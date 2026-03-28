//
//  ApkAction.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import XunsuCore

/// Build type for APK
public enum ApkBuildType: String, Codable, Sendable {
    case debug
    case release
    case profile
}

/// Output type for Android builds
public enum AndroidOutputType: String, Codable, Sendable {
    case apk         // APK file
    case appbundle   // AAB (Android App Bundle)
}

/// Options for building APK/AAB
public struct ApkOptions: Codable, Sendable {
    public var projectPath: String?
    public var buildType: ApkBuildType
    public var outputType: AndroidOutputType
    public var splitPerAbi: Bool           // Create separate APKs per ABI
    public var targetPlatform: String?     // e.g., "android-arm64"
    public var buildNumber: String?
    public var buildName: String?
    public var flavor: String?             // Build flavor
    public var dartDefines: [String]?      // --dart-define flags
    public var obfuscate: Bool             // Enable code obfuscation
    public var splitDebugInfo: String?     // Path for debug symbols
    public var clean: Bool

    public init(
        projectPath: String? = nil,
        buildType: ApkBuildType = .release,
        outputType: AndroidOutputType = .apk,
        splitPerAbi: Bool = false,
        targetPlatform: String? = nil,
        buildNumber: String? = nil,
        buildName: String? = nil,
        flavor: String? = nil,
        dartDefines: [String]? = nil,
        obfuscate: Bool = false,
        splitDebugInfo: String? = nil,
        clean: Bool = false
    ) {
        self.projectPath = projectPath
        self.buildType = buildType
        self.outputType = outputType
        self.splitPerAbi = splitPerAbi
        self.targetPlatform = targetPlatform
        self.buildNumber = buildNumber
        self.buildName = buildName
        self.flavor = flavor
        self.dartDefines = dartDefines
        self.obfuscate = obfuscate
        self.splitDebugInfo = splitDebugInfo
        self.clean = clean
    }
}

/// Result of APK build
public struct ApkOutput: Sendable {
    public let outputPaths: [URL]      // Can be multiple if split-per-abi
    public let buildType: ApkBuildType
    public let outputType: AndroidOutputType
    public let buildDuration: TimeInterval

    public init(outputPaths: [URL], buildType: ApkBuildType, outputType: AndroidOutputType, buildDuration: TimeInterval) {
        self.outputPaths = outputPaths
        self.buildType = buildType
        self.outputType = outputType
        self.buildDuration = buildDuration
    }
}

/// Errors specific to APK building
public enum ApkError: Error, LocalizedError {
    case flutterNotFound
    case notFlutterProject
    case buildFailed(String)
    case cleanFailed(String)
    case outputNotFound

    public var errorDescription: String? {
        switch self {
        case .flutterNotFound:
            return "Flutter not found. Install Flutter and add it to PATH"
        case .notFlutterProject:
            return "Not a Flutter project (pubspec.yaml not found)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .cleanFailed(let message):
            return "Clean failed: \(message)"
        case .outputNotFound:
            return "Build output not found"
        }
    }
}

/// Action for building Flutter APK/AAB
public struct ApkAction: Action {
    public static let name = "apk"
    public static let description = "Build Flutter APK or App Bundle for Android"
    public static let category: ActionCategory = .building

    public typealias Options = ApkOptions
    public typealias Output = ApkOutput

    public init() {}

