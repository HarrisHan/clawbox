# ClawBox 版本规划与路线图

## 版本命名规范

遵循 [Semantic Versioning 2.0](https://semver.org/):

- **MAJOR.MINOR.PATCH** (如 `1.2.3`)
- MAJOR: 不兼容的 API 变更
- MINOR: 向后兼容的新功能
- PATCH: 向后兼容的 bug 修复

---

## 版本规划

### v0.1.0 - MVP ✅

**目标**: 可用的 CLI 基础版本

**状态**: ✅ 已完成 (2026-02-07)

**功能清单**:

- [x] 项目结构搭建
  - [x] Rust workspace 配置
  - [x] CI/CD 基础 (GitHub Actions)
  - [x] 文档结构

- [x] 加密核心
  - [x] Argon2id 密钥派生
  - [x] AES-256-GCM 加密/解密
  - [x] 安全随机数生成
  - [x] 内存安全 (zeroize)

- [x] 存储引擎
  - [x] SQLite 数据库初始化
  - [x] 密钥 CRUD 操作
  - [x] 事务支持

- [x] CLI 基础命令
  - [x] `clawbox init` - 初始化保险库
  - [x] `clawbox set` - 设置密钥
  - [x] `clawbox get` - 获取密钥
  - [x] `clawbox list` - 列出密钥
  - [x] `clawbox delete` - 删除密钥
  - [x] `clawbox unlock` / `lock` - 解锁/锁定

- [x] 测试
  - [x] 单元测试
  - [x] 集成测试

**发布物**:
- GitHub Release: https://github.com/HarrisHan/clawbox/releases/tag/v0.1.0

---

### v0.2.0 - 权限与审计 ✅

**目标**: 完善的权限控制和审计追踪

**状态**: ✅ 已完成 (2026-02-07)

**功能清单**:

- [x] 访问级别
  - [x] 四级权限: public, normal, sensitive, critical
  - [x] 默认权限配置

- [x] 审计日志
  - [x] 日志记录引擎
  - [x] 链式哈希完整性
  - [x] `clawbox audit` 命令
  - [x] 日志导出 (--json)

- [x] 密钥管理增强
  - [x] 密钥分组 (路径层级)
  - [x] 标签系统
  - [x] 备注功能

- [x] CLI 改进
  - [x] 彩色输出
  - [x] 进度指示

**发布物**:
- GitHub Release: https://github.com/HarrisHan/clawbox/releases/tag/v0.2.0

---

### v0.3.0 - macOS App ✅

**目标**: 原生 macOS 图形界面

**状态**: ✅ 已完成 (2026-02-07)

**功能清单**:

- [x] CLI 集成
  - [x] VaultManager 调用 CLI
  - [x] 密码环境变量传递

- [x] macOS App 基础
  - [x] SwiftUI 主界面
  - [x] 密钥列表视图 (NavigationSplitView)
  - [x] 密钥详情 (reveal/copy/delete)
  - [x] 搜索功能
  - [x] 添加密钥表单

- [x] 系统集成
  - [x] 菜单栏图标 (MenuBarExtra)
  - [x] 快捷键 (Cmd+Shift+L 锁定)
  - [x] 剪贴板自动清除 (30秒)

- [ ] 待完善 (v0.3.1)
  - [ ] FFI 直接绑定 (替代 CLI 调用)
  - [ ] .dmg/.pkg 打包
  - [ ] 通知系统

**发布物**:
- GitHub Release: https://github.com/HarrisHan/clawbox/releases/tag/v0.3.0
- Xcode 项目源码

---

### v0.4.0 - 高级安全 🔒

**目标**: 硬件密钥和生物识别支持

**预计时间**: 2 周 (累计 9 周)

**功能清单**:

- [ ] 生物识别
  - [ ] Touch ID 解锁
  - [ ] 系统 Keychain 集成
  - [ ] 自动锁定策略

- [ ] 硬件密钥
  - [ ] YubiKey 支持
  - [ ] FIDO2/WebAuthn
  - [ ] 备用主密码

- [ ] 密钥安全增强
  - [ ] TTL (自动过期)
  - [ ] 密钥轮换提醒
  - [ ] 密钥强度检查

- [ ] 安全审计
  - [ ] 依赖漏洞扫描
  - [ ] 代码安全审查

**发布物**:
- 更新的 CLI 和 App
- 安全白皮书

---

### v0.5.0 - 同步与分享 ☁️

**目标**: 云同步和团队协作

**预计时间**: 3 周 (累计 12 周)

**功能清单**:

- [ ] 云同步
  - [ ] E2E 加密同步协议
  - [ ] iCloud 集成 (macOS)
  - [ ] 冲突解决策略

- [ ] 导入导出增强
  - [ ] JSON/YAML/ENV 格式
  - [ ] 加密导出
  - [ ] 从 1Password/Bitwarden 导入

- [ ] 团队功能 (可选)
  - [ ] 共享保险库
  - [ ] 角色权限
  - [ ] 团队审计

**发布物**:
- 同步服务组件
- 团队版文档

---

### v1.0.0 - 正式发布 ✅

**目标**: 稳定、完善、可生产使用

**状态**: ✅ 已完成 (2026-02-07)

**功能清单**:

- [x] 稳定性
  - [x] API 稳定
  - [x] 全平台测试
  - [x] QA 测试通过

- [x] 文档完善
  - [x] README
  - [x] CHANGELOG
  - [x] CLI Reference
  - [x] 架构文档

- [x] 发布准备
  - [x] 安装脚本 (install.sh)
  - [x] GitHub Releases
  - [x] CI/CD 完整

**发布物**:
- GitHub Release: https://github.com/HarrisHan/clawbox/releases/tag/v1.0.0

---

## 里程碑时间线

```
2026 February
├── Week 1-2: v0.1.0 MVP
│   └── 基础 CLI 可用
│
├── Week 3-4: v0.2.0 权限与审计
│   └── 完整权限控制
│
March
├── Week 5-7: v0.3.0 macOS App
│   └── GUI 界面发布
│
├── Week 8-9: v0.4.0 高级安全
│   └── Touch ID + YubiKey
│
April
├── Week 10-12: v0.5.0 同步与分享
│   └── 云同步功能
│
May
└── Week 14-16: v1.0.0 正式发布
    └── 生产就绪
```

---

## 发布流程

### 1. 版本准备

```bash
# 更新版本号
./scripts/bump-version.sh 0.1.0

# 更新 CHANGELOG
vim CHANGELOG.md

# 提交
git add -A
git commit -m "chore: prepare v0.1.0"
```

### 2. 创建 Tag

```bash
git tag -a v0.1.0 -m "Release v0.1.0 - MVP"
git push origin v0.1.0
```

### 3. GitHub Actions 自动构建

- 多平台编译
- 运行测试
- 创建 Release
- 上传 Artifacts

### 4. 发布后

- 更新文档
- 发布公告
- 社区通知

---

## 贡献指南

### 优先级标签

| 标签 | 说明 |
|------|------|
| `P0` | 阻塞发布，必须修复 |
| `P1` | 重要功能，当前版本完成 |
| `P2` | 次要功能，可延期 |
| `P3` | Nice to have |

### Issue 模板

- 🐛 Bug Report
- ✨ Feature Request
- 📚 Documentation
- ❓ Question

---

## 长期愿景 (v2.0+)

- **移动端**: iOS/Android App
- **浏览器扩展**: 自动填充密码
- **企业版**: SSO, SCIM, 合规报告
- **密钥即服务**: SaaS 版本

---

*本文档持续更新，最后修改: 2026-02-07*
