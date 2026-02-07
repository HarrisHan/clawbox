# ClawBox 技术架构文档

**版本**: 1.0  
**日期**: 2026-02-07

---

## 1. 系统架构

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interfaces                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│      CLI        │   macOS App     │   Browser Extension         │
│    (Rust)       │   (Swift)       │   (TypeScript)              │
└────────┬────────┴────────┬────────┴──────────────┬──────────────┘
         │                 │                       │
         │        ┌────────▼────────┐              │
         │        │   IPC Daemon    │              │
         │        │   (optional)    │              │
         │        └────────┬────────┘              │
         │                 │                       │
         └─────────────────┼───────────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Core Lib   │
                    │   (Rust)    │
                    │  libclawbox │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
    │ Crypto  │      │ Storage │      │  Audit  │
    │ Module  │      │ Engine  │      │  Logger │
    └────┬────┘      └────┬────┘      └────┬────┘
         │                │                │
         │           ┌────▼────┐           │
         └──────────►│ SQLite  │◄──────────┘
                     │   DB    │
                     └─────────┘
```

### 1.2 组件说明

| 组件 | 语言 | 职责 |
|------|------|------|
| **CLI** | Rust | 命令行接口，直接调用 Core Lib |
| **macOS App** | Swift | GUI 界面，通过 FFI 调用 Core Lib |
| **Core Lib** | Rust | 核心逻辑，加密/存储/审计 |
| **IPC Daemon** | Rust | 可选，提供后台服务和权限提升 |
| **Browser Ext** | TypeScript | 浏览器集成，通过 Native Messaging 通信 |

---

## 2. 核心模块

### 2.1 加密模块 (Crypto)

#### 密钥派生

```rust
// 使用 Argon2id 从主密码派生密钥
fn derive_key(password: &str, salt: &[u8]) -> Result<DerivedKey> {
    let config = argon2::Config {
        variant: argon2::Variant::Argon2id,
        memory_cost: 65536,     // 64 MB
        time_cost: 3,           // 3 iterations
        lanes: 4,               // 4 parallel lanes
        hash_length: 32,        // 256-bit key
    };
    
    argon2::hash_raw(password.as_bytes(), salt, &config)
}
```

#### 数据加密

```rust
// 使用 AES-256-GCM 加密数据
fn encrypt(plaintext: &[u8], key: &DerivedKey) -> Result<EncryptedData> {
    let nonce = generate_random_nonce();  // 96-bit
    let cipher = Aes256Gcm::new(key);
    
    let ciphertext = cipher.encrypt(&nonce, plaintext)?;
    
    Ok(EncryptedData {
        nonce,
        ciphertext,
        tag: /* included in ciphertext */,
    })
}

fn decrypt(encrypted: &EncryptedData, key: &DerivedKey) -> Result<Vec<u8>> {
    let cipher = Aes256Gcm::new(key);
    cipher.decrypt(&encrypted.nonce, &encrypted.ciphertext)
}
```

#### 内存安全

```rust
// 使用 zeroize 确保密钥在内存中被清除
use zeroize::Zeroize;

struct SensitiveData {
    data: Vec<u8>,
}

impl Drop for SensitiveData {
    fn drop(&mut self) {
        self.data.zeroize();
    }
}
```

### 2.2 存储引擎 (Storage)

#### 数据库 Schema

```sql
-- 主表：密钥存储
CREATE TABLE secrets (
    id TEXT PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    encrypted_value BLOB NOT NULL,
    access_level INTEGER NOT NULL DEFAULT 1,
    tags TEXT,  -- JSON array
    note TEXT,
    ttl_expires_at INTEGER,  -- Unix timestamp
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    created_by TEXT NOT NULL  -- JSON Actor
);

-- 索引
CREATE INDEX idx_secrets_path ON secrets(path);
CREATE INDEX idx_secrets_tags ON secrets(tags);
CREATE INDEX idx_secrets_ttl ON secrets(ttl_expires_at);

