# 🔐 ClawBox

**AI-Native Secret Manager** — Built for humans and AI agents alike.

[![CI](https://github.com/HarrisHan/clawbox/actions/workflows/ci.yml/badge.svg)](https://github.com/HarrisHan/clawbox/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/HarrisHan/clawbox)](https://github.com/HarrisHan/clawbox/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## ✨ Features

- 🔒 **Military-Grade Encryption**: AES-256-GCM + Argon2id
- 🤖 **AI-Ready**: JSON output, env vars, non-interactive mode
- 📊 **Audit Logging**: Tamper-evident logs with hash chain
- 🍎 **macOS Native**: SwiftUI app with Touch ID support
- ☁️ **Export/Import**: JSON, YAML, ENV formats
- 🔑 **Access Levels**: public, normal, sensitive, critical

## 🚀 Quick Start

### Install

```bash
# macOS / Linux
curl -sSL https://get.clawbox.sh | sh

# Or with Homebrew (coming soon)
brew install clawbox
```

### Basic Usage

```bash
# Initialize vault
clawbox init

# Store a secret
clawbox set github/token "ghp_xxxxxxxxxxxx"

# Retrieve a secret
clawbox get github/token

# List all secrets
clawbox list

# Delete a secret
clawbox delete github/token
```

### AI Agent Usage

```bash
# Environment variable for automation
export CLAWBOX_PASSWORD="your-master-password"

# JSON output for parsing
clawbox --json get github/token
# {"path":"github/token","value":"ghp_xxxxxxxxxxxx"}

# Use in scripts
TOKEN=$(clawbox get github/token)
curl -H "Authorization: token $TOKEN" https://api.github.com/user
```

## 📦 Export & Import

```bash
# Export to JSON
clawbox export backup.json

# Export to ENV format
clawbox export secrets.env --format env

# Import from file
clawbox import backup.json

# Import with skip existing
clawbox import backup.json --skip-existing
```

## 📊 Audit Log

```bash
# View recent audit entries
clawbox audit

# Filter by time
clawbox audit --since 24h

# JSON output
clawbox --json audit
```

## 🔐 Security

- **Encryption**: AES-256-GCM with random nonces
- **Key Derivation**: Argon2id (m=64MB, t=3, p=4)
- **Storage**: SQLite with 600 permissions
- **Audit**: SHA-256 hash chain for integrity

### Access Levels

| Level | Description |
|-------|-------------|
| `public` | AI can access freely |
| `normal` | Default, vault unlocked required |
| `sensitive` | AI access requires approval |
| `critical` | Human only |

```bash
clawbox set api/key "xxx" --access sensitive
```

## 🍎 macOS App

The macOS app provides:
- Touch ID / Face ID unlock
- Menu bar quick access
- Auto-lock on timeout/screen lock
- Visual secret management

Build from source:
```bash
cd macos-app/ClawBox
open ClawBox.xcodeproj
# Cmd+R to run
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                   ClawBox                        │
├──────────────┬──────────────┬──────────────┬────┤
│   CLI        │  macOS App   │   FFI        │ API│
├──────────────┴──────────────┴──────────────┴────┤
│                 clawbox-core                     │
├─────────────────────────────────────────────────┤
│  Crypto     │  Storage    │  Audit    │  Sync   │
│  (AES-GCM)  │  (SQLite)   │  (Chain)  │ (iCloud)│
└─────────────────────────────────────────────────┘
```

## 📁 File Structure

```
~/.clawbox/
├── vault.db       # Encrypted secrets (SQLite)
└── audit.log      # Audit trail (if enabled)
```

## 🛠️ Development

```bash
# Clone
git clone https://github.com/HarrisHan/clawbox.git
cd clawbox

# Build
cargo build --release

# Test
cargo test

# Run
./target/release/clawbox --help
```

## 📖 Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Security](docs/SECURITY.md)
- [Roadmap](docs/ROADMAP.md)
- [CLI Reference](docs/CLI_REFERENCE.md)

## 🗺️ Roadmap

- [x] v0.1.0 - MVP CLI
- [x] v0.2.0 - Audit Logging
- [x] v0.3.0 - macOS App
- [x] v0.4.0 - Touch ID / Auto-Lock
- [x] v0.5.0 - Export / Import
- [x] v1.0.0 - Stable Release
- [ ] v1.1.0 - Browser Extension
- [ ] v1.2.0 - Mobile Apps

## 🤝 Contributing

Contributions welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

## 📄 License

MIT © [Harris Han](https://github.com/HarrisHan)

---

Made with ❤️ for the AI-native future.
