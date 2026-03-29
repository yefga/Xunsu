//
//  CredentialStore.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Signing identity information
public struct SigningIdentity: Sendable {
    public let name: String
    public let hash: String?

    public init(name: String, hash: String? = nil) {
        self.name = name
        self.hash = hash
    }
}

/// Centralized credential management
public actor CredentialStore {
    public init() {}

    /// List available code signing identities using security command
    public func listSigningIdentities() async throws -> [SigningIdentity] {
        let process = ProcessRunner()
        let result = try await process.run(
            "/usr/bin/security",
            arguments: ["find-identity", "-v", "-p", "codesigning"]
        )

        guard result.succeeded else {
            return []
        }

        // Parse output: "  1) ABC123 \"Developer ID Application: Name (TEAM)\""
        var identities: [SigningIdentity] = []
        let lines = result.stdout.components(separatedBy: "\n")

        for line in lines {
            // Match pattern: number) hash "identity name"
            if let range = line.range(of: #"\d+\)\s+([A-F0-9]+)\s+"([^"]+)""#, options: .regularExpression) {
                let match = String(line[range])
                // Extract hash and name
                if let hashRange = match.range(of: #"[A-F0-9]+"#, options: .regularExpression),
                   let nameRange = match.range(of: #""[^"]+""#, options: .regularExpression)
                {
                    let hash = String(match[hashRange])
                    var name = String(match[nameRange])
                    name = String(name.dropFirst().dropLast()) // Remove quotes
                    identities.append(SigningIdentity(name: name, hash: hash))
                }
            }
        }

        return identities
    }
}
