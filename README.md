# IP优选工具

一个基于 Flutter 开发的跨平台 Cloudflare IP 优选工具，支持 Windows、macOS、Android。

它会从 Cloudflare 官方 IP 段中提取 IPv4 地址，批量测试延迟，并将你选中的最优 IP 写入 Clash 配置文件，减少手工查找和修改配置的成本。

## 功能特性

- 支持 Windows / macOS / Android
- 从 Cloudflare 官方 API 获取 IP 段
- 仅扫描 IPv4
- 按 CIDR 均匀采样生成可测试 IP
- 并发测试延迟并按结果排序
- 支持扫描取消、进度显示、预计剩余时间
- 支持选择 Clash 配置文件并直接更新 `server` 字段
- 修改前自动备份原配置文件为 `.bak`
- 兼容 VMess / VLESS / Trojan 常见配置

## 适用场景

适用于使用 Cloudflare WARP + Clash 的用户：

1. 扫描 Cloudflare 可用 IP
2. 找到延迟较低的 IP
3. 选择 Clash 配置文件
4. 一键替换代理节点中的 `server`
5. 重新加载 Clash 配置即可生效

## 工作原理

1. 调用 Cloudflare 官方接口获取 CIDR 列表
2. 从每个 IPv4 CIDR 中按配置数量均匀采样生成 IP
3. 对这些 IP 执行并发延迟测试
4. 展示可用 IP 和响应时间
5. 将选中的 IP 写回 Clash 配置文件中的 `proxies` 段
6. 如原 `server` 是域名，则尽量保留到 `servername`

## 支持平台

- macOS
- Windows
- Android

## 界面能力

当前版本提供：

- 一键开始优选 IP
- 扫描设置：超时时间、每段采样数量
- 扫描进度、实时日志、预计剩余时间
- 扫描中取消操作
- 结果列表选择 IP
- 本地 Clash 配置文件选择与更新

## 使用说明

### 1. 优选 IP

1. 打开应用
2. 点击“优选IP”
3. 等待扫描完成
4. 从结果列表中选择一个延迟较低的 IP

### 2. 更新 Clash 配置

1. 点击“选择”按钮选择 Clash 配置文件
2. 确认已选中一个 IP
3. 点击“更新配置”
4. 应用会自动备份原文件为 `配置文件名.bak`
5. 在 Clash 中重新加载配置

## Clash 配置处理说明

程序会只修改 `proxies` 段中的 `server` 字段，尽量保持其他内容不变。

处理行为：

- 自动备份原配置文件
- 仅替换代理节点中的 `server`
- 如果原 `server` 是域名，且后续没有 `servername`，会自动补上 `servername`

## 开发环境

- Flutter SDK 3.41+
- Dart 3.11+

本项目当前 `pubspec.yaml` 中的环境要求：

- `sdk: ^3.11.5`

## 本地运行

```bash
flutter pub get
flutter run
```

## 本地构建

### Android APK

```bash
flutter build apk --release
```

### macOS

```bash
flutter build macos --release
```

### Windows

```bash
flutter build windows --release
```

## Android 模拟器说明

如果你在 Android 模拟器中需要走本机代理，可在模拟器启动后手动设置：

```bash
adb shell "settings put global http_proxy 10.0.2.2:7897"
```

注意：

- 这是本地开发环境配置，不应写死到仓库共享配置中
- GitHub Actions 或其他 CI 环境不应依赖本地代理

## 核心依赖

- `http`：请求 Cloudflare API
- `yaml`：处理配置内容
- `file_picker`：选择 Clash 配置文件
- `path_provider`：路径处理

## 项目结构

```text
.
├── CHANGELOG.md
├── CLAUDE.md
├── docs/
│   └── development_rules.md
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   └── home_screen.dart
│   ├── services/
│   │   ├── clash_config_service.dart
│   │   ├── cloudflare_service.dart
│   │   ├── dns_service.dart
│   │   └── ping_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       └── ip_list_widget.dart
├── android/
├── macos/
├── windows/
└── pubspec.yaml
```

## 关键文件

- `lib/screens/home_screen.dart`：主界面与扫描流程
- `lib/services/cloudflare_service.dart`：Cloudflare IP 获取与 CIDR 采样
- `lib/services/ping_service.dart`：IP 延迟测试
- `lib/services/clash_config_service.dart`：Clash 配置文件修改与备份
- `lib/theme/app_theme.dart`：统一主题配置

## Cloudflare API 说明

使用接口：

- `https://api.cloudflare.com/client/v4/ips`

注意返回字段：

- `ipv4_cidrs`
- `ipv6_cidrs`

当前项目只使用 `ipv4_cidrs`。

## 自动发版

仓库已配置 GitHub Actions 自动发版流程：

- 触发条件：push 到 `main`
- 构建产物：macOS、Windows、Android APK
- 发布位置：GitHub Release
- Release Notes：自动提取 `CHANGELOG.md` 最新一节
- 发布方式：使用固定 `main-latest` 滚动发布主干最新构建

工作流文件：

- `.github/workflows/release.yml`

## 更新日志

所有功能变更请查看：

- [CHANGELOG.md](CHANGELOG.md)

## 开发规则

详细开发规则见：

- [docs/development_rules.md](docs/development_rules.md)

## 注意事项

- 当前优选逻辑以 IPv4 为主
- Android 模拟器环境与真机网络环境可能不同
- macOS/Windows/Android 的最终连通性仍受本机网络、代理和 Clash 配置影响
- 自动修改配置前会备份，但仍建议在重要配置上自行保留额外备份
