# Clippy

Clippy is a premium native macOS clipboard history app with a persistent menu bar icon, global shortcuts, local-only storage, and a fast command-palette style history panel.

## Features

- Text, link, and image clipboard history
- Persistent top menu bar icon
- Floating keyboard-first history panel
- Fuzzy search and quick number selection
- Pin, delete, clear, pause capture, and app exclusions
- Configurable global shortcuts
- Optional auto-paste with macOS Accessibility permission
- Optional launch at login
- Local-only privacy posture

## Development

Xcode is installed at:

```sh
/Applications/Xcode.app
```

This environment can use it per command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

To make the Xcode selection persistent on the Mac, run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The app can also be opened from `Package.swift` in Xcode. A full Mac App Store archive should be produced from full Xcode with any distribution entitlements required for that target.

To build a local `.app` bundle for testing:

```sh
Scripts/package_app.sh
```

That creates:

```sh
Build/Clippy.app
```
