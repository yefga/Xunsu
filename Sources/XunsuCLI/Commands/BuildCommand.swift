//
//  BuildCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuActions
import XunsuCore
import XunsuTUI

/// Supported Apple platforms
enum Platform: String, ExpressibleByArgument, CaseIterable {
    case iOS = "ios"
    case macOS = "macos"
    case watchOS = "watchos"
    case tvOS = "tvos"
    case visionOS = "visionos"

    var destination: String {
        switch self {
        case .iOS:
            return "generic/platform=iOS"
        case .macOS:
            return "generic/platform=macOS"
        case .watchOS:
            return "generic/platform=watchOS"
        case .tvOS:
            return "generic/platform=tvOS"
        case .visionOS:
            return "generic/platform=visionOS"
        }
    }

    /// Generic simulator destination (uses any available simulator)
    var simulatorDestination: String {
        switch self {
        case .iOS:
            return "platform=iOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder"
        case .macOS:
            return "platform=macOS"
        case .watchOS:
            return "platform=watchOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-watchsimulator:placeholder"
        case .tvOS:
            return "platform=tvOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-appletvsimulator:placeholder"
        case .visionOS:
            return "platform=visionOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-xrsimulator:placeholder"
        }
    }
}

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build and archive iOS/macOS/watchOS/tvOS/visionOS apps"
    )

    @Option(name: .shortAndLong, help: "Xcode project path (.xcodeproj)")
    var project: String?

    @Option(name: .shortAndLong, help: "Xcode workspace path (.xcworkspace)")
    var workspace: String?

    @Option(name: .shortAndLong, help: "Build scheme (required)")
    var scheme: String?

    @Option(name: .shortAndLong, help: "Build configuration (Debug/Release)")
    var configuration: String = "Release"

    @Option(name: .long, help: "Target platform")
    var platform: Platform = .iOS

    @Option(name: .long, help: "Custom destination string")
    var destination: String?

    @Option(name: .long, help: "Archive output path")
    var archivePath: String?

    @Option(name: .long, help: "Export output path")
    var exportPath: String?

    @Option(name: .long, help: "Export options plist path")
    var exportOptionsPlist: String?

    @Flag(name: .long, help: "Clean before building")
    var clean = false

    @Flag(name: .long, help: "Build for simulator (no archive, no signing)")
    var simulator = false

    @Flag(name: .shortAndLong, help: "Interactive mode with prompts")
    var interactive = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() async throws {
        let prompt = TextPrompt(useColors: !json)

        // Resolve scheme
        let resolvedScheme: String
        if let scheme = scheme {
            resolvedScheme = scheme
        } else if interactive {
            resolvedScheme = prompt.ask("Enter scheme name")
            if resolvedScheme.isEmpty {
                throw ValidationError("Scheme is required")
            }
        } else {
            throw ValidationError("--scheme is required (or use --interactive)")
        }

        // Resolve destination
        let resolvedDestination: String
        if let dest = destination {
            resolvedDestination = dest
        } else if simulator {
            resolvedDestination = platform.simulatorDestination
        } else {
            resolvedDestination = platform.destination
        }

        let options = BuildOptions(
            project: project,
            workspace: workspace,
            scheme: resolvedScheme,
            configuration: configuration,
            destination: resolvedDestination,
            archivePath: archivePath,
            exportPath: exportPath,
            exportOptionsPlist: exportOptionsPlist,
            clean: clean,
            simulatorBuild: simulator
        )

        let context = ActionContext.current(interactive: interactive)
        let action = BuildAction()

        do {
            try action.validate(options: options)

            if json {
                // No spinner for JSON output
                let output = try await action.run(options: options, context: context)
                printJSON(output)
            } else {
                // Use spinner for interactive output
                let buildType = simulator ? "simulator" : "device"
                let spinner = Spinner(useColors: true)
                spinner.start("Building \(resolvedScheme) for \(buildType)...")

                let output: BuildOutput
                do {
                    output = try await action.run(options: options, context: context)
                    spinner.success("Build completed in \(DurationFormatter.format(output.buildDuration))")
                } catch {
                    spinner.failure(formatBuildError(error))
                    throw error
                }

                let archiveSize = FileSizeFormatter.sizeOfDirectory(at: output.archivePath) ?? "N/A"
                print("  \(simulator ? "Output" : "Archive"): \(output.archivePath.path) (\(archiveSize))")
                if let exportPath = output.exportPath {
                    let exportSize = FileSizeFormatter.sizeOfDirectory(at: exportPath) ?? "N/A"
                    print("  Export: \(exportPath.path) (\(exportSize))")
                }
                if let appPath = output.appPath {
                    let appSize = FileSizeFormatter.sizeOfDirectory(at: appPath) ?? "N/A"
                    print("  App: \(appPath.path) (\(appSize))")
                }
            }
        } catch {
            if json {
                printJSONError(error)
            }
            throw ExitCode.failure
        }
    }

    private func printJSON(_ output: BuildOutput) {
        let result: [String: Any] = [
            "success": true,
            "archivePath": output.archivePath.path,
            "exportPath": output.exportPath?.path as Any,
            "appPath": output.appPath?.path as Any,
            "buildDuration": output.buildDuration,
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

    /// Format build errors with more detail
    private func formatBuildError(_ error: Error) -> String {
        if let buildError = error as? BuildError {
            switch buildError {
            case .noProjectFound:
                return "No Xcode project found in current directory"
            case .schemeNotFound(let scheme):
                return "Scheme '\(scheme)' not found. Run 'xcodebuild -list' to see available schemes"
            case .archiveFailed(let message):
                // Extract the most relevant error line
                let lines = message.components(separatedBy: "\n")
                if let errorLine = lines.first(where: { $0.contains("error:") }) {
                    return errorLine.trimmingCharacters(in: .whitespaces)
                }
                return "Build failed. Check Xcode build settings"
            case .exportFailed(let message):
                return "Export failed: \(message.components(separatedBy: "\n").first ?? message)"
            case .cleanFailed:
                return "Clean failed"
            }
        }
        return error.localizedDescription
    }
}
