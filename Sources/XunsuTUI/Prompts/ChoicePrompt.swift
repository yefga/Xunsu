//
//  ChoicePrompt.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Choice selection prompt
public struct ChoicePrompt: Sendable {
    private let style: TerminalStyle

    public init(useColors: Bool = true) {
        self.style = TerminalStyle(useColors: useColors)
    }

    /// Present a list of choices and return the selected index
    public func select<T: CustomStringConvertible>(
        _ question: String,
        choices: [T],
        default defaultIndex: Int = 0
    ) -> Int {
        print("\(style.info("?")) \(question)")

        for (index, choice) in choices.enumerated() {
            let marker = index == defaultIndex ? style.info("❯") : " "
            let number = style.dim("[\(index + 1)]")
            print("  \(marker) \(number) \(choice)")
        }

        print("\(style.dim("Enter number [1-\(choices.count)]")): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return defaultIndex
        }

        if input.isEmpty {
            return defaultIndex
        }

        if let number = Int(input), number >= 1, number <= choices.count {
            return number - 1
        }

        return defaultIndex
    }

    /// Present a list of choices and return the selected value
    public func selectValue<T: CustomStringConvertible>(
        _ question: String,
        choices: [T],
        default defaultIndex: Int = 0
    ) -> T {
        let index = select(question, choices: choices, default: defaultIndex)
        return choices[index]
    }

    /// Multi-select prompt (returns indices of selected items)
    public func multiSelect<T: CustomStringConvertible>(
        _ question: String,
        choices: [T],
        preselected: Set<Int> = []
    ) -> [Int] {
        print("\(style.info("?")) \(question)")
        print(style.dim("  (Enter comma-separated numbers, e.g., 1,3,5)"))

        for (index, choice) in choices.enumerated() {
            let marker = preselected.contains(index) ? style.success("✓") : " "
            let number = style.dim("[\(index + 1)]")
            print("  \(marker) \(number) \(choice)")
        }

        print("\(style.dim("Selection")): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return Array(preselected)
        }

        if input.isEmpty {
            return Array(preselected)
        }

        let selected = input
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 1 && $0 <= choices.count }
            .map { $0 - 1 }

        return selected
    }
}
