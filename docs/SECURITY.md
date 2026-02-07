# ClawBox 安全模型

## 概述

ClawBox 采用零信任安全架构，确保用户密钥在存储、传输和使用过程中的安全。

---

## 1. 加密算法

### 1.1 密钥派生

使用 **Argon2id** 从主密码派生加密密钥：

| 参数 | 值 | 说明 |
|------|-----|------|
| Variant | Argon2id | 混合模式，抗侧信道 + 抗 GPU |
| Memory | 64 MB | 内存成本 |
| Iterations | 3 | 时间成本 |
| Parallelism | 4 | 并行线程 |
| Output | 256 bits | 输出密钥长度 |
| Salt | 256 bits | 随机盐，每个保险库唯一 |

**为什么选择 Argon2id？**
- 2015 年密码哈希竞赛冠军
- 抗 GPU/ASIC 暴力破解
- 可调节的内存和时间成本

### 1.2 数据加密

使用 **AES-256-GCM** 加密所有密钥值：

| 参数 | 值 | 说明 |
|------|-----|------|
| Algorithm | AES-256 | 对称加密 |
| Mode | GCM | 认证加密模式 |
| Key | 256 bits | 从主密码派生 |
| Nonce | 96 bits | 每个密钥随机生成 |
| Auth Tag | 128 bits | 完整性校验 |

**为什么选择 AES-256-GCM？**
- 业界标准，广泛验证
- 同时提供加密和认证
- 硬件加速支持（AES-NI）

---

## 2. 密钥层次

```
Master Password (用户输入)
       │
       ▼
   [Argon2id]
       │
       ▼
  Derived Key (256-bit)
       │
       ├──────────────┐
       ▼              ▼
  Encryption Key  Auth Key
  (加密密钥)      (认证密钥)
       │
       ▼
  [AES-256-GCM]
       │
       ▼
  Encrypted Secrets
```

### 2.1 密钥分离

- **Encryption Key**: 用于加密密钥值
- **Auth Key**: 用于验证主密码正确性

这种分离确保即使攻击者获得加密数据，也无法验证密码猜测是否正确（需要同时破解两个密钥）。

---

## 3. 访问控制

### 3.1 访问级别

| 级别 | 说明 | AI 访问 | 审计 |
|------|------|---------|------|
| `public` | 公开信息 | ✅ 无需解锁 | 记录 |
| `normal` | 普通密钥 | ✅ 需要解锁 | 记录 |
| `sensitive` | 敏感密钥 | ⚠️ 需要确认 | 记录 + 通知 |
| `critical` | 关键密钥 | ❌ 仅人类 | 记录 + 通知 |

### 3.2 访问流程

```
┌─────────────────────────────────────────────────────────┐
│                    Access Request                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Check: Vault Unlocked?                     │
├──────────────────────┬──────────────────────────────────┤
│         NO           │              YES                 │
│         │            │               │                  │
│         ▼            │               ▼                  │
│   Request Unlock     │    Check: Access Level?          │
│         │            │               │                  │
│         ▼            │    ┌──────────┴──────────┐       │
│   Return Error       │    ▼          ▼          ▼       │
│   (Vault Locked)     │  public    normal    sensitive   │
│                      │    │          │          │       │
│                      │    ▼          ▼          ▼       │
│                      │  Allow    Allow      Request     │
│                      │                      Approval    │
│                      │                         │        │
│                      │              ┌──────────┴────┐   │
│                      │              ▼               ▼   │
│                      │           Approved        Denied │
│                      │              │               │   │
│                      │              ▼               ▼   │
│                      │           Allow           Deny   │
└──────────────────────┴──────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Log to Audit                          │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 审计日志

### 4.1 记录内容

每次访问都会记录：

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-02-07T10:30:15.123Z",
  "actor": {
    "type": "ai",
    "agent": "claude-3-opus",
    "session": "openclaw-main"
  },
  "action": "read",
  "key_path": "binance/api-key",
  "result": "success",
  "source": {
    "type": "cli",
    "command": "clawbox get binance/api-key",
    "pwd": "/Users/harris/projects"
  },
  "metadata": {
    "ip": "127.0.0.1",
    "hostname": "harris-macbook"
  }
}
```

