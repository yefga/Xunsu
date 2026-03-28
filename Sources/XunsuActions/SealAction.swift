//
//  SealAction.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import XunsuCore

/// Options for sealing (notarizing) an app
public struct SealOptions: Codable, Sendable {
    public var appPath: String
    public var output: String
    public var volumeName: String?
    public var signingIdentity: String
    public var notaryProfile: String?
    public var notaryAppleID: String?
    public var notaryTeamID: String?
    public var notaryPassword: String?
    public var staple: Bool
    public var skipNotarization: Bool

    public init(
        appPath: String,
        output: String,
        volumeName: String? = nil,
        signingIdentity: String,
        notaryProfile: String? = nil,
        notaryAppleID: String? = nil,
        notaryTeamID: String? = nil,
        notaryPassword: String? = nil,
        staple: Bool = true,
        skipNotarization: Bool = false
    ) {
        self.appPath = appPath
        self.output = output
        self.volumeName = volumeName
        self.signingIdentity = signingIdentity
        self.notaryProfile = notaryProfile
        self.notaryAppleID = notaryAppleID
        self.notaryTeamID = notaryTeamID
        self.notaryPassword = notaryPassword
        self.staple = staple
        self.skipNotarization = skipNotarization
    }
}

/// Result of seal action
public struct SealOutput: Sendable {
    public let dmgPath: URL
    public let notarizationID: String?
    public let stapled: Bool

    public init(dmgPath: URL, notarizationID: String?, stapled: Bool) {
        self.dmgPath = dmgPath
        self.notarizationID = notarizationID
        self.stapled = stapled
    }
}

/// Errors specific to seal action
public enum SealError: Error, LocalizedError {
    case appNotFound(String)
    case codesignFailed(String)
    case dmgCreationFailed(String)
    case notarizationFailed(String)
    case stapleFailed(String)
    case missingCredentials(String)

    public var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            return "App not found at: \(path)"
        case .codesignFailed(let message):
            return "Code signing failed: \(message)"
        case .dmgCreationFailed(let message):
            return "DMG creation failed: \(message)"
        case .notarizationFailed(let message):
            return "Notarization failed: \(message)"
        case .stapleFailed(let message):
            return "Stapling failed: \(message)"
        case .missingCredentials(let detail):
            return "Missing credentials: \(detail)"
        }
    }
}

/// Action for creating, signing, and notarizing DMGs
public struct SealAction: Action {
    public static let name = "seal"
    public static let description = "Create DMG, code sign, and notarize for distribution"
    public static let category: ActionCategory = .distribution

    public typealias Options = SealOptions
    public typealias Output = SealOutput

    public init() {}

    public func run(options: Options, context: ActionContext) async throws -> Output {
        let runner = await context.processRunner
        let appURL = URL(fileURLWithPath: options.appPath)
        let dmgURL = URL(fileURLWithPath: options.output)

        // Verify app exists
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw SealError.appNotFound(options.appPath)
        }

        // Step 1: Codesign the app with hardened runtime
        await context.logger.info("Codesigning \(appURL.lastPathComponent)...")
        try await codesign(
            path: appURL,
            identity: options.signingIdentity,
            deep: true,
            hardenedRuntime: true,
            runner: runner
        )

        // Step 2: Create DMG
        let volumeName = options.volumeName ?? appURL.deletingPathExtension().lastPathComponent
        await context.logger.info("Creating DMG: \(dmgURL.lastPathComponent)...")
        try await createDMG(
            from: appURL,
            to: dmgURL,
            volumeName: volumeName,
            runner: runner
        )

        // Step 3: Codesign the DMG
        await context.logger.info("Codesigning DMG...")
        try await codesign(
            path: dmgURL,
            identity: options.signingIdentity,
            deep: false,
            hardenedRuntime: false,
            runner: runner
        )

        var notarizationID: String?
        var stapled = false

        // Step 4: Notarize (if not skipped)
        if !options.skipNotarization {
            await context.logger.info("Submitting for notarization...")
            notarizationID = try await notarize(
                path: dmgURL,
                options: options,
                context: context,
                runner: runner
            )

            // Step 5: Staple
            if options.staple {
                await context.logger.info("Stapling notarization ticket...")
                try await staple(path: dmgURL, runner: runner)
                stapled = true
            }
        }

        await context.logger.info("Seal complete: \(dmgURL.path)")

