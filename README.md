# 🔐 ClawBox

**AI-Native Secret Manager** — Securely manage secrets for AI assistant collaboration

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)]()

[📖 中文文档](docs/README_CN.md)

---

## 🎯 Why ClawBox?

When using AI assistants (Claude, GPT, Copilot), you often need them to access your API keys:

- 🏦 Exchange APIs (Binance, Coinbase)
- ☁️ Cloud Services (AWS, GCP, Azure)
- 🔧 Dev Tools (GitHub, GitLab, Docker)
- 📡 Various SaaS APIs

**Problems with existing solutions:**

| Solution | Issue |
|----------|-------|
| Paste keys directly | Exposed in chat history ❌ |
| Environment variables | Messy multi-project management ❌ |
| 1Password | Not designed for AI ❌ |
| HashiCorp Vault | Too heavy, over-engineered ❌ |

**ClawBox solution:**

```
👤 Human                    🤖 AI Assistant
   │                          │
   │  Manage (GUI/CLI)        │  Read (CLI)
   │         ↘              ↙         │
   │          ┌──────────┐            │
   │          │ ClawBox  │            │
   │          │ Encrypted │            │
   │          │ Controlled│            │
   │          │ Audited   │            │
   │          └──────────┘            │
   │                                  │
   └──── Approve sensitive ops ◄──────┘
```

---

## ✨ Key Features

### 🔒 Security First
- **AES-256-GCM** encrypted storage
- **Master password** protection with optional hardware keys
- **Zero-knowledge** — we never see your secrets

### 🤖 AI Friendly
- Simple **CLI interface** for AI assistants
- **JSON output** for structured parsing
- **Read-only mode** for AI access

### 👤 Human Control
- **Access levels** — control what AI can access
- **Approval workflow** — sensitive keys require human confirmation
- **Audit logs** — who accessed what and when

### 📱 Multi-platform
- **CLI** — Command line for AI assistants
- **macOS App** — Native GUI (coming soon)
- **Browser Extension** — Web integration (planned)

---

## 🚀 Quick Start

### Installation

```bash
# macOS (Homebrew)
brew install clawbox/tap/clawbox

# Or download binary
curl -sSL https://get.clawbox.sh | sh
```

### Initialize

```bash
# Create vault
clawbox init

# Set master password
Enter master password: ********
Confirm password: ********
✓ Vault created at ~/.clawbox/vault.db
```

### Basic Usage

```bash
# Set a secret
clawbox set binance/api-key "your-api-key"
clawbox set binance/api-secret "your-api-secret" --access sensitive

# Get a secret
clawbox get binance/api-key
# → your-api-key

# List all secrets
clawbox list
# → binance/api-key
# → binance/api-secret [sensitive]

# JSON output (AI friendly)
clawbox get binance/api-key --json
# → {"key": "binance/api-key", "value": "your-api-key"}
```

### AI Assistant Usage

```bash
# AI can retrieve secrets like this
API_KEY=$(clawbox get binance/api-key)
API_SECRET=$(clawbox get binance/api-secret)

# Then call APIs
curl -H "X-MBX-APIKEY: $API_KEY" ...
```

---

## 📖 Documentation

- [Installation Guide](docs/installation.md)
- [CLI Reference](docs/CLI-REFERENCE.md)
- [macOS App Guide](docs/macos-app.md)
- [Security Model](docs/SECURITY.md)
- [AI Integration](docs/ai-integration.md)
- [API Documentation](docs/api.md)

---

## 🗺️ Roadmap

### v0.1.0 - MVP (CLI Basic)
- [x] Project setup
- [ ] Encryption engine
- [ ] Basic CRUD commands
- [ ] Master password protection

### v0.2.0 - Permissions & Audit
- [ ] AI access control
- [ ] Audit logging
- [ ] Key grouping/tags

### v0.3.0 - macOS App
- [ ] SwiftUI native app
- [ ] Menu bar access
- [ ] Keychain integration

### v0.4.0 - Advanced Security
- [ ] Hardware key support (YubiKey)
- [ ] Biometric unlock (Touch ID)
- [ ] Key expiration (TTL)

### v0.5.0 - Sync & Share
- [ ] E2E encrypted cloud sync
- [ ] Team shared vaults
- [ ] Import/Export

### v1.0.0 - Production Release
- [ ] Stable API
- [ ] Full documentation
- [ ] Browser extension

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      ClawBox                            │
├─────────────────┬─────────────────┬─────────────────────┤
│      CLI        │   macOS App     │   Browser Extension │
│    (Rust)       │   (Swift)       │   (TypeScript)      │
└────────┬────────┴────────┬────────┴──────────┬──────────┘
         │                 │                   │
         └─────────────────┼───────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Core Lib   │
                    │   (Rust)    │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
    │ Crypto  │      │ Storage │      │  Audit  │
    │AES-256  │      │ SQLite  │      │  Log    │
    └─────────┘      └─────────┘      └─────────┘
```

### Tech Stack

| Component | Technology | Reason |
|-----------|------------|--------|
| Core | Rust | Security, performance, single binary |
| CLI | Rust (clap) | Unified stack |
| macOS App | Swift/SwiftUI | Native experience |
| Encryption | libsodium | Industry standard |
| Storage | SQLite | Lightweight, reliable |

---

## 🔐 Security Model

### Encryption

```
Master Password
      │
      ▼
   Argon2id (key derivation)
      │
      ▼
  Derived Key (256-bit)
      │
      ▼
  AES-256-GCM (encrypt secrets)
      │
      ▼
  Encrypted Vault (SQLite)
```

### Access Levels

| Level | Description | AI Access |
|-------|-------------|-----------|
| `public` | Public info | ✅ Free access |
| `normal` | Regular keys | ✅ Requires unlock |
| `sensitive` | Sensitive keys | ⚠️ Requires approval |
| `critical` | Critical keys | ❌ Human only |

---

## 🤝 OpenClaw Integration

ClawBox is designed for the [OpenClaw](https://github.com/openclaw/openclaw) ecosystem:

```yaml
# openclaw.yaml
tools:
  clawbox:
    enabled: true
    vault: ~/.clawbox
    ai_access: normal
```

---

## 🧑‍💻 Development

```bash
# Clone repo
git clone https://github.com/HarrisHan/clawbox.git
cd clawbox

# Build CLI
cargo build --release

# Run tests
cargo test

# Build macOS App
cd macos-app
xcodebuild -scheme ClawBox -configuration Release
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 🙏 Credits

- [libsodium](https://libsodium.org/) - Crypto library
- [SQLite](https://sqlite.org/) - Storage engine
- [clap](https://clap.rs/) - CLI framework
- [OpenClaw](https://openclaw.ai/) - AI assistant platform

---

<p align="center">
  <b>ClawBox</b> — Let AI access your secrets securely 🔐
</p>
