<p align="center">
  <img src="logo.png" alt="Xunsu Logo" width="200">
</p>

# Xunsu

A lightweight alternative to fastlane, written entirely in Swift 6.

> **Xunsu** (迅速) means "swift" or "rapid" in Chinese.

## Why Xunsu?

- **Pure Swift** - Fast startup, near-instant execution
- **Interactive TUI** - Guided prompts when you need them
- **CI/CD ready** - All options available via flags or environment variables

## Installation

### Homebrew

```bash
brew install yefga/tap/xunsu
```

### Build from source

Requires Swift 6.0 (Xcode 16+):

```bash
git clone https://github.com/yefga/Xunsu.git
cd Xunsu
swift build -c release
cp .build/release/xunsu /usr/local/bin/
```

## Commands

| Command | Description |
|---------|-------------|
| `xunsu build` | Build and archive apps for iOS, macOS, watchOS, tvOS, visionOS |
| `xunsu test` | Run unit and UI tests |
| `xunsu seal` | Create, sign, and notarize DMGs for macOS distribution |
| `xunsu apk` | Build Flutter APK or App Bundle for Android |
| `xunsu devices` | List available simulators and devices |
| `xunsu init` | Initialize project configuration |

## Quick Start

### Build an iOS app

```bash
# Archive for device
xunsu build --scheme MyApp --platform ios

# Build for simulator (no signing required)
xunsu build --scheme MyApp --platform ios --simulator
```

### Build a macOS app

```bash
xunsu build --scheme MyApp --platform macos
```

### Run tests

```bash
xunsu test --scheme MyApp --platform ios
```

### Create and notarize a DMG

```bash
# Interactive mode - prompts guide you through
xunsu seal --interactive

# Or specify everything via flags
xunsu seal \
  --app ./build/MyApp.app \
  --output ./release/MyApp.dmg \
  --identity "Developer ID Application: Your Name (TEAM)" \
  --notary-profile my-notary-profile
```

### Build Flutter APK

```bash
xunsu apk --build-type release --output apk
```

## CI/CD Usage

All commands work in non-interactive mode by default. Use environment variables or flags:

```yaml
# GitHub Actions example
- name: Build and Notarize
  env:
    NOTARY_APPLE_ID: ${{ secrets.APPLE_ID }}
    NOTARY_TEAM_ID: ${{ secrets.TEAM_ID }}
    NOTARY_PASSWORD: ${{ secrets.APP_SPECIFIC_PASSWORD }}
  run: |
    xunsu build --scheme MyApp --platform macos
    xunsu seal \
      --app ./build/MyApp.xcarchive/Products/Applications/MyApp.app \
      --output ./release/MyApp.dmg \
      --identity "$SIGNING_IDENTITY" \
      --notary-apple-id "$NOTARY_APPLE_ID" \
      --notary-team-id "$NOTARY_TEAM_ID" \
      --notary-password "$NOTARY_PASSWORD"
```

## Requirements

- macOS 13 or later
- Swift 6.0 / Xcode 16+ (to build from source)
- For notarization: Apple Developer account with Developer ID certificate

## Project Structure

```
Xunsu/
├── Sources/
│   ├── xunsu/           # CLI entry point
│   ├── XunsuCLI/        # Command definitions (ArgumentParser)
│   ├── XunsuCore/       # ProcessRunner, Action protocol, Keychain
│   ├── XunsuActions/    # Build, Test, Seal, APK actions
│   └── XunsuTUI/        # Interactive prompts and spinners
└── Tests/
```

## License

MIT

## Contributing

Contributions welcome. Please open an issue first to discuss what you'd like to change.

---

Built with Swift by [@yefga](https://github.com/yefga)
