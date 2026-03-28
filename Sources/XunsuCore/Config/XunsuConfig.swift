//
//  XunsuConfig.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Global Xunsu configuration
public struct XunsuConfig: Codable, Sendable {
    /// Default signing identity
    public var signingIdentity: String?

    /// Default notary profile name
    public var notaryProfile: String?

    /// Default team ID
    public var teamID: String?

    /// Output format (text, json)
    public var outputFormat: OutputFormat

    /// Whether to use colors in output
    public var useColors: Bool

    public init(
        signingIdentity: String? = nil,
        notaryProfile: String? = nil,
        teamID: String? = nil,
        outputFormat: OutputFormat = .text,
        useColors: Bool = true
    ) {
        self.signingIdentity = signingIdentity
        self.notaryProfile = notaryProfile
        self.teamID = teamID
        self.outputFormat = outputFormat
        self.useColors = useColors
    }

    /// Load configuration from file
    public static func load(from path: URL) throws -> XunsuConfig {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(XunsuConfig.self, from: data)
    }

    /// Save configuration to file
    public func save(to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: path)
    }

    /// Default config file path
    public static var defaultPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".xunsu/config.json")
    }

    /// Load default config or return empty
    public static func loadDefault() -> XunsuConfig {
        do {
            return try load(from: defaultPath)
        } catch {
            return XunsuConfig()
        }
    }
}

/// Output format for CLI
public enum OutputFormat: String, Codable, Sendable {
    case text
    case json
}
