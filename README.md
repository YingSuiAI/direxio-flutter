# p2p-matrix-client

> P2P-IM 的客户端（Flutter）。当前阶段：纯 UI / Mock 演示版

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-blue.svg)](https://flutter.dev)

---

## 定位

`p2p-matrix-client` 是 P2P-IM 项目的多端客户端，目标是覆盖 **Android / iOS / Web / macOS / Windows / Linux**。

当前仓库内是**纯 UI Mock 演示版**：架构铺好、Matrix SDK 集成代码保留，但运行时数据全部走本地 Mock，不连真后端。**用来快速演示产品形态、对齐设计、迭代 Agent 交互**。

> 真后端接入路径见组织内的 [`p2p-matrix-as`](https://github.com/P2P-IM/p2p-matrix-as)（Matrix Application Service）+ [`p2p-matrix-ops`](https://github.com/P2P-IM/p2p-matrix-ops)（Dendrite homeserver）。

---

## 演示能力

| 模块 | 状态 | 说明 |
|------|------|------|
| 会话列表 + 普通聊天 | ✅ Mock | Jack 工作伙伴对话 |
| AI Bot 会话 | ✅ Mock | 含飞书风格快捷指令浮条 |
| Markdown 渲染 | ✅ | 表格 / 列表 / 引用 / 行内代码 / 代码块 / LaTeX |
| 流式输出 + Typing 指示 | ✅ Mock | 按字符喂入 + 三点跳动 |
| 工具调用气泡 | ✅ Mock | 可折叠看 args / warnings / latency |
| 二次确认条 | ✅ Mock | 写类工具调用经用户确认才执行 |
| MCP 权限设置 | ✅ Mock | 7 个维度：工具 / 会话 / 时间 / 内容 / 频次 / 生命周期 / 审计 |
| 审计日志 | ✅ Mock | 每次工具调用按结果颜色编码列出 |
| Agent Tab | ✅ Mock | 独立底栏入口，统计 + Agent 列表 + 最近活动 |
| PC 响应式 | ✅ | ≥ 900px 自动 master-detail 双栏 |
| 长按消息菜单 | ✅ | 复制 / 引用 / 转发 / 让 AI Bot 解读 |
| AI 建议回复 | ✅ Mock | 普通会话输入框上方 chip |
| 真 Matrix 通路 | 📦 保留 | 代码在但跳过登录走 Mock；后端 ready 后只需删 router redirect |

---

## 快速开始

### 依赖

- Flutter 3.41 (Dart 3.11)
- 国内推荐设环境变量走镜像：
  ```bash
  export PUB_HOSTED_URL=https://pub.flutter-io.cn
  export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
  ```

### 起步

```bash
git clone https://github.com/P2P-IM/p2p-matrix-client.git
cd p2p-matrix-client

# 1. 拉依赖
flutter pub get

# 2. 生成 freezed / riverpod 代码（本仓库不提交 .g.dart）
flutter pub run build_runner build --delete-conflicting-outputs

# 3. 跑起来
flutter run -d chrome        # Web
flutter run -d <android-id>  # 真机或模拟器
```

### 路径速览

启动后默认跳过登录直接进首页：

- **消息 tab** → AI Bot / Jack 两个 mock 会话
- **Agent tab** → Agent 中心、Agent 列表、最近活动
- **进 AI Bot** → 上方"快捷指令"可触发：
  - 查询 Token 用量
  - 总结最近的聊天
  - 代我回复 Jack（演示二次确认）
  - 新建会话
- **设置 → MCP / Agent 权限** → 编辑 Agent 的工具/会话/时间等权限

---

## 项目结构

```
lib/
├── core/
│   ├── router/             # go_router 路由
│   └── theme/              # 设计 token + 主题
├── presentation/
│   ├── mock/               # Mock 数据 + Mock MCP Client + 权限/审计 store
│   │   ├── mock_data.dart
│   │   ├── mcp_policy.dart
│   │   ├── mcp_audit.dart
│   │   └── mock_mcp_client.dart
│   ├── pages/              # 路由页
│   ├── providers/          # Riverpod providers
│   └── widgets/            # 可复用 widget
│       ├── agent_message_body.dart  # Markdown 渲染
│       └── tool_call_bubble.dart    # 工具调用气泡 + Typing
└── main.dart
```

---

## 技术栈

- **状态管理**：Riverpod 2 + riverpod_annotation
- **路由**：go_router
- **Markdown**：gpt_markdown（专为 LLM 输出优化）
- **Matrix SDK**：matrix ^0.30（当前 mock 阶段保留 import，未调用）
- **图标**：flutter_lucide
- **代码生成**：freezed + json_serializable + build_runner

---

## 与组织内其他仓库的关系

```
┌──────────────────────────────────────────────────────────────┐
│            p2p-matrix-client (本仓库)                        │
│            Flutter 多端客户端                                │
└──────────────┬───────────────────────────┬───────────────────┘
               │                           │
   走 Matrix SDK 直连                 走 MCP/AS 协议
               │                           │
               ▼                           ▼
   ┌───────────────────────┐   ┌───────────────────────────┐
   │  p2p-matrix-ops       │   │  p2p-matrix-as            │
   │  Dendrite + nginx     │   │  Application Service 网关 │
   │  + systemd 部署       │   │  + WS 事件 + REST API     │
   └───────────────────────┘   └─────────────┬─────────────┘
                                              │
                                              ▼
                                ┌──────────────────────────┐
                                │  p2p-matrix-agent        │
                                │  MAP 协议 + 多语言 SDK   │
                                └──────────────────────────┘
```

---

## 开发约定

- **Mock 优先**：所有 Agent / Matrix 真实通路在跑通真后端前都用 Mock 替身
- **检测前缀**：Mock 房间 id 以 `mock_` 开头，命中后走 mock 通路
- **接 backend 时**：删 `app_router.dart` 里的 mock redirect、把 `MockMcpClient` 换成真实 MCP server adapter，UI 一行不用改

---

## License

MIT
