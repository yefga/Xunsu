//
//  TestCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser
import Foundation
import XunsuActions
import XunsuCore
import XunsuTUI

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run unit and UI tests for any Apple platform"
    )

    @Option(name: .shortAndLong, help: "Xcode project path (.xcodeproj)")
    var project: String?

    @Option(name: .shortAndLong, help: "Xcode workspace path (.xcworkspace)")
    var workspace: String?

    @Option(name: .shortAndLong, help: "Test scheme (required)")
    var scheme: String?

    @Option(name: .shortAndLong, help: "Build configuration")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Target platform for simulator")
    var platform: Platform = .iOS

    @Option(name: .long, help: "Custom destination string")
    var destination: String?

    @Option(name: .long, help: "Test plan name")
    var testPlan: String?

    @Option(name: .long, help: "Only run specific tests (can repeat)")
    var onlyTesting: [String] = []

    @Option(name: .long, help: "Skip specific tests (can repeat)")
    var skipTesting: [String] = []

    @Option(name: .long, help: "Result bundle output path")
    var resultBundlePath: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Run tests in parallel")
    var parallel = true

    @Flag(name: .long, help: "Retry failed tests")
    var retryOnFailure = false

    @Flag(name: .shortAndLong, help: "Interactive mode")
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
            resolvedScheme = prompt.ask("Enter test scheme name")
            if resolvedScheme.isEmpty {
                throw ValidationError("Scheme is required")
            }
        } else {
            throw ValidationError("--scheme is required (or use --interactive)")
        }

        // Use simulator destination for tests
        let resolvedDestination = destination ?? platform.simulatorDestination

        let options = TestOptions(
            project: project,
            workspace: workspace,
            scheme: resolvedScheme,
            destination: resolvedDestination,
            configuration: configuration,
            testPlan: testPlan,
            onlyTesting: onlyTesting.isEmpty ? nil : onlyTesting,
            skipTesting: skipTesting.isEmpty ? nil : skipTesting,
            resultBundlePath: resultBundlePath,
            parallel: parallel,
            retryOnFailure: retryOnFailure
        )

        let context = ActionContext.current(interactive: interactive)
        let action = TestAction()

        do {
            try action.validate(options: options)
            let output = try await action.run(options: options, context: context)

            if json {
                printJSON(output)
            } else {
                if output.passed {
                    prompt.success("All \(output.totalTests) tests passed")
                } else {
                    prompt.error("\(output.failedTests) of \(output.totalTests) tests failed")
                }
                print("  Duration: \(DurationFormatter.format(output.duration))")
                if let resultPath = output.resultBundlePath {
                    print("  Results: \(resultPath.path)")
                }
            }

            if !output.passed {
                throw ExitCode.failure
            }
        } catch let error as TestError {
            if json {
                printJSONError(error)
            } else {
                prompt.error(error.localizedDescription)
            }
            throw ExitCode.failure
        }
    }

    private func printJSON(_ output: TestOutput) {
        let result: [String: Any] = [
            "success": output.passed,
            "totalTests": output.totalTests,
            "failedTests": output.failedTests,
            "skippedTests": output.skippedTests,
            "duration": output.duration,
            "resultBundlePath": output.resultBundlePath?.path as Any,
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
