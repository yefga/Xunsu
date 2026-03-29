//
//  BuildAction.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import XunsuCore

/// Options for building an app
public struct BuildOptions: Codable, Sendable {
    public var project: String?
    public var workspace: String?
    public var scheme: String
    public var configuration: String
    public var sdk: String?
    public var destination: String?
    public var archivePath: String?
    public var exportPath: String?
    public var exportOptionsPlist: String?
    public var clean: Bool
    public var derivedDataPath: String?
    public var simulatorBuild: Bool  // Build for simulator (no archive)

    public init(
        project: String? = nil,
        workspace: String? = nil,
        scheme: String,
        configuration: String = "Release",
        sdk: String? = nil,
        destination: String? = nil,
        archivePath: String? = nil,
        exportPath: String? = nil,
        exportOptionsPlist: String? = nil,
        clean: Bool = false,
        derivedDataPath: String? = nil,
        simulatorBuild: Bool = false
    ) {
        self.project = project
        self.workspace = workspace
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.archivePath = archivePath
        self.exportPath = exportPath
        self.exportOptionsPlist = exportOptionsPlist
        self.clean = clean
        self.derivedDataPath = derivedDataPath
        self.simulatorBuild = simulatorBuild
    }
}

/// Result of a build action
public struct BuildOutput: Sendable {
    public let archivePath: URL
    public let exportPath: URL?
    public let appPath: URL?
    public let buildDuration: TimeInterval

    public init(archivePath: URL, exportPath: URL?, appPath: URL?, buildDuration: TimeInterval) {
        self.archivePath = archivePath
        self.exportPath = exportPath
        self.appPath = appPath
        self.buildDuration = buildDuration
    }
}

/// Errors specific to build action
public enum BuildError: Error, LocalizedError {
    case noProjectFound
    case schemeNotFound(String)
    case archiveFailed(String)
    case exportFailed(String)
    case cleanFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noProjectFound:
            return "No .xcodeproj or .xcworkspace found in current directory"
        case .schemeNotFound(let scheme):
            return "Scheme '\(scheme)' not found"
        case .archiveFailed(let message):
            return "Archive failed: \(message)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .cleanFailed(let message):
            return "Clean failed: \(message)"
        }
    }
}

/// Action for building iOS/macOS apps
public struct BuildAction: Action {
    public static let name = "build"
    public static let description = "Build and archive iOS/macOS application"
    public static let category: ActionCategory = .building

    public typealias Options = BuildOptions
    public typealias Output = BuildOutput

    public init() {}

