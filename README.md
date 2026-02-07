# 🔐 ClawBox

**AI-Native Secret Manager** — 专为 AI 助手协作设计的密钥管理工具

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)]()

---

## 🎯 为什么需要 ClawBox？

当你使用 AI 助手（Claude、GPT、Copilot）时，经常需要让 AI 访问你的 API 密钥：

- 🏦 交易所 API（Binance、Coinbase）
- ☁️ 云服务（AWS、GCP、Azure）
- 🔧 开发工具（GitHub、GitLab、Docker）
- 📡 各种 SaaS API

**现有方案的问题：**

| 方案 | 问题 |
|------|------|
| 直接粘贴密钥 | 明文暴露在聊天记录中 ❌ |
| 环境变量 | 多项目管理混乱 ❌ |
| 1Password | 不是为 AI 设计的 ❌ |
| HashiCorp Vault | 太重，过度设计 ❌ |

**ClawBox 的解决方案：**

```
👤 人类                    🤖 AI 助手
   │                          │
   │  管理密钥 (GUI/CLI)      │  读取密钥 (CLI)
   │         ↘              ↙         │
   │          ┌──────────┐            │
   │          │ ClawBox  │            │
   │          │ 加密存储  │            │
   │          │ 权限控制  │            │
   │          │ 审计日志  │            │
   │          └──────────┘            │
   │                                  │
   └──── 审批敏感操作 ◄───────────────┘
```

---

## ✨ 核心特性

### 🔒 安全第一
- **AES-256-GCM** 加密存储
- **主密码** 保护，可选硬件密钥
- **零知识架构** — 我们永远看不到你的密钥

### 🤖 AI 友好
- 简洁的 **CLI 接口**，AI 一行命令即可调用
- **JSON 输出**，结构化数据便于解析
- **只读模式**，AI 只能读不能改

### 👤 人类掌控
- **权限分级** — 哪些密钥 AI 可以访问
- **敏感操作确认** — 关键密钥需要人类审批
- **审计日志** — 谁在什么时候访问了什么

### 📱 多端支持
- **CLI** — 命令行工具，AI 助手直接调用
- **macOS App** — 原生 GUI，优雅管理
- **浏览器扩展** — 网页端快速填充（规划中）

---

## 🚀 快速开始

### 安装

```bash
# macOS (Homebrew)
brew install clawbox/tap/clawbox

# 或下载二进制
curl -sSL https://get.clawbox.dev | sh
```

### 初始化

```bash
# 创建保险库
clawbox init

# 设置主密码
Enter master password: ********
Confirm password: ********
✓ Vault created at ~/.clawbox/vault.db
```

### 基本使用

```bash
# 添加密钥
clawbox set binance/api-key "your-api-key"
clawbox set binance/api-secret "your-api-secret" --sensitive

# 读取密钥
clawbox get binance/api-key
# → your-api-key

# 列出所有密钥
clawbox list
# → binance/api-key
# → binance/api-secret [sensitive]

# JSON 输出（AI 友好）
clawbox get binance/api-key --json
# → {"key": "binance/api-key", "value": "your-api-key"}
```

### AI 助手使用示例

```bash
# AI 可以这样获取密钥
API_KEY=$(clawbox get binance/api-key)
API_SECRET=$(clawbox get binance/api-secret)

# 然后调用 API
curl -H "X-MBX-APIKEY: $API_KEY" ...
```

---

## 📖 文档

- [安装指南](docs/installation.md)
- [CLI 参考](docs/cli-reference.md)
- [macOS App 使用](docs/macos-app.md)
- [安全模型](docs/security.md)
- [AI 集成指南](docs/ai-integration.md)
- [API 文档](docs/api.md)

---

## 🗺️ 路线图

### v0.1.0 - MVP (CLI 基础版)
- [x] 项目初始化
- [ ] 加密存储引擎
- [ ] 基础 CRUD 命令
- [ ] 主密码保护

### v0.2.0 - 权限与审计
- [ ] AI 权限控制
- [ ] 审计日志
- [ ] 密钥分组/标签

### v0.3.0 - macOS App
- [ ] SwiftUI 原生应用
- [ ] 菜单栏快捷访问
- [ ] 系统 Keychain 集成