    public func run(options: Options, context: ActionContext) async throws -> Output {
        let startTime = Date()
        let runner = await context.processRunner

        // Resolve project path
        let projectPath: URL
        if let path = options.projectPath {
            projectPath = URL(fileURLWithPath: path)
        } else {
            projectPath = await context.projectPath
        }

        // Verify it's a Flutter project
        let pubspecPath = projectPath.appendingPathComponent("pubspec.yaml")
        guard FileManager.default.fileExists(atPath: pubspecPath.path) else {
            throw ApkError.notFlutterProject
        }

        // Find Flutter executable
        let flutterPath = try await findFlutter(runner: runner)

        // Clean if requested
        if options.clean {
            await context.logger.info("Cleaning Flutter project...")
            try await clean(flutterPath: flutterPath, projectPath: projectPath, runner: runner)
        }

        // Build arguments
        var args = ["build"]

        switch options.outputType {
        case .apk:
            args.append("apk")
        case .appbundle:
            args.append("appbundle")
        }

        // Build type
        switch options.buildType {
        case .debug:
            args.append("--debug")
        case .release:
            args.append("--release")
        case .profile:
            args.append("--profile")
        }

        // Split per ABI (APK only)
        if options.splitPerAbi && options.outputType == .apk {
            args.append("--split-per-abi")
        }

        // Target platform
        if let target = options.targetPlatform {
            args.append("--target-platform")
            args.append(target)
        }

        // Build number and name
        if let buildNumber = options.buildNumber {
            args.append("--build-number")
            args.append(buildNumber)
        }
        if let buildName = options.buildName {
            args.append("--build-name")
            args.append(buildName)
        }

        // Flavor
        if let flavor = options.flavor {
            args.append("--flavor")
            args.append(flavor)
        }

        // Dart defines
        if let defines = options.dartDefines {
            for define in defines {
                args.append("--dart-define")
                args.append(define)
            }
        }

        // Obfuscation
        if options.obfuscate {
            args.append("--obfuscate")
            if let debugInfoPath = options.splitDebugInfo {
                args.append("--split-debug-info")
                args.append(debugInfoPath)
            } else {
                // Obfuscation requires split-debug-info
                let debugDir = projectPath.appendingPathComponent("build/debug-info")
                args.append("--split-debug-info")
                args.append(debugDir.path)
            }
        }

        // Run build
        await context.logger.info("Building \(options.outputType == .apk ? "APK" : "App Bundle")...")
        let result = try await runner.run(
            flutterPath,
            arguments: args,
            workingDirectory: projectPath
        )

        if !result.succeeded {
            throw ApkError.buildFailed(extractFlutterError(from: result.stderr + result.stdout))
        }

        // Find output files
        let outputPaths = try findOutputFiles(
            projectPath: projectPath,
            outputType: options.outputType,
            buildType: options.buildType,
            splitPerAbi: options.splitPerAbi,
            flavor: options.flavor
        )

        let duration = Date().timeIntervalSince(startTime)
        await context.logger.info("Build completed in \(String(format: "%.1f", duration))s")

        return ApkOutput(
            outputPaths: outputPaths,
            buildType: options.buildType,
            outputType: options.outputType,
            buildDuration: duration
        )
    }

    public func validate(options: Options) throws {
        // Obfuscation only works with release builds
        if options.obfuscate && options.buildType != .release {
            throw ActionError.invalidOptions("Obfuscation only works with release builds")
        }
    }

    // MARK: - Private

    private func findFlutter(runner: ProcessRunner) async throws -> String {
        // Try common locations
        let possiblePaths = [
            "/usr/local/bin/flutter",
            "/opt/homebrew/bin/flutter",
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/flutter/bin/flutter" },
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/.flutter/bin/flutter" },
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using which
        let result = try await runner.run("/usr/bin/which", arguments: ["flutter"])
        if result.succeeded {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        throw ApkError.flutterNotFound
    }

    private func clean(flutterPath: String, projectPath: URL, runner: ProcessRunner) async throws {
        let result = try await runner.run(
            flutterPath,
            arguments: ["clean"],
            workingDirectory: projectPath
        )

        if !result.succeeded {
            throw ApkError.cleanFailed(result.stderr)
        }
    }

    private func findOutputFiles(
        projectPath: URL,
        outputType: AndroidOutputType,
        buildType: ApkBuildType,
        splitPerAbi: Bool,
        flavor: String?
    ) throws -> [URL] {
        let buildDir = projectPath.appendingPathComponent("build/app/outputs")

        var outputDir: URL
        var fileExtension: String

        switch outputType {
        case .apk:
            fileExtension = "apk"
            if let flavor = flavor {
                outputDir = buildDir.appendingPathComponent("flutter-apk")
            } else {
                outputDir = buildDir.appendingPathComponent("flutter-apk")
            }
        case .appbundle:
            fileExtension = "aab"
            outputDir = buildDir.appendingPathComponent("bundle/\(buildType.rawValue)")
        }

        // Find all matching files
        var outputPaths: [URL] = []

        if let contents = try? FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        ) {
            outputPaths = contents.filter { $0.pathExtension == fileExtension }
        }

        // Also check for the standard output location for APKs
        if outputType == .apk {
            let standardPath = buildDir
                .appendingPathComponent("flutter-apk")
                .appendingPathComponent("app-\(buildType.rawValue).apk")

            if FileManager.default.fileExists(atPath: standardPath.path) {
                if !outputPaths.contains(standardPath) {
                    outputPaths.append(standardPath)
                }
            }
        }

        if outputPaths.isEmpty {
            throw ApkError.outputNotFound
        }

        return outputPaths
    }

    private func extractFlutterError(from output: String) -> String {
        let lines = output.components(separatedBy: "\n")

        // Look for error lines
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("error:") ||
               trimmed.lowercased().contains("failure:") ||
               trimmed.contains("FAILURE") {
                return trimmed
            }
        }

        // Look for Gradle errors
        for line in lines {
            if line.contains("Execution failed") ||
               line.contains("Build failed") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }

        // Return last non-empty line
        if let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return lastLine.trimmingCharacters(in: .whitespaces)
        }

        return "Unknown error"
    }
}
