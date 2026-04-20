# 开发规则

## ⚠️ 记忆规则（非常重要）

### 记忆持久化
- **重要项目信息必须放在 `docs/` 目录**（会提交到 git）
- **切换模型时，只读取 git 仓库中的文档**
- **每次会话结束前，确认重要信息已写入 `docs/` 目录**

### 会话结束检查清单
1. ✅ 改动记录到 CHANGELOG.md
2. ✅ 开发规则更新到 docs/development_rules.md
3. ✅ 项目关键信息在 docs/ 目录
4. ✅ 用户偏好更新到记忆文件

---

## Cloudflare API

### API 端点
- URL: `https://api.cloudflare.com/client/v4/ips`
- 返回字段：`ipv4_cidrs` 和 `ipv6_cidrs`（不是 `ipv4` 和 `ipv6`）

### IP 生成规则
- 每个 CIDR 段按配置数量均匀采样
- 跳过 `.0` 网络地址
- 只扫描 IPv4，不需要 IPv6

## 扫描配置

### 默认值
- 超时时间：1 秒
- 每段扫描数量：100 个 IP
- 并发数：100

### 配置范围
- 超时：1-10 秒
- 每段数量：10-1000

## UI/UX 要求

### 配色主题
- 风格：参考 VSCode
- 主色：VSCode 蓝 (#007ACC)
- 延迟显示：统一使用绿色
- 所有界面元素必须适配明暗模式

### 界面要求
- 扫描日志背景适配暗色模式
- 设置对话框适配暗色模式
- 统计信息条适配暗色模式
- 取消按钮暗色模式下使用深红色背景

### 用户反馈
- 取消扫描立即显示"正在取消扫描..."
- 扫描进度实时显示剩余时间
- 只显示成功的 IP，失败过滤

## 文件结构

```
lib/
├── main.dart                 # 应用入口
├── theme/
│   └── app_theme.dart        # 统一主题配置
├── screens/
│   └── home_screen.dart      # 主界面
├── services/
│   ├── cloudflare_service.dart  # IP 扫描逻辑
│   ├── ping_service.dart        # 延迟测试逻辑
│   └── dns_service.dart         # DNS 修改逻辑
└── widgets/
    └── ip_list_widget.dart   # IP 列表展示组件
```

## Git 提交规范

- 每次改动记录到 CHANGELOG.md
- 重要开发规则更新到 docs/development_rules.md
