//
//  Action.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Category of an action for organization
public enum ActionCategory: String, Codable, Sendable {
    case building
    case signing
    case testing
    case distribution
    case utility
}

/// Protocol that all Xunsu actions must conform to
public protocol Action: Sendable {
    associatedtype Options: Codable & Sendable
    associatedtype Output: Sendable

    /// Unique name of the action (used in CLI)
    static var name: String { get }

    /// Human-readable description
    static var description: String { get }

    /// Category for organization
    static var category: ActionCategory { get }

    /// Execute the action with given options
    func run(options: Options, context: ActionContext) async throws -> Output

    /// Validate options before running (optional)
    func validate(options: Options) throws
}

/// Default implementation for validate
public extension Action {
    func validate(options: Options) throws {
        // No validation by default
    }
}

/// Errors that can occur during action execution
public enum ActionError: Error, LocalizedError {
    case invalidOptions(String)
    case executionFailed(String)
    case missingDependency(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidOptions(let message):
            return "Invalid options: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .missingDependency(let name):
            return "Missing dependency: \(name)"
        case .cancelled:
            return "Action was cancelled"
        }
    }
}
