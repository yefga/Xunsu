//
//  InitCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuActions
import XunsuCore
import XunsuTUI

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize Xunsu configuration for your project"
    )

    @Flag(name: .long, help: "Setup notarization credentials")
    var notarization = false

    @Flag(name: .long, help: "Force overwrite existing configuration")
    var force = false

    func run() async throws {
        let prompt = TextPrompt()
        let choice = ChoicePrompt()

        prompt.info("Welcome to Xunsu!")
        print()

        if notarization {
            try await setupNotarization(prompt: prompt, choice: choice)
        } else {
            try await setupProject(prompt: prompt, choice: choice)
        }
    }

    private func setupProject(prompt: TextPrompt, choice: ChoicePrompt) async throws {
        // Check for existing config
        let configPath = URL(fileURLWithPath: ".xunsu.json")
        if FileManager.default.fileExists(atPath: configPath.path) && !force {
            let overwrite = prompt.confirm("Configuration already exists. Overwrite?", default: false)
            if !overwrite {
                prompt.info("Keeping existing configuration")
                return
            }
        }

        // Detect project
        let contents = try FileManager.default.contentsOfDirectory(atPath: ".")
        let workspaces = contents.filter { $0.hasSuffix(".xcworkspace") }
        let projects = contents.filter { $0.hasSuffix(".xcodeproj") }

        var config: [String: Any] = [:]

        if !workspaces.isEmpty {
            let selected = choice.selectValue("Select workspace", choices: workspaces)
            config["workspace"] = selected
        } else if !projects.isEmpty {
            let selected = choice.selectValue("Select project", choices: projects)
            config["project"] = selected
        } else {
            prompt.warning("No Xcode project or workspace found")
        }

        // Ask for default scheme
        let scheme = prompt.ask("Default scheme name")
        if !scheme.isEmpty {
            config["scheme"] = scheme
        }

        // Ask about signing
        let setupSigning = prompt.confirm("Setup code signing identity?", default: true)
        if setupSigning {
            let store = CredentialStore()
            let identities = try await store.listSigningIdentities()

            if !identities.isEmpty {
                let names = identities.map { $0.name }
                let selected = choice.selectValue("Select signing identity", choices: names)
                config["signingIdentity"] = selected
            } else {
                prompt.warning("No signing identities found. Run 'security find-identity -v -p codesigning'")
            }
        }

        // Ask about notarization
        let setupNotary = prompt.confirm("Setup notarization?", default: false)
        if setupNotary {
            try await setupNotarization(prompt: prompt, choice: choice)
        }

        // Save config
        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: configPath)

        prompt.success("Configuration saved to .xunsu.json")
        print()
        print("Next steps:")
        print("  xunsu build --scheme <scheme>")
        print("  xunsu test --scheme <scheme>")
        print("  xunsu seal --app <path> --identity '<identity>'")
    }

    private func setupNotarization(prompt: TextPrompt, choice: ChoicePrompt) async throws {
        prompt.info("Setting up notarization credentials")
        print()
        print("You'll need:")
        print("  1. Apple ID enrolled in Apple Developer Program")
        print("  2. Team ID (from developer.apple.com)")
        print("  3. App-specific password (from appleid.apple.com)")
        print()

        let profileName = prompt.ask("Profile name to store credentials", default: "xunsu-notary")
        let appleID = prompt.ask("Apple ID (email)")
        let teamID = prompt.ask("Team ID")
        let password = prompt.password("App-specific password")

        if appleID.isEmpty || teamID.isEmpty || password.isEmpty {
            throw ValidationError("All fields are required")
        }

        prompt.info("Storing credentials via xcrun notarytool...")

        let setup = NotaryCredentialSetup()
        try await setup.storeCredentials(
            profile: profileName,
            appleID: appleID,
            teamID: teamID,
            password: password
        )

        prompt.success("Credentials stored as '\(profileName)'")
        print()
        print("Usage:")
        print("  xunsu seal --app <path> --notary-profile \(profileName)")
    }
}