### v0.4.0 - 高级安全
- [ ] 硬件密钥支持 (YubiKey)
- [ ] 生物识别解锁 (Touch ID)
- [ ] 密钥自动过期 (TTL)

### v0.5.0 - 同步与分享
- [ ] E2E 加密云同步
- [ ] 团队共享保险库
- [ ] 密钥导入/导出

### v1.0.0 - 正式发布
- [ ] 稳定 API
- [ ] 完整文档
- [ ] 浏览器扩展

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                      ClawBox                            │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   CLI       │  │  macOS App  │  │  Browser    │     │
│  │  (Rust)     │  │  (Swift)    │  │  Extension  │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         └────────────────┼────────────────┘             │
│                          │                              │
│                   ┌──────▼──────┐                       │
│                   │  Core Lib   │                       │
│                   │   (Rust)    │                       │
│                   └──────┬──────┘                       │
│                          │                              │
│         ┌────────────────┼────────────────┐             │
│         │                │                │             │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐     │
│  │   Crypto    │  │   Storage   │  │   Audit     │     │
│  │ AES-256-GCM │  │   SQLite    │  │    Log      │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### 技术栈

| 组件 | 技术 | 理由 |
|------|------|------|
| Core | Rust | 安全、高性能、单二进制 |
| CLI | Rust (clap) | 统一技术栈 |
| macOS App | Swift/SwiftUI | 原生体验 |
| 加密 | libsodium | 业界标准 |
| 存储 | SQLite | 轻量、可靠 |
| IPC | Unix Socket | CLI ↔ App 通信 |

---

## 🔐 安全模型

### 加密

```
Master Password
      │
      ▼
   Argon2id (密钥派生)
      │
      ▼
  Derived Key (256-bit)
      │
      ▼
  AES-256-GCM (加密每个密钥)
      │
      ▼
  Encrypted Vault (SQLite)
```

### 权限级别

| 级别 | 描述 | AI 访问 |
|------|------|---------|
| `public` | 公开信息 | ✅ 自由访问 |
| `normal` | 普通密钥 | ✅ 需要解锁 |
| `sensitive` | 敏感密钥 | ⚠️ 需要确认 |
| `critical` | 关键密钥 | ❌ 仅人类访问 |

### 审计日志

每次访问都会记录：
- 时间戳
- 访问者（human/ai/app）
- 操作类型（read/write/delete）
- 密钥名称
- 来源（终端、App、API）

---

## 🤝 与 OpenClaw 集成

ClawBox 专为 [OpenClaw](https://github.com/openclaw/openclaw) 生态设计：

```yaml
# openclaw.yaml
tools:
  clawbox:
    enabled: true
    vault: ~/.clawbox
    ai_access: normal  # AI 可访问 normal 级别密钥
```

AI 助手可以直接调用：

```bash
# 在 OpenClaw 会话中
clawbox get github/token
```

---

## 📦 安装包

| 平台 | 格式 | 下载 |
|------|------|------|
| macOS (Apple Silicon) | `.dmg` / `.pkg` | [下载]() |
| macOS (Intel) | `.dmg` / `.pkg` | [下载]() |
| Linux (x64) | `.tar.gz` / `.deb` | [下载]() |
| Windows | `.msi` / `.exe` | [下载]() |

---

## 🧑‍💻 开发

```bash
# 克隆仓库
git clone https://github.com/AIClaw/clawbox.git
cd clawbox

# 构建 CLI
cargo build --release

# 运行测试
cargo test

# 构建 macOS App
cd macos-app
xcodebuild -scheme ClawBox -configuration Release
```

---

## 📄 License

MIT License - 详见 [LICENSE](LICENSE)

---

## 🙏 致谢

- [libsodium](https://libsodium.org/) - 加密库
- [SQLite](https://sqlite.org/) - 存储引擎
- [clap](https://clap.rs/) - CLI 框架
- [OpenClaw](https://openclaw.ai/) - AI 助手平台

---

<p align="center">
  <b>ClawBox</b> — 让 AI 安全地访问你的密钥 🔐
</p>
