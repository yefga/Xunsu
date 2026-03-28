//
//  Theme.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// ANSI color codes for terminal output
public enum ANSIColor: String, Sendable {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"

    // Foreground colors
    case black = "\u{001B}[30m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"

    // Bright foreground colors
    case brightBlack = "\u{001B}[90m"
    case brightRed = "\u{001B}[91m"
    case brightGreen = "\u{001B}[92m"
    case brightYellow = "\u{001B}[93m"
    case brightBlue = "\u{001B}[94m"
    case brightMagenta = "\u{001B}[95m"
    case brightCyan = "\u{001B}[96m"
    case brightWhite = "\u{001B}[97m"
}

/// Theme for Xunsu CLI output
public struct XunsuTheme: Sendable {
    public let success: ANSIColor
    public let error: ANSIColor
    public let warning: ANSIColor
    public let info: ANSIColor
    public let highlight: ANSIColor
    public let dim: ANSIColor

    public static let `default` = XunsuTheme(
        success: .green,
        error: .red,
        warning: .yellow,
        info: .cyan,
        highlight: .brightWhite,
        dim: .brightBlack
    )

    public init(
        success: ANSIColor,
        error: ANSIColor,
        warning: ANSIColor,
        info: ANSIColor,
        highlight: ANSIColor,
        dim: ANSIColor
    ) {
        self.success = success
        self.error = error
        self.warning = warning
        self.info = info
        self.highlight = highlight
        self.dim = dim
    }
}

/// Helper for styled terminal output
public struct TerminalStyle: Sendable {
    private let useColors: Bool
    private let theme: XunsuTheme

    public init(useColors: Bool = true, theme: XunsuTheme = .default) {
        self.useColors = useColors
        self.theme = theme
    }

    public func success(_ text: String) -> String {
        styled(text, color: theme.success)
    }

    public func error(_ text: String) -> String {
        styled(text, color: theme.error)
    }

    public func warning(_ text: String) -> String {
        styled(text, color: theme.warning)
    }

    public func info(_ text: String) -> String {
        styled(text, color: theme.info)
    }

    public func highlight(_ text: String) -> String {
        styled(text, color: theme.highlight)
    }

    public func dim(_ text: String) -> String {
        styled(text, color: theme.dim)
    }

    public func bold(_ text: String) -> String {
        styled(text, color: .bold)
    }

    private func styled(_ text: String, color: ANSIColor) -> String {
        guard useColors else { return text }
        return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }

    // Status indicators
    public var checkmark: String { success("✓") }
    public var cross: String { error("✗") }
    public var arrow: String { info("→") }
    public var bullet: String { dim("•") }
}