    public func run(options: Options, context: ActionContext) async throws -> Output {
        let startTime = Date()
        let runner = await context.processRunner

        // Find project/workspace
        let projectFile = try await resolveProject(options: options, context: context)
        await context.logger.info("Using project: \(projectFile)")

        // Clean if requested
        if options.clean {
            await context.logger.info("Cleaning build...")
            try await clean(projectFile: projectFile, scheme: options.scheme, runner: runner)
        }

        var archivePath: URL
        var exportedPath: URL?
        var appPath: URL?

        if options.simulatorBuild {
            // Simulator build - just build, no archive/export
            await context.logger.info("Building \(options.scheme) for simulator...")
            let buildDir = await context.projectPath.appendingPathComponent("build")
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
            archivePath = buildDir  // Use build dir as "archive" path for consistency

            try await buildForSimulator(
                projectFile: projectFile,
                scheme: options.scheme,
                configuration: options.configuration,
                destination: options.destination,
                derivedDataPath: options.derivedDataPath,
                runner: runner
            )
        } else {
            // Archive build for device/distribution
            if let customPath = options.archivePath {
                archivePath = URL(fileURLWithPath: customPath)
            } else {
                let buildDir = await context.projectPath.appendingPathComponent("build")
                try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
                archivePath = buildDir.appendingPathComponent("\(options.scheme).xcarchive")
            }

            await context.logger.info("Archiving \(options.scheme)...")
            try await archive(
                projectFile: projectFile,
                scheme: options.scheme,
                configuration: options.configuration,
                destination: options.destination,
                archivePath: archivePath,
                derivedDataPath: options.derivedDataPath,
                runner: runner
            )

            // Export if plist provided
            if let exportPlist = options.exportOptionsPlist {
                let exportDir: URL
                if let customExport = options.exportPath {
                    exportDir = URL(fileURLWithPath: customExport)
                } else {
                    exportDir = await context.projectPath.appendingPathComponent("build/export")
                }

                await context.logger.info("Exporting archive...")
                try await export(
                    archivePath: archivePath,
                    exportPath: exportDir,
                    exportOptionsPlist: URL(fileURLWithPath: exportPlist),
                    runner: runner
                )
                exportedPath = exportDir

                // Find .app in export directory
                if let contents = try? FileManager.default.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil) {
                    appPath = contents.first { $0.pathExtension == "app" }
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        await context.logger.info("Build completed in \(DurationFormatter.format(duration))")

        return BuildOutput(
            archivePath: archivePath,
            exportPath: exportedPath,
            appPath: appPath,
            buildDuration: duration
        )
    }

    public func validate(options: Options) throws {
        if options.scheme.isEmpty {
            throw ActionError.invalidOptions("Scheme is required")
        }
    }

    // MARK: - Private

    private func resolveProject(options: Options, context: ActionContext) async throws -> URL {
        if let workspace = options.workspace {
            return URL(fileURLWithPath: workspace)
        }
        if let project = options.project {
            return URL(fileURLWithPath: project)
        }

        // Auto-detect
        let projectDir = await context.projectPath
        let contents = try FileManager.default.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

        // Prefer workspace over project
        if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
            return workspace
        }
        if let project = contents.first(where: { $0.pathExtension == "xcodeproj" }) {
            return project
        }

        throw BuildError.noProjectFound
    }

    private func clean(projectFile: URL, scheme: String, runner: ProcessRunner) async throws {
        var args = [
            "-scheme", scheme,
            "clean",
        ]

        if projectFile.pathExtension == "xcworkspace" {
            args.insert(contentsOf: ["-workspace", projectFile.path], at: 0)
        } else {
            args.insert(contentsOf: ["-project", projectFile.path], at: 0)
        }

        let result = try await runner.run("/usr/bin/xcodebuild", arguments: args)
        if !result.succeeded {
            throw BuildError.cleanFailed(result.stderr)
        }
    }

    private func archive(
        projectFile: URL,
        scheme: String,
        configuration: String,
        destination: String?,
        archivePath: URL,
        derivedDataPath: String?,
        runner: ProcessRunner
    ) async throws {
        var args: [String] = []

        if projectFile.pathExtension == "xcworkspace" {
            args.append(contentsOf: ["-workspace", projectFile.path])
        } else {
            args.append(contentsOf: ["-project", projectFile.path])
        }

        args.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration,
            "-archivePath", archivePath.path,
            "archive",
        ])

        if let dest = destination {
            args.append(contentsOf: ["-destination", dest])
        } else {
            // Default to generic iOS device
            args.append(contentsOf: ["-destination", "generic/platform=iOS"])
        }

        if let derivedData = derivedDataPath {
            args.append(contentsOf: ["-derivedDataPath", derivedData])
        }

        let result = try await runner.run("/usr/bin/xcodebuild", arguments: args)
        if !result.succeeded {
            throw BuildError.archiveFailed(result.stderr)
        }
    }

    private func buildForSimulator(
        projectFile: URL,
        scheme: String,
        configuration: String,
        destination: String?,
        derivedDataPath: String?,
        runner: ProcessRunner
    ) async throws {
        var args: [String] = []

        if projectFile.pathExtension == "xcworkspace" {
            args.append(contentsOf: ["-workspace", projectFile.path])
        } else {
            args.append(contentsOf: ["-project", projectFile.path])
        }

        args.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration,
            "build",
        ])

        if let dest = destination {
            args.append(contentsOf: ["-destination", dest])
        } else {
            // Default to any iOS simulator
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder"])
        }

        if let derivedData = derivedDataPath {
            args.append(contentsOf: ["-derivedDataPath", derivedData])
        }

        let result = try await runner.run("/usr/bin/xcodebuild", arguments: args)
        if !result.succeeded {
            throw BuildError.archiveFailed(result.stderr)
        }
    }

    private func export(
        archivePath: URL,
        exportPath: URL,
        exportOptionsPlist: URL,
        runner: ProcessRunner
    ) async throws {
        try FileManager.default.createDirectory(at: exportPath, withIntermediateDirectories: true)

        let args = [
            "-exportArchive",
            "-archivePath", archivePath.path,
            "-exportPath", exportPath.path,
            "-exportOptionsPlist", exportOptionsPlist.path,
        ]

        let result = try await runner.run("/usr/bin/xcodebuild", arguments: args)
        if !result.succeeded {
            throw BuildError.exportFailed(result.stderr)
        }
    }
}
