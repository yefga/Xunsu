//
//  SealCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuActions
import XunsuCore
import XunsuTUI

struct SealCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seal",
        abstract: "Create, code sign, and notarize DMG for distribution"
    )

    @Option(name: .shortAndLong, help: "Path to .app bundle")
    var app: String?

    @Option(name: .shortAndLong, help: "Output DMG path")
    var output: String?

    @Option(name: .long, help: "DMG volume name")
    var volumeName: String?

    @Option(name: .long, help: "Code signing identity (e.g., 'Developer ID Application: Name (TEAM)')")
    var identity: String?

    @Option(name: .long, help: "Notarytool keychain profile name")
    var notaryProfile: String?

    @Option(name: .long, help: "Apple ID for notarization")
    var notaryAppleId: String?

    @Option(name: .long, help: "Team ID for notarization")
    var notaryTeamId: String?

    @Option(name: .long, help: "App-specific password for notarization")
    var notaryPassword: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Staple notarization ticket to DMG")
    var staple = true

    @Flag(name: .long, help: "Skip notarization (only create and sign DMG)")
    var skipNotarization = false

    @Flag(name: .shortAndLong, help: "Interactive mode with prompts")
    var interactive = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() async throws {
        let prompt = TextPrompt(useColors: !json)
        let choice = ChoicePrompt(useColors: !json)

        // Resolve app path
        let resolvedApp: String
        if let app = app {
            resolvedApp = app
        } else if interactive {
            resolvedApp = prompt.ask("Path to .app bundle")
            if resolvedApp.isEmpty {
                throw ValidationError("App path is required")
            }
        } else {
            throw ValidationError("--app is required (or use --interactive)")
        }

        // Resolve output path
        let resolvedOutput: String
        if let output = output {
            resolvedOutput = output
        } else if interactive {
            let appName = URL(fileURLWithPath: resolvedApp).deletingPathExtension().lastPathComponent
            let defaultOutput = "./\(appName).dmg"
            resolvedOutput = prompt.ask("Output DMG path", default: defaultOutput)
        } else {
            // Default: same name as app in current directory
            let appName = URL(fileURLWithPath: resolvedApp).deletingPathExtension().lastPathComponent
            resolvedOutput = "./\(appName).dmg"
        }

        // Resolve signing identity
        let resolvedIdentity: String
        if let identity = identity {
            resolvedIdentity = identity
        } else if interactive {
            let store = CredentialStore()
            let identities = try await store.listSigningIdentities()

            if identities.isEmpty {
                resolvedIdentity = prompt.ask("Signing identity")
            } else {
                let names = identities.map { $0.name }
                let selected = choice.selectValue("Select signing identity", choices: names)
                resolvedIdentity = selected
            }

            if resolvedIdentity.isEmpty {
                throw ValidationError("Signing identity is required")
            }
        } else {
            // Try environment variable
            if let envIdentity = ProcessInfo.processInfo.environment["XUNSU_SIGNING_IDENTITY"] {
                resolvedIdentity = envIdentity
            } else {
                throw ValidationError("--identity is required (or use --interactive or set XUNSU_SIGNING_IDENTITY)")
            }
        }

        // Resolve notarization credentials
        var resolvedNotaryProfile = notaryProfile
        var resolvedAppleID = notaryAppleId
        var resolvedTeamID = notaryTeamId
        var resolvedPassword = notaryPassword

        if !skipNotarization && resolvedNotaryProfile == nil && resolvedAppleID == nil {
            if interactive {
                let useProfile = prompt.confirm("Use stored notary profile?", default: true)
                if useProfile {
                    resolvedNotaryProfile = prompt.ask("Notary profile name")
                } else {
                    resolvedAppleID = prompt.ask("Apple ID")
                    resolvedTeamID = prompt.ask("Team ID")
                    resolvedPassword = prompt.password("App-specific password")
                }
            }
            // If still no credentials, check environment
            if resolvedNotaryProfile == nil && resolvedAppleID == nil {
                resolvedAppleID = ProcessInfo.processInfo.environment["XUNSU_APPLE_ID"]
                    ?? ProcessInfo.processInfo.environment["NOTARY_APPLE_ID"]
                resolvedTeamID = ProcessInfo.processInfo.environment["XUNSU_TEAM_ID"]
                    ?? ProcessInfo.processInfo.environment["NOTARY_TEAM_ID"]
                resolvedPassword = ProcessInfo.processInfo.environment["XUNSU_APP_PASSWORD"]
                    ?? ProcessInfo.processInfo.environment["NOTARY_PASSWORD"]
            }
        }

        let options = SealOptions(
            appPath: resolvedApp,
            output: resolvedOutput,
            volumeName: volumeName,
            signingIdentity: resolvedIdentity,
            notaryProfile: resolvedNotaryProfile,
            notaryAppleID: resolvedAppleID,
            notaryTeamID: resolvedTeamID,
            notaryPassword: resolvedPassword,
            staple: staple,
            skipNotarization: skipNotarization
        )

        let context = ActionContext.current(interactive: interactive)
        let action = SealAction()

        do {
            try action.validate(options: options)

            let output: SealOutput
            if json {
                output = try await action.run(options: options, context: context)
                printJSON(output)
            } else {
                let spinner = Spinner(useColors: true)
                let appName = URL(fileURLWithPath: resolvedApp).deletingPathExtension().lastPathComponent
                spinner.start("Sealing \(appName)...")

                do {
                    output = try await action.run(options: options, context: context)
                    spinner.success("Seal complete!")
                } catch {
                    spinner.failure(formatSealError(error))
                    throw error
                }

                let dmgSize = FileSizeFormatter.sizeOfFile(at: output.dmgPath) ?? "N/A"
                print("  DMG: \(output.dmgPath.path) (\(dmgSize))")
                if let notaryID = output.notarizationID {
                    print("  Notarization ID: \(notaryID)")
                }
                print("  Stapled: \(output.stapled ? "Yes" : "No")")
            }
        } catch {
            if json {
                printJSONError(error)
            }
            throw ExitCode.failure
        }
    }

    private func formatSealError(_ error: Error) -> String {
        if let sealError = error as? SealError {
            switch sealError {
            case .appNotFound(let path):
                return "App not found: \(path)"
            case .codesignFailed(let msg):
                if msg.contains("no identity found") {
                    return "No valid signing identity. Run 'security find-identity -v -p codesigning'"
                }
                return "Codesign failed: \(msg.components(separatedBy: "\n").first ?? msg)"
            case .dmgCreationFailed(let msg):
                return "DMG creation failed: \(msg.components(separatedBy: "\n").first ?? msg)"
            case .notarizationFailed(let msg):
                if msg.contains("credentials") {
                    return "Notarization credentials invalid. Check Apple ID and app-specific password"
                }
                return "Notarization failed: \(msg.components(separatedBy: "\n").first ?? msg)"
            case .stapleFailed:
                return "Failed to staple notarization ticket"
            case .missingCredentials(let detail):
                return "Missing credentials: \(detail)"
            }
        }
        return error.localizedDescription
    }

    private func printJSON(_ output: SealOutput) {
        let result: [String: Any] = [
            "success": true,
            "dmgPath": output.dmgPath.path,
            "notarizationID": output.notarizationID as Any,
            "stapled": output.stapled,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }

    private func printJSONError(_ error: Error) {
        let result: [String: Any] = [
            "success": false,
            "error": error.localizedDescription,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }
}
