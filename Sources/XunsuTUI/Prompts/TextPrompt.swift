//
//  TextPrompt.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Simple text prompts for interactive mode
public struct TextPrompt: Sendable {
    private let style: TerminalStyle

    public init(useColors: Bool = true) {
        self.style = TerminalStyle(useColors: useColors)
    }

    /// Prompt for text input
    public func ask(_ question: String, default defaultValue: String? = nil) -> String {
        let defaultHint = defaultValue.map { " [\($0)]" } ?? ""
        print("\(style.info("?")) \(question)\(style.dim(defaultHint)): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return defaultValue ?? ""
        }

        if input.isEmpty {
            return defaultValue ?? ""
        }

        return input
    }

    /// Prompt for yes/no confirmation
    public func confirm(_ question: String, default defaultValue: Bool = true) -> Bool {
        let hint = defaultValue ? "[Y/n]" : "[y/N]"
        print("\(style.info("?")) \(question) \(style.dim(hint)): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return defaultValue
        }

        if input.isEmpty {
            return defaultValue
        }

        return input == "y" || input == "yes"
    }

    /// Prompt for password (hidden input)
    public func password(_ question: String) -> String {
        print("\(style.info("?")) \(question): ", terminator: "")
        fflush(stdout)

        // Disable echo for password input
        var oldTermios = termios()
        tcgetattr(STDIN_FILENO, &oldTermios)

        var newTermios = oldTermios
        newTermios.c_lflag &= ~UInt(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &newTermios)

        let password = readLine() ?? ""

        // Restore echo
        tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
        print() // New line after hidden input

        return password
    }

    /// Display an info message
    public func info(_ message: String) {
        print("\(style.info("ℹ")) \(message)")
    }

    /// Display a success message
    public func success(_ message: String) {
        print("\(style.checkmark) \(message)")
    }

    /// Display a warning message
    public func warning(_ message: String) {
        print("\(style.warning("⚠")) \(message)")
    }

    /// Display an error message
    public func error(_ message: String) {
        print("\(style.cross) \(style.error(message))")
    }
}