        return SealOutput(
            dmgPath: dmgURL,
            notarizationID: notarizationID,
            stapled: stapled
        )
    }

    public func validate(options: Options) throws {
        if options.appPath.isEmpty {
            throw ActionError.invalidOptions("App path is required")
        }
        if options.output.isEmpty {
            throw ActionError.invalidOptions("Output path is required")
        }
        if options.signingIdentity.isEmpty {
            throw ActionError.invalidOptions("Signing identity is required")
        }

        // Need either profile or all three (apple id, team id, password)
        if !options.skipNotarization {
            if options.notaryProfile == nil {
                if options.notaryAppleID == nil || options.notaryTeamID == nil || options.notaryPassword == nil {
                    throw ActionError.invalidOptions(
                        "Either --notary-profile or all of --notary-apple-id, --notary-team-id, --notary-password required"
                    )
                }
            }
        }
    }

    // MARK: - Private

    private func codesign(
        path: URL,
        identity: String,
        deep: Bool,
        hardenedRuntime: Bool,
        runner: ProcessRunner
    ) async throws {
        var args = ["--force", "--timestamp", "--sign", identity]

        if deep {
            args.append("--deep")
        }

        if hardenedRuntime {
            args.append("--options")
            args.append("runtime")
        }

        args.append(path.path)

        let result = try await runner.run("/usr/bin/codesign", arguments: args)
        if !result.succeeded {
            throw SealError.codesignFailed(result.stderr)
        }
    }

    private func createDMG(
        from appPath: URL,
        to dmgPath: URL,
        volumeName: String,
        runner: ProcessRunner
    ) async throws {
        // Remove existing DMG if present
        if FileManager.default.fileExists(atPath: dmgPath.path) {
            try FileManager.default.removeItem(at: dmgPath)
        }

        // Create parent directory if needed
        let parentDir = dmgPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let args = [
            "create",
            "-volname", volumeName,
            "-srcfolder", appPath.path,
            "-ov",
            "-format", "UDZO",
            dmgPath.path,
        ]

        let result = try await runner.run("/usr/bin/hdiutil", arguments: args)
        if !result.succeeded {
            throw SealError.dmgCreationFailed(result.stderr)
        }
    }

    private func notarize(
        path: URL,
        options: SealOptions,
        context: ActionContext,
        runner: ProcessRunner
    ) async throws -> String {
        var args = ["notarytool", "submit", path.path, "--wait"]

        if let profile = options.notaryProfile {
            // Use stored keychain profile
            args.append(contentsOf: ["--keychain-profile", profile])
        } else {
            // Use direct credentials - fetch env vars first to avoid autoclosure issues
            let envAppleID = await context.env("XUNSU_APPLE_ID")
            let envTeamID = await context.env("XUNSU_TEAM_ID")
            let envPassword = await context.env("XUNSU_APP_PASSWORD")

            guard let appleID = options.notaryAppleID ?? envAppleID,
                  let teamID = options.notaryTeamID ?? envTeamID,
                  let password = options.notaryPassword ?? envPassword
            else {
                throw SealError.missingCredentials("Apple ID, Team ID, and App-Specific Password required")
            }

            args.append(contentsOf: [
                "--apple-id", appleID,
                "--team-id", teamID,
                "--password", password,
            ])
        }

        let result = try await runner.xcrun("notarytool", arguments: Array(args.dropFirst()))
        if !result.succeeded {
            throw SealError.notarizationFailed(result.stderr)
        }

        // Parse submission ID from output
        // Format: "  id: abc-123-def-456"
        if let range = result.stdout.range(of: "id:\\s*([a-f0-9-]+)", options: .regularExpression) {
            let match = String(result.stdout[range])
            let id = match.replacingOccurrences(of: "id:", with: "").trimmingCharacters(in: .whitespaces)
            return id
        }

        return "unknown"
    }

    private func staple(path: URL, runner: ProcessRunner) async throws {
        let result = try await runner.xcrun("stapler", arguments: ["staple", path.path])
        if !result.succeeded {
            throw SealError.stapleFailed(result.stderr)
        }
    }
}

// MARK: - Credential Setup Helper

/// Helper for setting up notarization credentials interactively
public struct NotaryCredentialSetup {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    /// Store credentials in Keychain using xcrun notarytool
    public func storeCredentials(
        profile: String,
        appleID: String,
        teamID: String,
        password: String
    ) async throws {
        let args = [
            "notarytool", "store-credentials", profile,
            "--apple-id", appleID,
            "--team-id", teamID,
            "--password", password,
        ]

        let result = try await runner.xcrun("notarytool", arguments: Array(args.dropFirst()))
        if !result.succeeded {
            throw SealError.notarizationFailed("Failed to store credentials: \(result.stderr)")
        }
    }

    /// List stored credential profiles
    public func listProfiles() async throws -> [String] {
        // xcrun notarytool doesn't have a list command, but we can try to detect
        // This is a placeholder - in practice, users manage this themselves
        return []
    }
}
