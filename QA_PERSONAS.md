# ClawBox QA 测试角色

本文档定义了用于测试 ClawBox 的虚拟 QA 角色。每个角色有不同的背景和测试重点。

---

## 👨‍💻 QA-1: 小白用户 (Newbie)

**背景**: 
- 刚接触命令行的普通用户
- 不懂技术细节，只想安全存密码
- 可能会犯各种低级错误

**测试重点**:
- 首次安装体验
- 错误提示是否友好
- 帮助文档是否清晰
- 常见错误操作的容错

**测试场景**:
```bash
# 忘记初始化就使用
clawbox get something

# 密码输错
clawbox unlock  # wrong password

# 不知道命令
clawbox save key value  # 应该是 set

# 路径格式错误
clawbox set "my key" "value"  # 有空格
```

---

## 🤖 QA-2: AI 助手 (AI Agent)

**背景**:
- OpenClaw / Claude Code 等 AI 助手
- 需要通过脚本自动化获取密钥
- 期望结构化输出 (JSON)

**测试重点**:
- 非交互式使用
- JSON 输出格式
- 环境变量支持
- 批量操作效率

**测试场景**:
```bash
# 环境变量密码
export CLAWBOX_PASSWORD="xxx"
clawbox get github/token

# JSON 输出
clawbox --json get github/token
clawbox --json list

# 管道使用
TOKEN=$(clawbox get github/token)
curl -H "Authorization: $TOKEN" ...

# 批量设置
for key in key1 key2 key3; do
  clawbox set "batch/$key" "value_$key"
done
```

---

## 🔐 QA-3: 安全测试员 (Security)

**背景**:
- 渗透测试背景
- 专门找安全漏洞
- 测试边界情况和恶意输入

**测试重点**:
- 密码暴力破解防护
- 内存中密钥是否清除
- 文件权限
- 注入攻击

**测试场景**:
```bash
# 恶意输入
clawbox set "key" "$(cat /etc/passwd)"
clawbox set "../../../etc/passwd" "value"
clawbox set "key\x00hidden" "value"

# SQL 注入
clawbox set "'; DROP TABLE secrets;--" "value"

# 路径遍历
clawbox --vault /etc/shadow init

# 文件权限检查
ls -la ~/.clawbox/

# 暴力破解尝试
for i in {1..100}; do
  CLAWBOX_PASSWORD="wrong$i" clawbox get test
done
```

---

## 🏢 QA-4: 企业用户 (Enterprise)

**背景**:
- DevOps 工程师
- 管理大量密钥
- 需要审计和合规

**测试重点**:
- 大规模密钥管理
- 审计日志完整性
- 导入导出功能
- 性能表现

**测试场景**:
```bash
# 批量创建 1000 个密钥
for i in {1..1000}; do
  clawbox set "bulk/key$i" "value$i"
done

# 性能测试
time clawbox list | wc -l

# 导出备份
clawbox export backup.json

# 审计日志
clawbox audit --since 1h

# 搜索过滤
clawbox list "aws/*"
clawbox list --tags prod
```

---

## 🍎 QA-5: macOS 用户 (macOS Native)

**背景**:
- macOS 重度用户
- 期望原生体验
- 使用 Touch ID、Keychain

**测试重点**:
- macOS App 功能
- Touch ID 集成
- Keychain 集成
- 菜单栏功能

**测试场景**:
```bash
# CLI 与 App 数据同步
# 在 CLI 创建密钥，App 中查看

# Touch ID 解锁
# (需要 macOS App)

# Keychain 集成
# 主密码存储在 Keychain
```

---

## 📋 测试执行记录

| 日期 | 角色 | 版本 | 通过 | 失败 | 备注 |
|------|------|------|------|------|------|
| 2026-02-07 | QA-1,2,3 | v0.0.2 | 12 | 0 | 初始测试 |
| 2026-02-07 | QA-1~5 | v0.4.0 | 15 | 0 | Touch ID + 安全测试 |
| 2026-02-07 | QA-1~5 | v0.5.0 | 10 | 0 | Export/Import + 同步 |

---

## 🐛 已发现问题

| Issue | 发现者 | 状态 |
|-------|--------|------|
| [#1](https://github.com/HarrisHan/clawbox/issues/1) 非 TTY 密码输入 | QA-2 | ✅ 已修复 |

---

## 🔄 持续测试计划

每次发布新版本前，需要运行以下测试：

1. **冒烟测试** (5 min)
   - init, set, get, list, delete 基本流程

2. **回归测试** (15 min)
   - 所有 QA 角色的核心场景

3. **安全测试** (30 min)
   - QA-3 的完整测试套件

4. **性能测试** (10 min)
   - 1000 密钥创建/读取
