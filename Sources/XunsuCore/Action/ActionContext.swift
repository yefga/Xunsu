//
//  ActionContext.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation
import Logging

/// Shared context for action execution
public actor ActionContext {
    /// Path to the project directory
    public let projectPath: URL

    /// Logger for output
    public let logger: Logger

    /// Process runner for shell commands
    public let processRunner: ProcessRunner

    /// Environment variables
    private var environment: [String: String]

    /// Artifacts produced by actions (for passing between actions)
    private var artifacts: [String: Any] = [:]

    /// Whether we're running in CI environment
    public let isCI: Bool

    /// Whether interactive mode is enabled
    public let interactive: Bool

    public init(
        projectPath: URL,
        logger: Logger = Logger(label: "com.xunsu.action"),
        environment: [String: String]? = nil,
        interactive: Bool = false
    ) {
        self.projectPath = projectPath
        self.logger = logger
        self.processRunner = ProcessRunner(logger: logger)
        self.environment = environment ?? ProcessInfo.processInfo.environment
        self.interactive = interactive

        // Detect CI environment
        self.isCI = ProcessInfo.processInfo.environment["CI"] != nil
            || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
            || ProcessInfo.processInfo.environment["GITLAB_CI"] != nil
    }

    /// Get an environment variable
    public func env(_ key: String) -> String? {
        environment[key]
    }

    /// Set an environment variable
    public func setEnv(_ key: String, value: String) {
        environment[key] = value
    }

    /// Store an artifact for later retrieval
    public func setArtifact<T: Sendable>(_ key: String, value: T) {
        artifacts[key] = value
    }

    /// Retrieve a stored artifact
    public func getArtifact<T>(_ key: String) -> T? {
        artifacts[key] as? T
    }

    /// Get the current environment dictionary
    public func getEnvironment() -> [String: String] {
        environment
    }

    /// Create a child context with the same settings
    public func childContext() -> ActionContext {
        ActionContext(
            projectPath: projectPath,
            logger: logger,
            environment: environment,
            interactive: interactive
        )
    }
}

/// Convenience for creating context from current directory
public extension ActionContext {
    static func current(interactive: Bool = false) -> ActionContext {
        ActionContext(
            projectPath: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            interactive: interactive
        )
    }
}
