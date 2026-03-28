//
//  ApkCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuActions
import XunsuCore
import XunsuTUI

struct ApkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apk",
        abstract: "Build Flutter APK or App Bundle for Android"
    )

    @Option(name: .shortAndLong, help: "Flutter project path")
    var project: String?

    @Option(name: .shortAndLong, help: "Build type")
    var buildType: BuildTypeArg = .release

    @Option(name: .shortAndLong, help: "Output type")
    var output: OutputTypeArg = .apk

    @Flag(name: .long, help: "Create separate APKs per ABI (arm64, arm, x64)")
    var splitPerAbi = false

    @Option(name: .long, help: "Target platform (android-arm, android-arm64, android-x64)")
    var targetPlatform: String?

    @Option(name: .long, help: "Build number (versionCode)")
    var buildNumber: String?

    @Option(name: .long, help: "Build name (versionName)")
    var buildName: String?

    @Option(name: .long, help: "Build flavor")
    var flavor: String?

    @Option(name: .long, help: "Dart define (can repeat)")
    var dartDefine: [String] = []

    @Flag(name: .long, help: "Enable code obfuscation (release only)")
    var obfuscate = false

    @Option(name: .long, help: "Path for split debug info (required with --obfuscate)")
    var splitDebugInfo: String?

    @Flag(name: .long, help: "Clean before building")
    var clean = false

    @Flag(name: .shortAndLong, help: "Interactive mode")
    var interactive = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    enum BuildTypeArg: String, ExpressibleByArgument, CaseIterable {
        case debug, release, profile
    }

    enum OutputTypeArg: String, ExpressibleByArgument, CaseIterable {
        case apk, appbundle, aab
    }

    func run() async throws {
        // Convert args to action types
        let buildType: ApkBuildType
        switch self.buildType {
        case .debug: buildType = .debug
        case .release: buildType = .release
        case .profile: buildType = .profile
        }

        let outputType: AndroidOutputType
        switch self.output {
        case .apk: outputType = .apk
        case .appbundle, .aab: outputType = .appbundle
        }

        let options = ApkOptions(
            projectPath: project,
            buildType: buildType,
            outputType: outputType,
            splitPerAbi: splitPerAbi,
            targetPlatform: targetPlatform,
            buildNumber: buildNumber,
            buildName: buildName,
            flavor: flavor,
            dartDefines: dartDefine.isEmpty ? nil : dartDefine,
            obfuscate: obfuscate,
            splitDebugInfo: splitDebugInfo,
            clean: clean
        )

        let context = ActionContext.current(interactive: interactive)
        let action = ApkAction()

        do {
            try action.validate(options: options)

            if json {
                let output = try await action.run(options: options, context: context)
                printJSON(output)
            } else {
                let outputName = outputType == .apk ? "APK" : "App Bundle"
                let spinner = Spinner(useColors: true)
                spinner.start("Building \(outputName) (\(buildType.rawValue))...")

                let output: ApkOutput
                do {
                    output = try await action.run(options: options, context: context)
                    spinner.success("Build completed in \(String(format: "%.1f", output.buildDuration))s")
                } catch {
                    spinner.failure(formatApkError(error))
                    throw error
                }

                print("  Output\(output.outputPaths.count > 1 ? "s" : ""):")
                for path in output.outputPaths {
                    let size = fileSize(path)
                    print("    \(path.lastPathComponent) \(size)")
                }
            }
        } catch {
            if json {
                printJSONError(error)
            }
            throw ExitCode.failure
        }
    }

    private func fileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return ""
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "(\(formatter.string(fromByteCount: size)))"
    }

    private func formatApkError(_ error: Error) -> String {
        if let apkError = error as? ApkError {
            switch apkError {
            case .flutterNotFound:
                return "Flutter not found. Run 'flutter doctor' to verify installation"
            case .notFlutterProject:
                return "Not a Flutter project. Ensure pubspec.yaml exists"
            case .buildFailed(let msg):
                // Try to extract meaningful error
                if msg.contains("Gradle") {
                    return "Gradle build failed. Run 'flutter build apk -v' for details"
                }
                if msg.contains("SDK") {
                    return "Android SDK issue. Run 'flutter doctor' to check setup"
                }
                return msg
            case .cleanFailed:
                return "Clean failed"
            case .outputNotFound:
                return "Build output not found. Check build/app/outputs/"
            }
        }
        return error.localizedDescription
    }

    private func printJSON(_ output: ApkOutput) {
        let result: [String: Any] = [
            "success": true,
            "outputPaths": output.outputPaths.map { $0.path },
            "buildType": output.buildType.rawValue,
            "outputType": output.outputType.rawValue,
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
}
