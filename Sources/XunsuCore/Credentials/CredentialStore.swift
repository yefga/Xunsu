//
//  CredentialStore.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Types of credentials Xunsu can manage
public enum CredentialType: String, Sendable {
    case appleID = "apple-id"
    case teamID = "team-id"
    case notaryProfile = "notary-profile"
    case signingIdentity = "signing-identity"
}

/// Apple ID credentials for App Store Connect
public struct AppleIDCredential: Sendable {
    public let appleID: String
    public let teamID: String
    public let appSpecificPassword: String

    public init(appleID: String, teamID: String, appSpecificPassword: String) {
        self.appleID = appleID
        self.teamID = teamID
        self.appSpecificPassword = appSpecificPassword
    }
}

/// Signing identity information
public struct SigningIdentity: Sendable {
    public let name: String
    public let hash: String?

    public init(name: String, hash: String? = nil) {
        self.name = name
        self.hash = hash
    }
}

/// Centralized credential management
public actor CredentialStore {
    private let keychain: KeychainService
    private var cache: [String: String] = [:]

    public init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    /// Get Apple ID credentials from Keychain or environment
    public func getAppleID() async throws -> AppleIDCredential {
        let env = ProcessInfo.processInfo.environment

        // Try environment variables first (for CI)
        if let appleID = env["XUNSU_APPLE_ID"] ?? env["NOTARY_APPLE_ID"],
           let teamID = env["XUNSU_TEAM_ID"] ?? env["NOTARY_TEAM_ID"],
           let password = env["XUNSU_APP_PASSWORD"] ?? env["NOTARY_PASSWORD"]
        {
            return AppleIDCredential(
                appleID: appleID,
                teamID: teamID,
                appSpecificPassword: password
            )
        }

        // Try Keychain
        let appleID = try await keychain.retrieve(account: "apple-id")
        let teamID = try await keychain.retrieve(account: "team-id")
        let password = try await keychain.retrieve(account: "app-password")

        return AppleIDCredential(
            appleID: appleID,
            teamID: teamID,
            appSpecificPassword: password
        )
    }

    /// Store Apple ID credentials
    public func storeAppleID(_ credential: AppleIDCredential) async throws {
        try await keychain.store(account: "apple-id", password: credential.appleID, label: "Xunsu Apple ID")
        try await keychain.store(account: "team-id", password: credential.teamID, label: "Xunsu Team ID")
        try await keychain.store(
            account: "app-password",
            password: credential.appSpecificPassword,
            label: "Xunsu App-Specific Password"
        )
    }

    /// Get notary profile name from environment or config
    public func getNotaryProfile() async -> String? {
        ProcessInfo.processInfo.environment["XUNSU_NOTARY_PROFILE"]
    }

    /// Get signing identity from environment or list available ones
    public func getSigningIdentity() async -> String? {
        ProcessInfo.processInfo.environment["XUNSU_SIGNING_IDENTITY"]
    }

    /// List available code signing identities using security command
    public func listSigningIdentities() async throws -> [SigningIdentity] {
        let process = ProcessRunner()
        let result = try await process.run(
            "/usr/bin/security",
            arguments: ["find-identity", "-v", "-p", "codesigning"]
        )

        guard result.succeeded else {
            return []
        }

        // Parse output: "  1) ABC123 \"Developer ID Application: Name (TEAM)\""
        var identities: [SigningIdentity] = []
        let lines = result.stdout.components(separatedBy: "\n")

        for line in lines {
            // Match pattern: number) hash "identity name"
            if let range = line.range(of: #"\d+\)\s+([A-F0-9]+)\s+"([^"]+)""#, options: .regularExpression) {
                let match = String(line[range])
                // Extract hash and name
                if let hashRange = match.range(of: #"[A-F0-9]+"#, options: .regularExpression),
                   let nameRange = match.range(of: #""[^"]+""#, options: .regularExpression)
                {
                    let hash = String(match[hashRange])
                    var name = String(match[nameRange])
                    name = String(name.dropFirst().dropLast()) // Remove quotes
                    identities.append(SigningIdentity(name: name, hash: hash))
                }
            }
        }

        return identities
    }
}
