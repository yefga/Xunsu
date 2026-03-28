//
//  ProcessRunnerTests.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Testing
@testable import XunsuCore

@Suite("ProcessRunner Tests")
struct ProcessRunnerTests {
    @Test("Run simple command")
    func testSimpleCommand() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run("/bin/echo", arguments: ["hello"])

        #expect(result.succeeded)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test("Run failing command")
    func testFailingCommand() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run("/usr/bin/false")

        #expect(!result.succeeded)
        #expect(result.exitCode != 0)
    }

    @Test("Run xcrun")
    func testXcrun() async throws {
        let runner = ProcessRunner()
        let result = try await runner.xcrun("--version")

        #expect(result.succeeded)
    }
}
