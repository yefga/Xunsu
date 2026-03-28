//
//  DevicesCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuCore
import XunsuTUI

struct DevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "List available simulators and devices"
    )

    @Flag(name: .long, help: "Show only simulators")
    var simulatorsOnly = false

    @Flag(name: .long, help: "Show only physical devices")
    var devicesOnly = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @Option(name: .long, help: "Filter by platform (ios, watchos, tvos, visionos)")
    var platform: String?

    func run() async throws {
        let runner = ProcessRunner()
        let prompt = TextPrompt(useColors: !json)

        // Get simulators using xcrun simctl
        let result = try await runner.run(
            "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "--json"]
        )

        guard result.succeeded else {
            prompt.error("Failed to list devices: \(result.stderr)")
            throw ExitCode.failure
        }

        guard let data = result.stdout.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = jsonObj["devices"] as? [String: [[String: Any]]]
        else {
            prompt.error("Failed to parse device list")
            throw ExitCode.failure
        }

        if json {
            print(result.stdout)
            return
        }

        // Parse and display devices
        var foundDevices: [(runtime: String, name: String, udid: String, state: String)] = []

        for (runtime, deviceList) in devices.sorted(by: { $0.key > $1.key }) {
            // Filter by platform if specified
            if let platformFilter = platform?.lowercased() {
                let runtimeLower = runtime.lowercased()
                if !runtimeLower.contains(platformFilter) {
                    continue
                }
            }

            for device in deviceList {
                guard let name = device["name"] as? String,
                      let udid = device["udid"] as? String,
                      let state = device["state"] as? String,
                      let isAvailable = device["isAvailable"] as? Bool,
                      isAvailable
                else { continue }

                // Extract OS version from runtime string
                // e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-0" -> "iOS 17.0"
                let osVersion = parseRuntime(runtime)
                foundDevices.append((runtime: osVersion, name: name, udid: udid, state: state))
            }
        }

        if foundDevices.isEmpty {
            prompt.warning("No available simulators found")
            return
        }

        // Group by runtime
        let grouped = Dictionary(grouping: foundDevices) { $0.runtime }

        for runtime in grouped.keys.sorted().reversed() {
            print("\n\(runtime):")
            for device in grouped[runtime]! {
                let stateIcon = device.state == "Booted" ? "🟢" : "⚪"
                print("  \(stateIcon) \(device.name)")
                print("     \(device.udid)")
            }
        }

        print("\n\(foundDevices.count) simulators available")
    }

    private func parseRuntime(_ runtime: String) -> String {
        // "com.apple.CoreSimulator.SimRuntime.iOS-17-0" -> "iOS 17.0"
        let parts = runtime.split(separator: ".")
        guard let last = parts.last else { return runtime }

        let versionParts = last.split(separator: "-")
        if versionParts.count >= 2 {
            let platform = String(versionParts[0])
            let version = versionParts.dropFirst().joined(separator: ".")
            return "\(platform) \(version)"
        }

        return String(last)
    }
}