### 4.2 完整性保护

审计日志使用链式哈希确保完整性：

```
Entry N:
  hash = SHA-256(content || prev_hash)
  
Entry N+1:
  hash = SHA-256(content || Entry_N.hash)
```

任何篡改都会破坏哈希链。

### 4.3 日志保留

| 级别 | 保留时间 |
|------|---------|
| 默认 | 90 天 |
| 敏感密钥访问 | 1 年 |
| 关键密钥访问 | 永久 |

---

## 5. 内存安全

### 5.1 密钥清零

所有敏感数据在使用后立即清零：

```rust
use zeroize::Zeroize;

struct SecretValue {
    data: Vec<u8>,
}

impl Drop for SecretValue {
    fn drop(&mut self) {
        self.data.zeroize();  // 覆写内存
    }
}
```

### 5.2 内存保护

- **mlock**: 防止密钥被交换到磁盘
- **guard pages**: 检测缓冲区溢出
- **ASLR**: 地址空间随机化

---

## 6. 威胁模型

### 6.1 威胁与缓解

| 威胁 | 风险 | 缓解措施 |
|------|------|---------|
| **主密码暴力破解** | 高 | Argon2id 高成本参数（64MB, 3次迭代）|
| **内存转储** | 中 | 密钥使用后 zeroize，mlock 保护 |
| **数据库泄露** | 高 | 所有值 AES-256-GCM 加密 |
| **侧信道攻击** | 低 | 常数时间比较，Argon2id 抗侧信道 |
| **AI 越权访问** | 中 | 分级权限，敏感操作需审批 |
| **审计日志篡改** | 低 | 链式哈希完整性校验 |
| **重放攻击** | 低 | 每个密钥唯一 nonce |

### 6.2 不在范围内

以下威胁不在当前安全模型范围内：

- 物理访问攻击（evil maid）
- 操作系统级别的 rootkit
- 硬件后门
- 用户主动泄露主密码

---

## 7. 最佳实践

### 7.1 主密码建议

- ✅ 至少 12 个字符
- ✅ 包含大小写、数字、符号
- ✅ 使用密码短语（如 "correct-horse-battery-staple"）
- ❌ 避免个人信息（生日、名字）
- ❌ 避免常见密码

### 7.2 使用建议

```bash
# ✅ 好的做法
echo "secret" | clawbox set key --stdin  # 避免命令历史

# ❌ 不好的做法
clawbox set key "secret123"  # 密钥出现在命令历史
```

### 7.3 备份建议

```bash
# 导出加密备份
clawbox export backup.json.enc --encrypted

# 将备份存储在安全位置
# - 加密的云存储
# - 离线存储（U盘）
# - 不同地理位置
```

---

## 8. 安全审计

### 8.1 代码审计

- 使用 `cargo audit` 检查依赖漏洞
- 定期安全代码审查
- 模糊测试（cargo-fuzz）

### 8.2 渗透测试

计划在 v1.0 发布前进行专业渗透测试。

### 8.3 漏洞报告

如果您发现安全漏洞，请通过以下方式报告：

- 邮件: security@clawbox.dev
- GitHub Security Advisories

请**不要**在公开 issue 中报告安全漏洞。

---

## 9. 合规性

ClawBox 的设计符合以下标准的相关要求：

- **OWASP 密码存储指南**
- **NIST SP 800-132** (密钥派生)
- **NIST SP 800-38D** (GCM 模式)

---

## 附录：加密参数选择依据

### Argon2id 参数

| 参数 | 选择 | 依据 |
|------|------|------|
| Memory: 64MB | 平衡安全与可用性，移动设备也能接受 |
| Time: 3 | OWASP 推荐最小值 |
| Parallelism: 4 | 现代 CPU 核心数 |

### AES-256-GCM 参数

| 参数 | 选择 | 依据 |
|------|------|------|
| Key: 256-bit | 抵抗量子计算攻击（Grover 算法降至 128-bit 安全性）|
| Nonce: 96-bit | GCM 标准推荐 |
| Tag: 128-bit | 完整性保护标准长度 |
