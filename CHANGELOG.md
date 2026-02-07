# Changelog

All notable changes to ClawBox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-07

### 🎉 First Stable Release

ClawBox is now production-ready! This release marks the culmination of the MVP development phase.

### Added
- Complete CLI with all CRUD operations
- macOS native app with SwiftUI
- Touch ID / Face ID authentication
- Auto-lock policies
- Export/Import (JSON, YAML, ENV)
- Audit logging with hash chain
- Access levels (public, normal, sensitive, critical)
- GitHub Actions CI/CD

### Security
- AES-256-GCM encryption
- Argon2id key derivation
- SQLite with 600 permissions
- Path traversal protection
- Null byte injection prevention

## [0.5.0] - 2026-02-07

### Added
- Export command (JSON, YAML, ENV formats)
- Import command with skip-existing option
- Sync framework foundation
- iCloud backend structure

## [0.4.0] - 2026-02-07

### Added
- Touch ID / Face ID unlock
- Keychain integration
- Auto-lock service
- Settings view
- Screen lock detection

### Changed
- Version bump to 0.4.0 in Xcode project

## [0.3.0] - 2026-02-07

### Added
- macOS SwiftUI app
- NavigationSplitView for secrets
- Menu bar extra
- Secret detail view
- Add secret sheet
- Clipboard auto-clear (30s)

## [0.2.0] - 2026-02-07

### Added
- Full audit logging system
- Tamper-evident hash chain
- `clawbox audit` command
- JSON audit export
- Audit filtering (--since, --key)

## [0.1.0] - 2026-02-07

### Added
- GitHub Actions CI workflow
- Release workflow for multi-platform builds
- Complete test coverage

## [0.0.3] - 2026-02-07

### Fixed
- Path traversal vulnerability
- File permissions (644 → 600)

### Security
- Reject `..`, `/`, null bytes in key paths

## [0.0.2] - 2026-02-07

### Fixed
- Non-TTY password input for automation

### Added
- `CLAWBOX_PASSWORD` environment variable support

## [0.0.1] - 2026-02-07

### Added
- Initial release
- Core encryption (AES-256-GCM, Argon2id)
- CLI: init, set, get, list, delete, lock, unlock
- SQLite storage
- FFI bindings for Swift
- Documentation (PRD, Architecture, Security, Roadmap)

[1.0.0]: https://github.com/HarrisHan/clawbox/releases/tag/v1.0.0
[0.5.0]: https://github.com/HarrisHan/clawbox/releases/tag/v0.5.0
[0.4.0]: https://github.com/HarrisHan/clawbox/releases/tag/v0.4.0
[0.3.0]: https://github.com/HarrisHan/clawbox/releases/tag/v0.3.0
[0.2.0]: https://github.com/HarrisHan/clawbox/releases/tag/v0.2.0
[0.1.0]: https://github.com/HarrisHan/clawbox/releases/tag/v0.1.0
[0.0.3]: https://github.com/HarrisHan/clawbox/releases/tag/v0.0.3
[0.0.2]: https://github.com/HarrisHan/clawbox/releases/tag/v0.0.2
[0.0.1]: https://github.com/HarrisHan/clawbox/releases/tag/v0.0.1
