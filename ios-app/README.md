# ClawBox iOS App

Native iOS app for ClawBox - AI-Native Secret Manager.

## Features

- 🔐 Secure vault with master password
- 🆔 Face ID / Touch ID unlock
- 📋 Copy secrets to clipboard (auto-clear after 30s)
- 🔍 Search secrets
- ➕ Add/delete secrets
- 🔒 Auto-lock

## Screenshots

*(Coming soon)*

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Open `ClawBox.xcodeproj` in Xcode
2. Select your development team
3. Build and run on device/simulator

## Architecture

```
ClawBox/
├── ClawBoxApp.swift      # App entry point
├── ContentView.swift     # Main views
└── VaultManager.swift    # Vault operations + crypto
```

## Security

- Keychain storage for all sensitive data
- AES-256-GCM encryption
- PBKDF2 key derivation (100k iterations)
- Auto-lock on background
- Clipboard auto-clear (30 seconds)

## Build

```bash
# Open in Xcode
open ios-app/ClawBox/ClawBox.xcodeproj

# Or build from command line
xcodebuild -project ClawBox.xcodeproj -scheme ClawBox -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

MIT © Harris Han
