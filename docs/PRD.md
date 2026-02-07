# ClawBox 产品需求文档 (PRD)

**版本**: 1.0  
**日期**: 2026-02-07  
**作者**: Harris Han / ClawBox Team

---

## 1. 产品概述

### 1.1 产品定位

ClawBox 是一款 **AI-Native 密钥管理工具**，专为 AI 助手与人类协作场景设计。它解决了开发者在使用 AI 助手时安全管理和共享 API 密钥的痛点。

### 1.2 目标用户

| 用户群体 | 特征 | 核心需求 |
|---------|------|---------|
| **AI 助手用户** | 使用 Claude/GPT/Copilot | 安全地让 AI 访问 API 密钥 |
| **开发者** | 管理多项目、多环境密钥 | 统一管理，便捷调用 |
| **DevOps** | CI/CD 密钥管理 | 安全注入，审计追踪 |
| **交易员** | 交易所 API 管理 | 高安全性，权限控制 |

### 1.3 核心价值主张

1. **AI 友好** — 简洁 CLI，AI 一行命令即可调用
2. **安全可控** — 分级权限，人类始终掌控关键密钥
3. **透明审计** — 完整访问日志，安全可追溯
4. **跨平台** — CLI + GUI，随处可用

---

## 2. 用户场景

### 场景 1: AI 助手调用交易所 API

**角色**: Harris，加密货币交易员  
**背景**: 使用 OpenClaw AI 助手分析行情和执行交易

**当前痛点**:
- 每次都要粘贴 API 密钥给 AI
- 密钥明文出现在聊天记录中
- 担心 AI 误操作导致资金损失

**使用 ClawBox 后**:
```bash
# Harris 预先配置
clawbox set binance/api-key "xxx" --access ai
clawbox set binance/api-secret "xxx" --access ai --sensitive

# AI 助手调用
API_KEY=$(clawbox get binance/api-key)
API_SECRET=$(clawbox get binance/api-secret)
# 自动记录审计日志
```

### 场景 2: 多项目 Token 管理

**角色**: 开发者  
**背景**: 同时开发多个项目，需要不同的 GitHub/GitLab Token

**当前痛点**:
- 多个 .env 文件散落各处
- 忘记哪个 token 用在哪里
- Token 更新后要改多个地方

**使用 ClawBox 后**:
```bash
# 统一管理
clawbox set github/personal-token "ghp_xxx"
clawbox set github/work-token "ghp_yyy"
clawbox set gitlab/dcs-token "glpat_zzz"

# 按需获取
export GITHUB_TOKEN=$(clawbox get github/personal-token)
```

### 场景 3: 敏感操作审批

**角色**: 团队负责人  
**背景**: 团队使用共享的云服务密钥

**当前痛点**:
- 不知道谁在什么时候用了密钥
- 高权限密钥被滥用的风险

**使用 ClawBox 后**:
```bash
# 设置关键密钥
clawbox set aws/root-key "xxx" --access critical

# AI 尝试访问时
$ clawbox get aws/root-key
⚠️  This key requires human approval.
Waiting for approval... (timeout: 60s)
[Notification sent to Harris's phone]
```

---

## 3. 功能规格

### 3.1 核心功能矩阵

| 功能 | v0.1 | v0.2 | v0.3 | v0.4 | v0.5 | v1.0 |
|------|------|------|------|------|------|------|
| 加密存储 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CRUD 操作 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 主密码保护 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 密钥分组 | - | ✅ | ✅ | ✅ | ✅ | ✅ |
| 权限分级 | - | ✅ | ✅ | ✅ | ✅ | ✅ |
| 审计日志 | - | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS App | - | - | ✅ | ✅ | ✅ | ✅ |
| Touch ID | - | - | - | ✅ | ✅ | ✅ |
| 硬件密钥 | - | - | - | ✅ | ✅ | ✅ |
| 云同步 | - | - | - | - | ✅ | ✅ |
| 团队共享 | - | - | - | - | ✅ | ✅ |
| 浏览器扩展 | - | - | - | - | - | ✅ |

### 3.2 CLI 命令规格

#### 初始化

