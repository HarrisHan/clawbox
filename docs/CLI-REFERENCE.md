# ClawBox CLI 参考手册

## 概述

ClawBox CLI 是一个命令行工具，用于管理加密的密钥存储库。

## 安装

```bash
# macOS (Homebrew)
brew install clawbox/tap/clawbox

# macOS (手动)
curl -sSL https://get.clawbox.dev | sh

# Linux (Debian/Ubuntu)
curl -sSL https://get.clawbox.dev | sh

# 从源码构建
cargo install clawbox-cli
```

## 全局选项

| 选项 | 说明 |
|------|------|
| `--vault <path>` | 指定保险库路径（默认: `~/.clawbox`）|
| `--json` | JSON 格式输出 |
| `--quiet` | 静默模式，仅输出结果 |
| `--help` | 显示帮助信息 |
| `--version` | 显示版本信息 |

---

## 命令

### `clawbox init`

初始化新的保险库。

```bash
clawbox init [OPTIONS]
```

**选项:**
| 选项 | 说明 |
|------|------|
| `--path <path>` | 保险库存储路径 |

**示例:**
```bash
# 在默认位置初始化
clawbox init

# 指定路径
clawbox init --path ~/my-secrets
```

**输出:**
```
Enter master password: ********
Confirm password: ********
✓ Vault created at /Users/harris/.clawbox
```

---

### `clawbox set`

设置或更新密钥。

```bash
clawbox set <path> <value> [OPTIONS]
```

**参数:**
| 参数 | 说明 |
|------|------|
| `<path>` | 密钥路径（如 `binance/api-key`）|
| `<value>` | 密钥值 |

**选项:**
| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--access <level>` | 访问级别: `public`, `normal`, `sensitive`, `critical` | `normal` |
| `--ttl <duration>` | 过期时间: `1h`, `7d`, `30d`, `1y` | 永不过期 |
| `--tags <tags>` | 标签（逗号分隔）| 无 |
| `--note <note>` | 备注 | 无 |
| `--stdin` | 从标准输入读取值 | - |

**示例:**
```bash
# 基本用法
clawbox set github/token "ghp_xxxxxxxxxxxx"

# 设置敏感密钥
clawbox set binance/api-secret "xxx" --access sensitive

# 设置带过期时间的密钥
clawbox set temp/deploy-key "xxx" --ttl 7d

# 添加标签和备注
clawbox set aws/prod-key "xxx" --tags "aws,prod" --note "Production AWS key"

# 从标准输入读取（避免密钥出现在命令历史）
echo "secret-value" | clawbox set my/secret --stdin
```

---

### `clawbox get`

获取密钥值。

```bash
clawbox get <path> [OPTIONS]
```

**参数:**
| 参数 | 说明 |
|------|------|
| `<path>` | 密钥路径 |

**选项:**
| 选项 | 说明 |
|------|------|
| `--json` | JSON 格式输出 |
| `--clipboard` | 复制到剪贴板（不输出到终端）|
| `--timeout <seconds>` | 敏感密钥审批等待超时 |

**示例:**
```bash
# 基本用法
clawbox get github/token
# → ghp_xxxxxxxxxxxx

# JSON 格式
clawbox get github/token --json
# → {"path": "github/token", "value": "ghp_xxxxxxxxxxxx"}

# 复制到剪贴板
clawbox get github/token --clipboard
# → Copied to clipboard (will clear in 30s)

# 在脚本中使用
export GITHUB_TOKEN=$(clawbox get github/token)
```

**访问敏感密钥:**
```bash
clawbox get binance/api-secret
# ⚠️  This secret requires approval.
# Waiting for approval... (timeout: 60s)
# ✓ Approved
# → xxx
```

---

### `clawbox list`

列出所有密钥。

```bash
clawbox list [pattern] [OPTIONS]
```

**参数:**
| 参数 | 说明 |
|------|------|
| `[pattern]` | 可选的路径匹配模式（支持 `*` 通配符）|

**选项:**
| 选项 | 说明 |
|------|------|
| `--tags <tags>` | 按标签筛选 |
| `--access <level>` | 按访问级别筛选 |
| `--json` | JSON 格式输出 |
| `--tree` | 树形显示 |

**示例:**
```bash
# 列出所有
clawbox list
# → binance/api-key
# → binance/api-secret [sensitive]
# → github/token
# → aws/access-key

# 按模式筛选
clawbox list "binance/*"
# → binance/api-key
# → binance/api-secret [sensitive]

# 按标签筛选
clawbox list --tags prod
# → aws/prod-key
# → db/prod-password

# 树形显示
clawbox list --tree
# → 📁 binance
# →   ├── 🔑 api-key
# →   └── 🔐 api-secret [sensitive]
# → 📁 github
# →   └── 🔑 token
```

---

### `clawbox delete`

删除密钥。

```bash
clawbox delete <path> [OPTIONS]
```

**选项:**
| 选项 | 说明 |
|------|------|
| `--force` | 跳过确认 |

**示例:**
```bash
# 删除（需确认）
clawbox delete temp/old-key
# Delete 'temp/old-key'? [y/N] y
# ✓ Deleted