-- 审计日志表
CREATE TABLE audit_log (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    actor TEXT NOT NULL,  -- JSON Actor
    action TEXT NOT NULL,
    key_path TEXT NOT NULL,
    success INTEGER NOT NULL,
    error_message TEXT,
    source TEXT NOT NULL,  -- JSON Source
    metadata TEXT  -- JSON
);

CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_key_path ON audit_log(key_path);

-- 元数据表
CREATE TABLE vault_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- 插入元数据
INSERT INTO vault_meta VALUES ('version', '1');
INSERT INTO vault_meta VALUES ('created_at', strftime('%s', 'now'));
INSERT INTO vault_meta VALUES ('salt', hex(randomblob(32)));
```

#### 存储接口

```rust
pub trait SecretStore {
    fn get(&self, path: &str) -> Result<Option<SecretEntry>>;
    fn set(&mut self, entry: SecretEntry) -> Result<()>;
    fn delete(&mut self, path: &str) -> Result<bool>;
    fn list(&self, pattern: Option<&str>) -> Result<Vec<SecretEntry>>;
    fn search(&self, query: &SearchQuery) -> Result<Vec<SecretEntry>>;
}

pub struct SqliteStore {
    conn: Connection,
    encryption_key: DerivedKey,
}

impl SecretStore for SqliteStore {
    // 实现...
}
```

### 2.3 审计模块 (Audit)

```rust
pub struct AuditLogger {
    store: Arc<dyn AuditStore>,
}

impl AuditLogger {
    pub fn log(&self, entry: AuditEntry) -> Result<()> {
        // 1. 添加时间戳
        let entry = entry.with_timestamp(Utc::now());
        
        // 2. 计算完整性哈希（可选）
        let entry = entry.with_integrity_hash(self.compute_hash(&entry));
        
        // 3. 持久化
        self.store.append(entry)?;
        
        // 4. 触发通知（如果是敏感操作）
        if entry.requires_notification() {
            self.notify(&entry)?;
        }
        
        Ok(())
    }
    
    pub fn query(&self, filter: &AuditFilter) -> Result<Vec<AuditEntry>> {
        self.store.query(filter)
    }
}
```

---

## 3. 接口设计

### 3.1 CLI 接口

```rust
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "clawbox")]
#[command(about = "AI-Native Secret Manager")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    #[arg(long, global = true)]
    vault: Option<PathBuf>,
    
    #[arg(long, global = true)]
    json: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new vault
    Init {
        #[arg(long)]
        path: Option<PathBuf>,
    },
    
    /// Set a secret
    Set {
        path: String,
        value: String,
        #[arg(long, default_value = "normal")]
        access: AccessLevel,
        #[arg(long)]
        ttl: Option<String>,
        #[arg(long)]
        tags: Option<String>,
        #[arg(long)]
        note: Option<String>,
    },
    
    /// Get a secret
    Get {
        path: String,
        #[arg(long)]
        clipboard: bool,
        #[arg(long)]
        timeout: Option<u64>,
    },
    
    /// List secrets
    List {
        pattern: Option<String>,
        #[arg(long)]
        tags: Option<String>,
        #[arg(long)]
        access: Option<AccessLevel>,
    },
    
    /// Delete a secret
    Delete {
        path: String,
        #[arg(long)]
        force: bool,
    },
    
    /// Unlock the vault
    Unlock {
        #[arg(long, default_value = "30")]
        timeout: u64,
    },
    
    /// Lock the vault
    Lock,
    
    /// View audit log
    Audit {
        #[arg(long)]
        key: Option<String>,
        #[arg(long)]
        since: Option<String>,
        #[arg(long)]
        actor: Option<String>,
    },
    
    /// Change master password
    Passwd,
    
    /// Export secrets
    Export {
        file: PathBuf,
        #[arg(long, default_value = "json")]
        format: ExportFormat,
    },
    
    /// Import secrets
    Import {
        file: PathBuf,
        #[arg(long, default_value = "json")]
        format: ExportFormat,
    },
}
```

### 3.2 Core Library API (Rust)

```rust
// lib.rs - 公开 API