```bash
clawbox init [--path <path>]
```

- 创建新的保险库
- 设置主密码
- 生成加密密钥

#### 密钥管理

```bash
# 设置密钥
clawbox set <key-path> <value> [options]
  --access <level>     # public|normal|sensitive|critical
  --ttl <duration>     # 过期时间: 1h, 7d, 30d
  --tags <tags>        # 标签: api,prod,binance
  --note <note>        # 备注

# 获取密钥
clawbox get <key-path> [options]
  --json               # JSON 格式输出
  --clipboard          # 复制到剪贴板
  --timeout <seconds>  # 敏感密钥审批超时

# 列出密钥
clawbox list [pattern] [options]
  --tags <tags>        # 按标签筛选
  --access <level>     # 按权限级别筛选
  --json               # JSON 格式输出

# 删除密钥
clawbox delete <key-path> [--force]

# 重命名密钥
clawbox rename <old-path> <new-path>
```

#### 保险库管理

```bash
# 解锁保险库
clawbox unlock [--timeout <minutes>]

# 锁定保险库
clawbox lock

# 修改主密码
clawbox passwd

# 导出保险库
clawbox export <file> [--format json|yaml|env]

# 导入密钥
clawbox import <file> [--format json|yaml|env]
```

#### 审计

```bash
# 查看审计日志
clawbox audit [options]
  --key <key-path>     # 筛选指定密钥
  --since <time>       # 起始时间
  --until <time>       # 结束时间
  --actor <actor>      # human|ai|app
  --json               # JSON 格式输出
```

### 3.3 macOS App 功能

#### 主界面

```
┌────────────────────────────────────────────────────────┐
│ ClawBox                                    🔒 Locked   │
├────────────────────────────────────────────────────────┤
│ 🔍 Search...                                           │
├────────────────────────────────────────────────────────┤
│ 📁 All Keys (12)                                       │
│ ├── 📁 binance (2)                                     │
│ │   ├── 🔑 api-key                                    │
│ │   └── 🔐 api-secret [sensitive]                     │
│ ├── 📁 github (3)                                      │
│ │   ├── 🔑 personal-token                             │
│ │   ├── 🔑 work-token                                 │
│ │   └── 🔑 actions-token                              │
│ └── 📁 aws (2)                                         │
│     ├── 🔑 access-key                                 │
│     └── 🔒 root-key [critical]                        │
├────────────────────────────────────────────────────────┤
│ [+ Add Key]  [⚙️ Settings]  [📋 Audit Log]             │
└────────────────────────────────────────────────────────┘
```

#### 菜单栏

```
┌─────────────────────┐
│ 🔐 ClawBox          │
├─────────────────────┤
│ 🔓 Unlock Vault     │
│ ───────────────     │
│ 📋 Quick Copy       │
│   → binance/api-key │
│   → github/token    │
│ ───────────────     │
│ ⚙️ Preferences      │
│ 📊 Audit Log        │
│ ───────────────     │
│ 🚪 Quit             │
└─────────────────────┘
```

#### 功能列表

1. **密钥管理**
   - 添加/编辑/删除密钥
   - 拖拽导入 .env 文件
   - 密钥搜索和筛选

2. **安全功能**
   - Touch ID 解锁
   - 自动锁定（闲置后）
   - 剪贴板自动清除

3. **通知与审批**
   - AI 访问敏感密钥时通知
   - 一键审批/拒绝
   - 访问历史查看

4. **同步功能**
   - iCloud 同步（可选）
   - 导入/导出

---

## 4. 非功能需求

### 4.1 安全性

| 需求 | 规格 |
|------|------|
| 加密算法 | AES-256-GCM |
| 密钥派生 | Argon2id (memory: 64MB, iterations: 3) |
| 随机数生成 | CSPRNG (系统级) |
| 内存安全 | 密钥使用后立即清零 |
| 审计日志 | 不可篡改，可选签名 |

### 4.2 性能

| 指标 | 目标 |
|------|------|
| 启动时间 | < 100ms |
| 密钥读取 | < 50ms |
| 密钥写入 | < 100ms |
| 内存占用 | < 50MB |
| 保险库大小 | 支持 10,000+ 密钥 |

