//
//  Spinner.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Animated spinner for long-running operations
public final class Spinner: @unchecked Sendable {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var frameIndex = 0
    private var isRunning = false
    private var message: String = ""
    private var spinnerThread: Thread?
    private let useColors: Bool

    public init(useColors: Bool = true) {
        self.useColors = useColors
    }

    /// Start the spinner with a message
    public func start(_ message: String) {
        guard !isRunning else { return }
        self.message = message
        self.isRunning = true
        self.frameIndex = 0

        spinnerThread = Thread { [weak self] in
            while let self = self, self.isRunning {
                self.render()
                Thread.sleep(forTimeInterval: 0.08)
            }
        }
        spinnerThread?.start()
    }

    /// Update the spinner message
    public func update(_ message: String) {
        self.message = message
    }

    /// Stop spinner with success
    public func success(_ message: String? = nil) {
        stop()
        let finalMessage = message ?? self.message
        let checkmark = useColors ? "\u{001B}[32m✓\u{001B}[0m" : "✓"
        print("\r\u{001B}[2K\(checkmark) \(finalMessage)")
    }

    /// Stop spinner with failure
    public func failure(_ message: String? = nil) {
        stop()
        let finalMessage = message ?? self.message
        let cross = useColors ? "\u{001B}[31m✗\u{001B}[0m" : "✗"
        let errorMsg = useColors ? "\u{001B}[31m\(finalMessage)\u{001B}[0m" : finalMessage
        print("\r\u{001B}[2K\(cross) \(errorMsg)")
    }

    /// Stop spinner without status message
    public func stop() {
        isRunning = false
        spinnerThread = nil
        print("\r\u{001B}[2K", terminator: "")
        fflush(stdout)
    }

    private func render() {
        let frame = frames[frameIndex]
        frameIndex = (frameIndex + 1) % frames.count
        let coloredFrame = useColors ? "\u{001B}[36m\(frame)\u{001B}[0m" : frame
        print("\r\u{001B}[2K\(coloredFrame) \(message)", terminator: "")
        fflush(stdout)
    }
}

/// Convenience function to run an async operation with a spinner
public func withSpinner<T: Sendable>(
    _ message: String,
    useColors: Bool = true,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let spinner = Spinner(useColors: useColors)
    spinner.start(message)

    do {
        let result = try await operation()
        spinner.success()
        return result
    } catch {
        spinner.failure(error.localizedDescription)
        throw error
    }
}
