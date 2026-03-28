// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Xunsu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "xunsu", targets: ["xunsu"]),
        .library(name: "XunsuCore", targets: ["XunsuCore"]),
        .library(name: "XunsuActions", targets: ["XunsuActions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    ],
    targets: [
        // Main executable
        .executableTarget(
            name: "xunsu",
            dependencies: [
                "XunsuCLI",
            ]
        ),

        // CLI layer - command definitions
        .target(
            name: "XunsuCLI",
            dependencies: [
                "XunsuCore",
                "XunsuActions",
                "XunsuTUI",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // TUI components - interactive prompts (pure Swift, no external deps)
        .target(
            name: "XunsuTUI",
            dependencies: [
                "XunsuCore",
            ]
        ),

        // Core abstractions - Action, ProcessRunner, Credentials
        .target(
            name: "XunsuCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // Built-in actions - build, seal, test, etc.
        .target(
            name: "XunsuActions",
            dependencies: [
                "XunsuCore",
            ]
        ),

        // Tests
        .testTarget(
            name: "XunsuCoreTests",
            dependencies: ["XunsuCore"]
        ),
        .testTarget(
            name: "XunsuActionsTests",
            dependencies: ["XunsuActions", "XunsuCore"]
        ),
    ]
)
