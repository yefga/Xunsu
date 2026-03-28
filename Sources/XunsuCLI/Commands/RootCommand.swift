//
//  RootCommand.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import ArgumentParser

public struct Xunsu: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "xunsu",
        abstract: "Swift-native iOS/macOS automation tool",
        discussion: """
            Xunsu (迅速) is a fast, interactive replacement for fastlane.
            Built in pure Swift with no Ruby dependencies.

            Commands:
              build   - Build and archive apps for any Apple platform
              test    - Run unit and UI tests
              seal    - Create, sign, and notarize DMGs
              apk     - Build Flutter APK or App Bundle
              sign    - Manage code signing certificates
              beta    - Upload to TestFlight
              release - Submit to App Store
              init    - Initialize project configuration
            """,
        version: "0.1.0",
        subcommands: [
            BuildCommand.self,
            TestCommand.self,
            SealCommand.self,
            ApkCommand.self,
            InitCommand.self,
            DevicesCommand.self,
        ]
    )
}
