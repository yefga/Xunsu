//
//  ProgressDisplay.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Progress display for long-running operations
public actor ProgressDisplay {
    private let style: TerminalStyle
    private var isRunning = false
    private var currentMessage: String = ""
    private var spinnerTask: Task<Void, Never>?

    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var frameIndex = 0

    public init(useColors: Bool = true) {
        self.style = TerminalStyle(useColors: useColors)
    }

    /// Start showing a spinner with a message
    public func start(_ message: String) {
        guard !isRunning else { return }
        isRunning = true
        currentMessage = message

        spinnerTask = Task { [weak self] in
            while let self = self, await self.isRunning {
                await self.renderSpinner()
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            }
        }
    }

    /// Update the current message
    public func update(_ message: String) {
        currentMessage = message
    }

    /// Stop the spinner and show success
    public func success(_ message: String? = nil) {
        stop()
        let finalMessage = message ?? currentMessage
        print("\r\(clearLine())\(style.checkmark) \(finalMessage)")
    }

    /// Stop the spinner and show failure
    public func failure(_ message: String? = nil) {
        stop()
        let finalMessage = message ?? currentMessage
        print("\r\(clearLine())\(style.cross) \(style.error(finalMessage))")
    }

    /// Stop the spinner without status
    public func stop() {
        isRunning = false
        spinnerTask?.cancel()
        spinnerTask = nil
        print("\r\(clearLine())", terminator: "")
    }

    private func renderSpinner() {
        let frame = spinnerFrames[frameIndex]
        frameIndex = (frameIndex + 1) % spinnerFrames.count
        print("\r\(clearLine())\(style.info(frame)) \(currentMessage)", terminator: "")
        fflush(stdout)
    }

    private func clearLine() -> String {
        "\u{001B}[2K"
    }
}

/// Simple progress bar
public struct ProgressBar: Sendable {
    private let width: Int
    private let style: TerminalStyle

    public init(width: Int = 40, useColors: Bool = true) {
        self.width = width
        self.style = TerminalStyle(useColors: useColors)
    }

    public func render(progress: Double, label: String = "") -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled

        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        let percentage = Int(progress * 100)

        if label.isEmpty {
            return "[\(style.info(bar))] \(percentage)%"
        } else {
            return "\(label) [\(style.info(bar))] \(percentage)%"
        }
    }
}