# 强制删除
clawbox delete temp/old-key --force
```

---

### `clawbox rename`

重命名密钥。

```bash
clawbox rename <old-path> <new-path>
```

**示例:**
```bash
clawbox rename github/old-token github/personal-token
# ✓ Renamed 'github/old-token' to 'github/personal-token'
```

---

### `clawbox unlock`

解锁保险库。

```bash
clawbox unlock [OPTIONS]
```

**选项:**
| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--timeout <minutes>` | 自动锁定超时 | 30 |

**示例:**
```bash
clawbox unlock
# Enter master password: ********
# ✓ Vault unlocked (will lock in 30 minutes)

clawbox unlock --timeout 60
# ✓ Vault unlocked (will lock in 60 minutes)
```

---

### `clawbox lock`

锁定保险库。

```bash
clawbox lock
```

**示例:**
```bash
clawbox lock
# ✓ Vault locked
```

---

### `clawbox passwd`

修改主密码。

```bash
clawbox passwd
```

**示例:**
```bash
clawbox passwd
# Enter current password: ********
# Enter new password: ********
# Confirm new password: ********
# ✓ Password changed
```

---

### `clawbox audit`

查看审计日志。

```bash
clawbox audit [OPTIONS]
```

**选项:**
| 选项 | 说明 |
|------|------|
| `--key <path>` | 筛选指定密钥 |
| `--since <time>` | 起始时间（如 `1h`, `7d`, `2024-01-01`）|
| `--until <time>` | 结束时间 |
| `--actor <type>` | 筛选访问者类型: `human`, `ai`, `app` |
| `--action <type>` | 筛选操作类型: `read`, `write`, `delete` |
| `--limit <n>` | 限制条数 |
| `--json` | JSON 格式输出 |

**示例:**
```bash
# 查看所有日志
clawbox audit
# → 2024-02-07 10:30:15  human   read    binance/api-key
# → 2024-02-07 10:25:03  ai      read    github/token
# → 2024-02-07 10:20:00  human   write   aws/new-key

# 筛选特定密钥
clawbox audit --key binance/api-key

# 筛选 AI 访问
clawbox audit --actor ai

# 最近 24 小时
clawbox audit --since 24h
```

---

### `clawbox export`

导出密钥。

```bash
clawbox export <file> [OPTIONS]
```

**选项:**
| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--format <fmt>` | 导出格式: `json`, `yaml`, `env` | `json` |
| `--keys <paths>` | 仅导出指定密钥（逗号分隔）| 全部 |
| `--exclude-sensitive` | 排除敏感密钥 | false |

**示例:**
```bash
# 导出为 JSON
clawbox export backup.json

# 导出为 .env 格式
clawbox export .env --format env

# 仅导出特定密钥
clawbox export partial.json --keys "github/*,aws/access-key"
```

---

### `clawbox import`

导入密钥。

```bash
clawbox import <file> [OPTIONS]
```

**选项:**
| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--format <fmt>` | 文件格式: `json`, `yaml`, `env` | 自动检测 |
| `--merge` | 合并模式（不覆盖已有）| false |
| `--prefix <path>` | 添加路径前缀 | 无 |

**示例:**
```bash
# 导入 JSON
clawbox import backup.json

# 导入 .env 文件
clawbox import .env --format env

# 导入并添加前缀
clawbox import prod.env --prefix "prod/"
```

---

### `clawbox config`

管理配置。

```bash
clawbox config <subcommand>
```

**子命令:**
- `clawbox config show` - 显示当前配置
- `clawbox config set <key> <value>` - 设置配置项
- `clawbox config reset` - 重置为默认配置

**配置项:**
| 键 | 说明 | 默认值 |
|-----|------|--------|
| `unlock_timeout` | 自动锁定超时（分钟）| 30 |
| `clipboard_timeout` | 剪贴板清除超时（秒）| 30 |
| `ai_access_default` | AI 默认访问级别 | `normal` |
| `confirm_delete` | 删除前确认 | true |

---

## 退出码

| 代码 | 含义 |
|------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| 2 | 密钥未找到 |
| 3 | 保险库已锁定 |
| 4 | 权限拒绝 |
| 5 | 审批超时 |

---

## 环境变量

| 变量 | 说明 |
|------|------|
| `CLAWBOX_VAULT` | 保险库路径 |
| `CLAWBOX_PASSWORD` | 主密码（不推荐，仅用于自动化）|
| `CLAWBOX_NO_COLOR` | 禁用彩色输出 |

---

## Shell 自动补全

```bash
# Bash
clawbox completions bash > /etc/bash_completion.d/clawbox

# Zsh
clawbox completions zsh > ~/.zsh/completions/_clawbox

# Fish
clawbox completions fish > ~/.config/fish/completions/clawbox.fish
```
