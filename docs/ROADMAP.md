# ClawBox 版本规划与路线图

## 版本命名规范

遵循 [Semantic Versioning 2.0](https://semver.org/):

- **MAJOR.MINOR.PATCH** (如 `1.2.3`)
- MAJOR: 不兼容的 API 变更
- MINOR: 向后兼容的新功能
- PATCH: 向后兼容的 bug 修复

---

## 版本规划

### v0.1.0 - MVP 🎯

**目标**: 可用的 CLI 基础版本

**预计时间**: 2 周

**功能清单**:

- [ ] 项目结构搭建
  - [ ] Rust workspace 配置
  - [ ] CI/CD 基础 (GitHub Actions)
  - [ ] 文档结构

- [ ] 加密核心
  - [ ] Argon2id 密钥派生
  - [ ] AES-256-GCM 加密/解密
  - [ ] 安全随机数生成
  - [ ] 内存安全 (zeroize)

- [ ] 存储引擎
  - [ ] SQLite 数据库初始化
  - [ ] 密钥 CRUD 操作
  - [ ] 事务支持

- [ ] CLI 基础命令
  - [ ] `clawbox init` - 初始化保险库
  - [ ] `clawbox set` - 设置密钥
  - [ ] `clawbox get` - 获取密钥
  - [ ] `clawbox list` - 列出密钥
  - [ ] `clawbox delete` - 删除密钥
  - [ ] `clawbox unlock` / `lock` - 解锁/锁定

- [ ] 测试
  - [ ] 单元测试 (>80% 覆盖率)
  - [ ] 集成测试

**发布物**:
- Linux x64 二进制
- macOS ARM64 二进制
- macOS x64 二进制

---

### v0.2.0 - 权限与审计 📊

**目标**: 完善的权限控制和审计追踪

**预计时间**: 2 周 (累计 4 周)

**功能清单**:

- [ ] 访问级别
  - [ ] 四级权限: public, normal, sensitive, critical
  - [ ] 默认权限配置
  - [ ] 权限修改命令

- [ ] 审计日志
  - [ ] 日志记录引擎
  - [ ] 链式哈希完整性
  - [ ] `clawbox audit` 命令
  - [ ] 日志导出

- [ ] 密钥管理增强
  - [ ] 密钥分组 (路径层级)
  - [ ] 标签系统
  - [ ] 备注功能
  - [ ] `clawbox rename` 命令

- [ ] CLI 改进
  - [ ] 彩色输出
  - [ ] 进度指示
  - [ ] Shell 自动补全

**发布物**:
- 更新的多平台二进制
- 完整 CLI 文档

---

### v0.3.0 - macOS App 🍎

**目标**: 原生 macOS 图形界面

**预计时间**: 3 周 (累计 7 周)

**功能清单**:

- [ ] FFI 层
  - [ ] Rust → C 绑定
  - [ ] Swift 桥接
  - [ ] 内存管理

- [ ] macOS App 基础
  - [ ] SwiftUI 主界面
  - [ ] 密钥列表视图
  - [ ] 密钥详情/编辑
  - [ ] 搜索功能

- [ ] 系统集成
  - [ ] 菜单栏图标
  - [ ] 快捷键
  - [ ] 启动时自动解锁 (可选)

- [ ] 通知系统
  - [ ] 敏感密钥访问通知
  - [ ] 审批弹窗
  - [ ] 一键审批/拒绝

**发布物**:
- macOS .dmg 安装包
- macOS .pkg 安装包
- App 使用文档

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

### v1.0.0 - 正式发布 🚀

**目标**: 稳定、完善、可生产使用

**预计时间**: 累计 14-16 周

**功能清单**:

- [ ] 稳定性
  - [ ] API 冻结
  - [ ] 性能优化
  - [ ] 全平台测试

- [ ] 生态集成
  - [ ] OpenClaw 插件
  - [ ] VS Code 扩展 (可选)
  - [ ] 浏览器扩展 (可选)

- [ ] 文档完善
  - [ ] 用户指南
  - [ ] API 文档
  - [ ] 安全白皮书
  - [ ] 多语言支持

- [ ] 发布准备
  - [ ] Homebrew formula
  - [ ] AUR 包
  - [ ] 官网上线

**发布物**:
- 全平台稳定版
- 完整文档
- 官方网站

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
