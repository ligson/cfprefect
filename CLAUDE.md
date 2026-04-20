# IP优选工具 - 跨平台 Cloudflare IP 优选工具

## 重要文档
- [开发规则](docs/development_rules.md) - 必读，包含 API 规范、UI 要求、文件结构
- [更新日志](CHANGELOG.md) - 每次改动记录

## 项目目标
一个跨平台应用（Windows/Mac/Android），帮助用户找到延迟最低的 Cloudflare IP，并更新 Clash 配置文件。

## 核心功能

### 当前功能
- ✅ 跨平台 UI：Flutter（支持 Windows/Mac/Android）
- ✅ 扫描 Cloudflare IP 列表
- ✅ 延迟测试：并发 HTTP 请求，显示响应时间
- ✅ Clash 配置文件修改：直接替换 server 字段
- ✅ 自动备份原配置文件
- ✅ 兼容 VMess/Vless/Trojan 协议

### 使用场景
适用于 Cloudflare WARP + Clash 用户：
1. 扫描获取最快的 Cloudflare IP
2. 选择 Clash 配置文件
3. 自动更新配置中的 server 字段
4. 重新加载 Clash 配置即可

## 技术栈
- **框架**：Flutter (Dart)
- **跨平台支持**：Windows / macOS / Android
- **网络库**：`http` package
- **文件操作**：`file_picker` + `path_provider`

## 开发规则

### Cloudflare API 字段名
- API 返回的字段名是 `ipv4_cidrs` 和 `ipv6_cidrs`

### Android 模拟器网络配置
每次启动模拟器后需配置代理：
```bash
adb shell "settings put global http_proxy 10.0.2.2:7897"
```

### Android 模拟器性能优化
- 并发数限制：10（避免崩溃）
- 内存配置：4GB RAM, 512MB Heap

## 目录结构
```
.
├── CLAUDE.md                    # 项目文档
├── CHANGELOG.md                 # 更新日志
├── pubspec.yaml                 # Flutter 依赖配置
├── lib/
│   ├── main.dart                # 应用入口
│   ├── screens/
│   │   └── home_screen.dart     # 主界面
│   ├── services/
│   │   ├── cloudflare_service.dart  # IP 扫描逻辑
│   │   ├── ping_service.dart        # 延迟测试逻辑
│   │   └── clash_config_service.dart # Clash 配置修改
│   └── widgets/
│       └── ip_list_widget.dart  # IP 列表展示组件
```

## 使用说明
1. 点击 "优选 IP" 按钮
2. 等待 IP 扫描和延迟测试完成
3. 从列表中选择一个 IP
4. 点击 "选择" 按钮，选择 Clash 配置文件
5. 点击 "更新配置" 按钮
6. 重新加载 Clash 配置

## 开发环境要求
- Flutter SDK >= 3.0
- Dart >= 3.0
