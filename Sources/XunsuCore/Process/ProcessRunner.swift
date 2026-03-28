//
//  ProcessRunner.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import Logging

/// Result of a process execution
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool { exitCode == 0 }

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Errors that can occur during process execution
public enum ProcessError: Error, LocalizedError {
    case executionFailed(exitCode: Int32, stderr: String)
    case processNotFound(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let code, let stderr):
            return "Process failed with exit code \(code): \(stderr)"
        case .processNotFound(let path):
            return "Process not found: \(path)"
        case .timeout:
            return "Process timed out"
        }
    }
}

/// Actor for running shell processes safely
public actor ProcessRunner {
    private let logger: Logger

    public init(logger: Logger = Logger(label: "com.xunsu.process")) {
        self.logger = logger
    }

    /// Run a process and capture its output
    public func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil
    ) async throws -> ProcessResult {
        logger.debug("Running: \(executable) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            process.environment = processEnv
        }

        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                let result = ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                )

                logger.debug("Process completed with exit code \(result.exitCode)")
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a process with real-time output streaming
    public func runStreaming(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        logger.debug("Running (streaming): \(executable) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            process.environment = processEnv
        }

        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Handle stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                onOutput(str)
            }
        }

        // Handle stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                onOutput(str)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                process.terminationHandler = { proc in
                    // Clean up handlers
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    continuation.resume(returning: proc.terminationStatus)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Helper to run xcrun commands
    public func xcrun(
        _ tool: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        try await run(
            "/usr/bin/xcrun",
            arguments: [tool] + arguments,
            environment: environment
        )
    }
}