### 4.3 兼容性

| 平台 | 最低版本 |
|------|---------|
| macOS | 12.0 (Monterey) |
| Linux | Ubuntu 20.04 / Debian 11 |
| Windows | 10 (1903+) |

### 4.4 可用性

- CLI 命令自动补全（bash/zsh/fish）
- 错误信息友好，包含修复建议
- 支持中英文界面

---

## 5. 数据模型

### 5.1 密钥条目

```rust
struct SecretEntry {
    id: Uuid,
    path: String,           // e.g., "binance/api-key"
    value: EncryptedBytes,  // 加密后的值
    access_level: AccessLevel,
    tags: Vec<String>,
    note: Option<String>,
    ttl: Option<DateTime>,
    created_at: DateTime,
    updated_at: DateTime,
    created_by: Actor,
}

enum AccessLevel {
    Public,     // AI 自由访问
    Normal,     // AI 需要解锁
    Sensitive,  // AI 访问需确认
    Critical,   // 仅人类访问
}

enum Actor {
    Human { device: String },
    AI { agent: String },
    App { name: String },
}
```

### 5.2 审计日志

```rust
struct AuditEntry {
    id: Uuid,
    timestamp: DateTime,
    actor: Actor,
    action: Action,
    key_path: String,
    result: Result<(), Error>,
    source: Source,
    metadata: HashMap<String, String>,
}

enum Action {
    Read,
    Write,
    Delete,
    Export,
    Unlock,
    Lock,
}

enum Source {
    CLI { pwd: String },
    App,
    API,
}
```

---

## 6. 竞品分析

| 产品 | 优势 | 劣势 | 定位 |
|------|------|------|------|
| **1Password** | 成熟稳定，生态完善 | 订阅贵，非 AI 设计 | 通用密码管理 |
| **Bitwarden** | 开源，自托管 | CLI 体验一般 | 通用密码管理 |
| **HashiCorp Vault** | 企业级，功能强大 | 太重，学习曲线陡 | 企业密钥管理 |
| **pass** | 简单，Unix 哲学 | 需要 GPG，不直观 | 极客密码管理 |
| **ClawBox** | AI 友好，轻量 | 新产品，生态待建 | AI 协作密钥管理 |

### ClawBox 差异化

1. **AI-First 设计** — CLI 接口专为 AI 调用优化
2. **权限分级** — 细粒度控制 AI 可访问的密钥
3. **审批机制** — 敏感操作需人类确认
4. **轻量级** — 单二进制，无依赖

---

## 7. 成功指标

### 7.1 发布指标

| 里程碑 | 目标日期 | 关键交付 |
|--------|---------|---------|
| v0.1.0 | +2 周 | CLI MVP，可用 |
| v0.2.0 | +4 周 | 权限 + 审计 |
| v0.3.0 | +6 周 | macOS App |
| v1.0.0 | +12 周 | 稳定版发布 |

### 7.2 用户指标（发布后）

| 指标 | 3 个月目标 |
|------|-----------|
| GitHub Stars | 500+ |
| 下载量 | 1,000+ |
| 活跃用户 | 200+ |
| 贡献者 | 10+ |

---

## 8. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 安全漏洞 | 中 | 高 | 代码审计，模糊测试 |
| 用户采用慢 | 中 | 中 | OpenClaw 集成推广 |
| 跨平台兼容 | 低 | 中 | CI 多平台测试 |
| 竞品跟进 | 低 | 低 | 持续创新，社区运营 |

---

## 附录

### A. 术语表

| 术语 | 定义 |
|------|------|
| Vault | 保险库，存储所有密钥的加密容器 |
| Secret | 密钥条目，包含路径和加密值 |
| Master Password | 主密码，用于解锁保险库 |
| Access Level | 访问级别，控制谁可以访问密钥 |
| Audit Log | 审计日志，记录所有访问操作 |

### B. 参考资料

- [libsodium 文档](https://doc.libsodium.org/)
- [Argon2 规范](https://github.com/P-H-C/phc-winner-argon2)
- [age 加密](https://age-encryption.org/)
