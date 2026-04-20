# Changelog

## [2026-04-20]

### Documentation
- **README 完善**
  - 补充项目介绍、功能特性、使用说明、开发环境和自动发版说明
  - 补充 Clash 配置处理逻辑、目录结构和关键文件说明

### CI/CD
- **GitHub Actions 自动发版**
  - 新增 `.github/workflows/release.yml`
  - 每次推送 `main` 自动构建 macOS、Windows、Android APK
  - 自动上传构建产物到 GitHub Release
  - Release Notes 自动提取 `CHANGELOG.md` 最新一节
  - 使用固定 `main-latest` 滚动发布主干最新构建

### Bug Fixes
- **Android CI 构建失败**
  - 移除 `android/gradle.properties` 中写死的本地代理配置
  - 避免 GitHub Actions runner 连接 `127.0.0.1:7897` 导致 Gradle 下载失败

## [2026-04-19]

### Features
- **Clash 配置文件支持**
  - 新增 `lib/services/clash_config_service.dart`
  - 支持直接修改 Clash 配置文件中的 server 字段
  - 自动备份原配置文件（.bak）
  - 兼容 Clash Premium / Clash.Meta / 原版 Clash
  - 支持 VMess/Vless/Trojan 协议

- **跨平台统一方案**
  - Windows/Mac/Android 统一使用 Clash 配置文件方式
  - 移除 hosts 文件修改方式（需要管理员权限）
  - 文件选择器支持（file_picker 包）

### UI/UX
- **标题中文化**
  - 应用名称：IP优选工具
  - 窗口标题：IP优选工具

- **界面简化**
  - 移除"域名输入"框
  - 只保留 Clash 配置文件选择方式
  - 选择 IP 和配置文件后，"更新配置"按钮可用

### Bug Fixes
- **Android 模拟器网络问题**
  - 修复 cmdline-tools 目录结构（需要 `latest/` 子目录）
  - 添加 Gradle 代理配置（`android/gradle.properties`）
  - Flutter HTTP 客户端配置代理（`10.0.2.2:7897`）

- **Android 模拟器崩溃问题**
  - 降低并发数：100 → 10
  - 增加模拟器内存：2GB → 4GB
  - 增加 VM Heap：228MB → 512MB

### Dependencies
- 新增 `yaml: ^3.1.2` - YAML 解析
- 新增 `file_picker: ^8.0.0` - 文件选择器
- 新增 `path_provider: ^2.1.0` - 路径处理

### Files Changed
- `lib/screens/home_screen.dart` - 简化 UI，添加 Clash 配置支持
- `lib/services/clash_config_service.dart` - 新增 Clash 配置服务
- `lib/services/cloudflare_service.dart` - 添加代理支持
- `lib/services/ping_service.dart` - 降低并发数
- `android/gradle.properties` - 添加代理配置
- `~/.android/avd/Pixel_7a.avd/config.ini` - 增加内存配置

## [2026-04-18]

### UI/UX
- **VSCode 风格配色主题**
  - 主色：VSCode 蓝 (#007ACC)
  - 暗色模式：VSCode Dark 风格
  - 延迟显示：统一使用绿色
  - 设置对话框适配明暗模式
  - 扫描日志适配明暗模式
  - 圆角卡片设计，简洁专业
  - 新增 `lib/theme/app_theme.dart` 统一管理主题

- **取消扫描优化**
  - 点击取消后立即显示"正在取消扫描..."
  - 提升用户反馈体验

### Features
- **取消扫描功能**
  - 扫描中显示"取消扫描"按钮（红色）
  - 点击后显示友好提示"扫描已取消"
  - 自动重置回首页状态

- **预计剩余时间显示**
  - 扫描前：显示预计时间（基于 IP 数量和超时设置）
  - 扫描中：实时计算剩余时间
  - 扫描后：显示实际耗时

- **扫描设置界面**：右上角齿轮图标
  - 超时时间：1-10 秒可调（默认 1 秒）
  - 每段扫描数量：10-1000 可调（默认 100）
  - 实时显示预计总 IP 数

- **扫描进度显示**
  - 进度条显示当前进度
  - 实时日志显示成功的 IP 及延迟
  - 只显示成功的 IP，失败过滤

- **性能优化**
  - 并发数提高到 100 个
  - 均匀采样算法，覆盖每个 CIDR 段

### Changes
- **CloudflareService**: 从 CIDR 段中采样具体 IP
  - 原来：只提取网络地址（如 `173.245.48.0`）
  - 现在：从每个 CIDR 均匀采样指定数量 IP
  - 结果：15 个 CIDR → 可配置数量（默认 1500 个）
  - 文件：`lib/services/cloudflare_service.dart`

- **CloudflareService**: 只扫描 IPv4，移除 IPv6 支持
  - 原因：用户只需 IPv4 扫描
  - 文件：`lib/services/cloudflare_service.dart`

### Bug Fixes
- **CloudflareService**: 修复 API 字段名解析错误
  - 问题：API 返回 `ipv4_cidrs`/`ipv6_cidrs`，代码错误使用 `ipv4`/`ipv6`
  - 影响：导致获取 IP 数量为 0
  - 修复：将字段名改为 `ipv4_cidrs` 和 `ipv6_cidrs`
  - 文件：`lib/services/cloudflare_service.dart`

### Verified
- Mac 桌面版测试通过
- 成功获取 15 个 IPv4 CIDR