pub struct ClawBox {
    vault: Vault,
    config: Config,
}

impl ClawBox {
    /// 打开或创建保险库
    pub fn open(path: impl AsRef<Path>) -> Result<Self>;
    
    /// 使用主密码解锁
    pub fn unlock(&mut self, password: &str) -> Result<()>;
    
    /// 锁定保险库
    pub fn lock(&mut self);
    
    /// 检查是否已解锁
    pub fn is_unlocked(&self) -> bool;
    
    /// 获取密钥
    pub fn get(&self, path: &str) -> Result<Option<String>>;
    
    /// 设置密钥
    pub fn set(&mut self, path: &str, value: &str, opts: SetOptions) -> Result<()>;
    
    /// 删除密钥
    pub fn delete(&mut self, path: &str) -> Result<bool>;
    
    /// 列出密钥
    pub fn list(&self, filter: Option<&ListFilter>) -> Result<Vec<SecretInfo>>;
    
    /// 查询审计日志
    pub fn audit(&self, filter: &AuditFilter) -> Result<Vec<AuditEntry>>;
}

#[derive(Default)]
pub struct SetOptions {
    pub access: AccessLevel,
    pub ttl: Option<Duration>,
    pub tags: Vec<String>,
    pub note: Option<String>,
}

pub struct SecretInfo {
    pub path: String,
    pub access: AccessLevel,
    pub tags: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

### 3.3 FFI 接口 (for Swift)

```rust
// ffi.rs - C-compatible API for Swift

#[no_mangle]
pub extern "C" fn clawbox_open(path: *const c_char) -> *mut ClawBox;

#[no_mangle]
pub extern "C" fn clawbox_close(handle: *mut ClawBox);

#[no_mangle]
pub extern "C" fn clawbox_unlock(
    handle: *mut ClawBox,
    password: *const c_char,
) -> c_int;

#[no_mangle]
pub extern "C" fn clawbox_get(
    handle: *mut ClawBox,
    path: *const c_char,
    out_value: *mut *mut c_char,
) -> c_int;

#[no_mangle]
pub extern "C" fn clawbox_set(
    handle: *mut ClawBox,
    path: *const c_char,
    value: *const c_char,
    access_level: c_int,
) -> c_int;

// ... 更多 FFI 函数
```

---

## 4. 安全设计

### 4.1 威胁模型

| 威胁 | 缓解措施 |
|------|---------|
| 主密码暴力破解 | Argon2id 高成本参数 |
| 内存转储攻击 | 密钥使用后 zeroize |
| 数据库泄露 | 所有值 AES-256-GCM 加密 |
| 中间人攻击 | 本地存储，无网络传输 |
| AI 过度访问 | 分级权限 + 审批机制 |
| 审计日志篡改 | 链式哈希完整性校验 |

### 4.2 加密流程

```
┌─────────────────────────────────────────────────────────────┐
│                     Key Derivation                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Master Password ─┬─► Argon2id ─► Derived Key (256-bit)    │
│                   │       │                                 │
│  Random Salt ─────┘       │                                 │
│  (stored in DB)           ▼                                 │
│                    ┌──────────────┐                         │
│                    │  Key Split   │                         │
│                    └──────┬───────┘                         │
│                           │                                 │
│              ┌────────────┴────────────┐                    │
│              ▼                         ▼                    │
│       Encryption Key            Auth Key                    │
│       (for secrets)         (for vault access)              │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Secret Encryption                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Plaintext Secret ─┬─► AES-256-GCM ─► Ciphertext           │
│                    │        │              │                │
│  Encryption Key ───┤        │              │                │
│                    │        ▼              ▼                │
│  Random Nonce ─────┘   Auth Tag      Stored in DB          │
│  (per-secret)          (16 bytes)                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 解锁流程

```
┌─────────────────────────────────────────────────────────────┐
│                     Unlock Process                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. User enters Master Password                             │
│                    │                                        │
│                    ▼                                        │
│  2. Load Salt from vault_meta table                         │
│                    │                                        │
│                    ▼                                        │
│  3. Derive Key using Argon2id                               │
│                    │                                        │
│                    ▼                                        │
│  4. Try decrypt verification token                          │
│         │                                                   │
│         ├─► Success: Store derived key in memory            │
│         │            Set unlock timeout                     │
│         │                                                   │
│         └─► Failure: Return error, increment attempt count  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 目录结构

```
clawbox/
├── Cargo.toml              # Rust workspace 配置
├── README.md
├── LICENSE
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── CLI-REFERENCE.md
│   ├── SECURITY.md
│   └── API.md
├── crates/
│   ├── clawbox-core/       # 核心库
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── crypto.rs
│   │       ├── storage.rs
│   │       ├── audit.rs
│   │       ├── vault.rs
│   │       └── error.rs
│   ├── clawbox-cli/        # CLI 工具
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── commands/
│   │       └── ui.rs
│   └── clawbox-ffi/        # FFI 绑定
│       ├── Cargo.toml
│       ├── src/
│       │   └── lib.rs
│       └── include/
│           └── clawbox.h
├── macos-app/              # macOS 应用
│   ├── ClawBox.xcodeproj/
│   ├── ClawBox/
│   │   ├── App.swift
│   │   ├── Views/
│   │   ├── Models/
│   │   └── Bridge/
│   └── ClawBoxTests/
├── tests/                  # 集成测试
│   ├── integration_test.rs
│   └── fixtures/
├── scripts/                # 构建脚本
│   ├── build-macos.sh
│   ├── build-linux.sh
│   └── release.sh
└── .github/
    └── workflows/
        ├── ci.yml
        ├── release.yml
        └── security-audit.yml
```

---

## 6. 依赖项

### 6.1 Rust Crates

```toml
# clawbox-core/Cargo.toml

[dependencies]
# 加密
aes-gcm = "0.10"
argon2 = "0.5"
rand = "0.8"
zeroize = { version = "1.7", features = ["derive"] }

# 存储
rusqlite = { version = "0.31", features = ["bundled"] }

# 序列化
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# 时间
chrono = { version = "0.4", features = ["serde"] }

# 错误处理
thiserror = "1.0"
anyhow = "1.0"

# UUID
uuid = { version = "1.7", features = ["v4", "serde"] }

[dev-dependencies]
tempfile = "3.10"
```

```toml
# clawbox-cli/Cargo.toml

[dependencies]
clawbox-core = { path = "../clawbox-core" }
clap = { version = "4.5", features = ["derive"] }
dialoguer = "0.11"
console = "0.15"
rpassword = "7.3"
```

### 6.2 Swift Dependencies

```swift
// Package.swift or via Xcode

dependencies: [
    // Keychain access
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
    
    // Swift-Rust bridge helpers (if needed)
    // Usually handled via manual FFI
]
```

---

## 7. 构建与发布

### 7.1 构建命令

```bash
# 构建所有 Rust crates
cargo build --release

# 构建 CLI
cargo build --release -p clawbox-cli

# 构建 FFI 库
cargo build --release -p clawbox-ffi

# 生成 C 头文件
cbindgen --config cbindgen.toml --crate clawbox-ffi --output target/clawbox.h

# 构建 macOS App
cd macos-app
xcodebuild -scheme ClawBox -configuration Release \
    -archivePath build/ClawBox.xcarchive archive
```

### 7.2 发布流程

```bash
# 1. 更新版本号
./scripts/bump-version.sh 0.1.0

# 2. 创建 Git tag
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0

# 3. GitHub Actions 自动构建并发布
# - 构建多平台二进制
# - 创建 GitHub Release
# - 上传 artifacts
```

### 7.3 CI/CD Pipeline

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: macos-latest
            target: x86_64-apple-darwin
          - os: macos-latest
            target: aarch64-apple-darwin
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
          - os: windows-latest
            target: x86_64-pc-windows-msvc
    
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Build
        run: cargo build --release --target ${{ matrix.target }}
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: clawbox-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/clawbox*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            clawbox-*/*
```
