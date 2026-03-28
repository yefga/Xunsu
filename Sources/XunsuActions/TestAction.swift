//
//  TestAction.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import XunsuCore

/// Options for running tests
public struct TestOptions: Codable, Sendable {
    public var project: String?
    public var workspace: String?
    public var scheme: String
    public var destination: String?
    public var configuration: String
    public var testPlan: String?
    public var onlyTesting: [String]?
    public var skipTesting: [String]?
    public var resultBundlePath: String?
    public var parallel: Bool
    public var retryOnFailure: Bool

    public init(
        project: String? = nil,
        workspace: String? = nil,
        scheme: String,
        destination: String? = nil,
        configuration: String = "Debug",
        testPlan: String? = nil,
        onlyTesting: [String]? = nil,
        skipTesting: [String]? = nil,
        resultBundlePath: String? = nil,
        parallel: Bool = true,
        retryOnFailure: Bool = false
    ) {
        self.project = project
        self.workspace = workspace
        self.scheme = scheme
        self.destination = destination
        self.configuration = configuration
        self.testPlan = testPlan
        self.onlyTesting = onlyTesting
        self.skipTesting = skipTesting
        self.resultBundlePath = resultBundlePath
        self.parallel = parallel
        self.retryOnFailure = retryOnFailure
    }
}

/// Result of test action
public struct TestOutput: Sendable {
    public let passed: Bool
    public let totalTests: Int
    public let failedTests: Int
    public let skippedTests: Int
    public let duration: TimeInterval
    public let resultBundlePath: URL?

    public init(
        passed: Bool,
        totalTests: Int,
        failedTests: Int,
        skippedTests: Int,
        duration: TimeInterval,
        resultBundlePath: URL?
    ) {
        self.passed = passed
        self.totalTests = totalTests
        self.failedTests = failedTests
        self.skippedTests = skippedTests
        self.duration = duration
        self.resultBundlePath = resultBundlePath
    }
}

/// Errors specific to test action
public enum TestError: Error, LocalizedError {
    case noProjectFound
    case testsFailed(Int, Int) // failed, total
    case buildFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noProjectFound:
            return "No .xcodeproj or .xcworkspace found"
        case .testsFailed(let failed, let total):
            return "\(failed) of \(total) tests failed"
        case .buildFailed(let message):
            return "Build for testing failed: \(message)"
        }
    }
}

/// Action for running tests
public struct TestAction: Action {
    public static let name = "test"
    public static let description = "Run unit and UI tests"
    public static let category: ActionCategory = .testing

    public typealias Options = TestOptions
    public typealias Output = TestOutput

    public init() {}

    public func run(options: Options, context: ActionContext) async throws -> Output {
        let startTime = Date()
        let runner = await context.processRunner

        // Find project/workspace
        let projectFile = try await resolveProject(options: options, context: context)
        await context.logger.info("Running tests for \(options.scheme)...")

        // Build arguments
        var args: [String] = []

        if projectFile.pathExtension == "xcworkspace" {
            args.append(contentsOf: ["-workspace", projectFile.path])
        } else {
            args.append(contentsOf: ["-project", projectFile.path])
        }

        args.append(contentsOf: [
            "-scheme", options.scheme,
            "-configuration", options.configuration,
            "test",
        ])

        if let dest = options.destination {
            args.append(contentsOf: ["-destination", dest])
        } else {
            // Default to iOS Simulator
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,name=iPhone 15"])
        }

        if let testPlan = options.testPlan {
            args.append(contentsOf: ["-testPlan", testPlan])
        }

        if let resultPath = options.resultBundlePath {
            args.append(contentsOf: ["-resultBundlePath", resultPath])
        }

        if options.parallel {
            args.append("-parallel-testing-enabled")
            args.append("YES")
        }

        if let onlyTesting = options.onlyTesting {
            for test in onlyTesting {
                args.append(contentsOf: ["-only-testing", test])
            }
        }

        if let skipTesting = options.skipTesting {
            for test in skipTesting {
                args.append(contentsOf: ["-skip-testing", test])
            }
        }

        // Run tests
        let result = try await runner.run("/usr/bin/xcodebuild", arguments: args)

        let duration = Date().timeIntervalSince(startTime)

        // Parse results (simplified - real implementation would parse xcresult)
        let passed = result.succeeded
        let testSummary = parseTestSummary(from: result.stdout)

        let output = TestOutput(
            passed: passed,
            totalTests: testSummary.total,
            failedTests: testSummary.failed,
            skippedTests: testSummary.skipped,
            duration: duration,
            resultBundlePath: options.resultBundlePath.map { URL(fileURLWithPath: $0) }
        )

        if passed {
            await context.logger.info("All tests passed (\(testSummary.total) tests in \(String(format: "%.1f", duration))s)")
        } else {
            await context.logger.error("\(testSummary.failed) tests failed")
        }

        return output
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

        let projectDir = await context.projectPath
        let contents = try FileManager.default.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)

        if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
            return workspace
        }
        if let project = contents.first(where: { $0.pathExtension == "xcodeproj" }) {
            return project
        }

        throw TestError.noProjectFound
    }

    private func parseTestSummary(from output: String) -> (total: Int, failed: Int, skipped: Int) {
        // Parse "Test Suite 'All tests' passed/failed" and similar patterns
        // This is a simplified parser - real implementation would use xcresult

        var total = 0
        var failed = 0
        let skipped = 0

        // Look for "Executed X tests" pattern
        if let range = output.range(of: "Executed (\\d+) test", options: .regularExpression) {
            let match = String(output[range])
            if let num = Int(match.filter { $0.isNumber }) {
                total = num
            }
        }

        // Look for "X failure" pattern
        if let range = output.range(of: "(\\d+) failure", options: .regularExpression) {
            let match = String(output[range])
            if let num = Int(match.filter { $0.isNumber }) {
                failed = num
            }
        }

        return (total, failed, skipped)
    }
}
