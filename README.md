# p2p-matrix-client

> P2P-IM 的多端客户端（Flutter）。当前阶段：UI Mock + Matrix / AS 接入过渡版

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-blue.svg)](https://flutter.dev)
[![Android APK](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml)
[![Windows EXE](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml)

---

## 定位

P2P-IM 项目的多端客户端，目标覆盖 **Android / iOS / Web / macOS / Windows / Linux**。

当前仓库保留完整 UI Mock 兜底，同时已经开始接入真实 Matrix / AS：

- Matrix 登录、注册、session 持久化代码已在 `auth_provider.dart` 内实现。
- AS Admin API 已有 HTTP 客户端，复用 Matrix `access_token` 调 `/_as/*`。
- 聊天、Agent / MCP 工具调用仍以 Mock 演示为主，真后端未完整跑通时不影响 UI 迭代。

> 真后端接入路径见组织内 [`p2p-matrix-as`](https://github.com/P2P-IM/p2p-matrix-as)（Matrix Application Service）+ [`p2p-matrix-ops`](https://github.com/P2P-IM/p2p-matrix-ops)（Dendrite homeserver）。

---

## 当前进度（2026-05-20）

### 已完成

| 模块 | 状态 | 说明 |
|------|------|------|
| 会话列表 + 普通聊天 | ✅ Mock | Jack 工作伙伴对话 |
| AI Bot 会话 | ✅ Mock | 飞书风格快捷指令浮条 |
| Markdown 渲染 | ✅ | 表格 / 列表 / 引用 / 行内代码 / 代码块 / LaTeX |
| 流式输出 + Typing 指示 | ✅ Mock | 按字符喂入 + 三点跳动 |
| 工具调用气泡 | ✅ Mock | 可折叠看 args / warnings / latency |
| 二次确认条 | ✅ Mock | 写类工具调用经用户确认才执行 |
| MCP 权限设置 | ✅ Mock | 7 个维度：工具 / 会话 / 时间 / 内容 / 频次 / 生命周期 / 审计 |
| 审计日志 | ✅ Mock | 每次工具调用按结果颜色编码列出 |
| Agent Tab | ✅ Mock | 独立底栏入口，统计 + Agent 列表 + 最近活动 |
| 长按消息菜单 | ✅ | 复制 / 引用 / 转发 / 让 AI Bot 解读 |
| AI 建议回复 | ✅ Mock | 普通会话输入框上方 chip |
| PC 响应式布局 | ✅ | ≥ 900px 自动 master-detail 双栏 |
| **Android APK CI** | ✅ | push / PR 自动出 debug APK |
| **Windows EXE CI** | ✅ | push / PR 自动出 release zip |
| Matrix 登录 / 注册 | ⚠️ 代码就绪 | `AuthStateNotifier` 已实现；当前演示路由仍跳过登录直进首页 |
| AS Admin API | ✅ HTTP | `HttpAsClient` 已接 `/_as/*`，复用 Matrix token |
| 真 Matrix 会话通路 | ⚠️ 部分 | 真 room / timeline 代码在，Mock 房间仍作为兜底 |

### 进行中 / 计划

- [ ] macOS 包 CI（需要 GitHub Actions macOS runner 额度，按 10x 计费）
- [ ] iOS 包 CI（需要 Apple Developer 账号 + 证书）
- [ ] Web 部署（待定方案：Cloudflare Pages / Netlify / public mirror + GitHub Pages）
- [ ] Tag 触发 GitHub Releases（产物长期可下载链接）
- [ ] APK release 签名（接 keystore）
- [ ] 启用真实登录路由守卫（移除 `app_router.dart` 的 mock redirect）
- [ ] 用 Dendrite + p2p-matrix-as 做端到端登录 / AS Admin API 验证
- [ ] 接入真 Matrix homeserver（从 `mock_` 前缀切真 timeline）
- [ ] 接入真 MCP server（替换 `MockMcpClient` 为 stdio MCP adapter）

---

## 下载预编译包

每次 push 到 `main` 或提 PR 时自动出包。

### Android APK（debug）

最新成功构建 → [Actions 页面](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml) → 进入最近 run → **Artifacts** → `android-apk-debug`

或者 CLI：
```bash
gh run download --repo P2P-IM/p2p-matrix-client --name android-apk-debug
```

解压后 `adb install p2p-matrix-client-<sha>-debug.apk`，或者直接用文件管理器装。包大小约 70 MB（含所有 ABI）。

### Windows EXE（release）

→ [Windows Actions 页面](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml) → 进入最近 run → **Artifacts** → `windows-exe-release`

或：
```bash
gh run download --repo P2P-IM/p2p-matrix-client --name windows-exe-release
```

解压 zip 后双击 `portal_app.exe`。首次运行 Defender 会弹"不受信任的发布者"警告（exe 未签名），点 "More info → Run anyway"。包大小约 15 MB。

> Artifacts 保留 14 天。要长期链接请等 Releases 接入。

---

## 本地开发

### 依赖环境

- Flutter **3.41.9** (Dart 3.11+) - 必须，gpt_markdown ^1.0.20 要求 Dart 3.7+
- Android：JDK 17（AGP 8.x 要求）+ Android SDK + cmdline-tools
- Windows desktop：Visual Studio 2022 + "Desktop development with C++" workload + **启用 Windows Developer Mode**（设置 → 隐私与安全 → 开发者选项）
- 国内网络推荐设镜像：
  ```bash
  export PUB_HOSTED_URL=https://pub.flutter-io.cn
  export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
  ```

### 起步

```bash
git clone https://github.com/P2P-IM/p2p-matrix-client.git
cd p2p-matrix-client

# 拉依赖
flutter pub get

# 生成 freezed / riverpod 代码（本仓库不提交 .g.dart / .freezed.dart）
dart run build_runner build --delete-conflicting-outputs

# 跑起来
flutter run -d chrome              # Web
flutter run -d <android-device>    # Android
flutter run -d windows             # Windows desktop
```

### 登录与 AS Admin API

当前认证模型只有一套登录态：**Matrix 登录态**。AS 不单独发登录 token。

1. App 用 Matrix SDK 调 homeserver 的 `/_matrix/client/v3/login` 登录 `@owner:{domain}`。
2. Matrix SDK 返回 `access_token`、`user_id`、`device_id`。
3. App 把 session 写入 `flutter_secure_storage`。
4. `asClientProvider` 从当前 Matrix client 读取 homeserver 和 `accessToken`。
5. `HttpAsClient` 请求 `/_as/*` 时统一带：

```http
Authorization: Bearer {matrix_access_token}
```

AS 侧会把这个 token 转发给 homeserver 的 `/_matrix/client/v3/account/whoami` 校验，所以 client 不需要也不应该保存另一套 AS 密码。

AS Admin API 当前对接端点：

| 能力 | 方法 |
|------|------|
| 消息搜索 | `GET /_as/search?q=&room_id=&limit=` |
| Agent 配置 | `GET /_as/agent/config` / `PUT /_as/agent/config` |
| Agent 状态 | `GET /_as/agent/status` |
| 关注列表 | `GET /_as/follows` / `POST /_as/follows` / `DELETE /_as/follows/{domain}` |
| Portal 状态 | `GET /_as/portal/status` |

部署路径约定：

- 生产：`https://{domain}/_as/*`
- 本地 AS：如果 homeserver 是 `http://127.0.0.1:8008` / `localhost`，client 自动映射到 `http://127.0.0.1:9090/_as/*`

注意：`p2p-matrix-as` 当前 `/_as/search` 仍返回 501，client 已真实请求该接口；AS 未实现前搜索页会按空结果处理。

### 已知本地编译坑

| 问题 | 原因 | 处理 |
|------|------|------|
| `record_linux` 接口不匹配 | record 系列 transitive 版本冲突 | CI 已通过 sed patch 删除；本地若编 desktop 同样要删 |
| `flutter_webrtc` 找不到 `PluginRegistry.Registrar` | 0.9.x 用了 Flutter v1 embedding（3.29+ 已删） | 同上，未来升级到 ^1.0.0 修复 |
| Windows build 报 `symlink support required` | 未启 Developer Mode | 系统设置 → 开发者选项 → 启用 |
| Android Gradle 拉依赖超时 | 国内访问 maven.google.com 不稳 | 项目 `~/.gradle/init.gradle` 或工程 settings.gradle 加阿里云镜像 |

### 路径速览

当前演示路由默认跳过登录直接进首页。真实登录页和登录逻辑已经实现，但 `app_router.dart` 里仍保留 mock redirect，启用真登录时需要移除这段 redirect。

- **消息 tab** → AI Bot / Jack 两个 mock 会话
- **Agent tab** → Agent 中心、Agent 列表、最近活动
- **进 AI Bot** → 上方"快捷指令"可触发：
  - 查询 Token 用量
  - 总结最近的聊天
  - 代我回复 Jack（演示二次确认）
  - 新建会话
- **设置 → MCP / Agent 权限** → 编辑 Agent 的工具/会话/时间等权限

---

## CI / 自动打包流程

### 触发条件

| 事件 | 行为 |
|------|------|
| `push` 到 `main` | Android + Windows 各跑一次构建 |
| `pull_request` 目标 `main` | Android + Windows 各跑一次构建（PR 页面显示 status check） |
| 手动 `workflow_dispatch` | 单独触发某一个 workflow |
| `paths-ignore` | `**/*.md` / `web/**` 不触发原生构建 |

### Workflow 一览

| 文件 | 平台 | Runner | Flutter | 用时 | 产物 |
|------|------|--------|---------|------|------|
| `.github/workflows/android-apk.yml` | Android | ubuntu-latest | 3.41.9 | ~12 min | ~70 MB APK |
| `.github/workflows/windows-exe.yml` | Windows | windows-latest | 3.41.9 | ~14 min | ~15 MB zip |

### 通用步骤

每个 workflow 内部：

1. **checkout** 仓库
2. **setup Flutter 3.41.9 stable** (`subosito/flutter-action@v2`，自动缓存 SDK)
3. **patch pubspec.yaml**：删除 `record` 和 `flutter_webrtc` 两行
   - Linux 用 `sed -i -E`
   - Windows 用 PowerShell 正则
   - 同时删 `pubspec.lock` 让 pub 重新解锁
4. **flutter pub get**
5. **dart run build_runner build --delete-conflicting-outputs**
6. **flutter build**：
   - Android：`flutter build apk --debug --no-tree-shake-icons`
   - Windows：`flutter build windows --release --no-tree-shake-icons`
7. **打包 + 短 SHA 命名**：
   - Android：直接重命名 apk
   - Windows：`Compress-Archive` 整个 Release 目录
8. **upload-artifact**：保留 14 天

### 为什么要 patch record / flutter_webrtc

仓库 pubspec 声明了 `record` 和 `flutter_webrtc`（为未来 VoIP / 语音消息预留）。但：
- `record_linux 0.7.2` 跟 `record_platform_interface 1.5.0` 接口签名不匹配，Android 编译会挂
- `flutter_webrtc 0.9.x` 用了 Flutter 3.29+ 已删的 `PluginRegistry.Registrar`，Android 编译会挂

代码里没真正调用这俩包，CI 阶段直接删依赖编译，等未来集成真 VoIP 时再升级到能用的版本。

---

## 项目结构

```
p2p-matrix-client/
├── .github/workflows/
│   ├── android-apk.yml         # Android CI
│   └── windows-exe.yml         # Windows CI
├── android/                     # Android 原生工程（flutter create 生成）
├── windows/                     # Windows 原生工程（同上）
├── web/                         # Web 入口
├── assets/                      # 静态资源（占位）
├── lib/
│   ├── core/
│   │   ├── router/             # go_router
│   │   └── theme/              # 设计 token
│   ├── data/
│   │   ├── as_client.dart            # AS Admin API 抽象与模型
│   │   ├── http_as_client.dart       # AS HTTP 实现，复用 Matrix access_token
│   │   ├── mock_as_client.dart       # AS Mock 兜底
│   │   └── well_known_service.dart   # Matrix / Portal well-known 发现
│   ├── presentation/
│   │   ├── mock/
│   │   │   ├── mock_data.dart           # 会话/消息 mock
│   │   │   ├── mcp_policy.dart          # MCP 权限模型 + store
│   │   │   ├── mcp_audit.dart           # 审计日志 store
│   │   │   └── mock_mcp_client.dart     # 假 MCP 调用 + 权限闸门
│   │   ├── pages/
│   │   │   ├── home_page.dart           # 底栏 + 四个 tab（含 Agent tab）
│   │   │   ├── chat_page.dart           # 含 _MockChatScaffold + 工具气泡
│   │   │   ├── mcp_permission_page.dart # 权限入口
│   │   │   ├── mcp_policy_edit_page.dart# 权限编辑（配置 + 审计双 tab）
│   │   │   └── ...
│   │   ├── providers/
│   │   │   ├── auth_provider.dart      # Matrix Client + Auth state
│   │   │   └── as_client_provider.dart # 注入真实 AS HTTP client
│   │   └── widgets/
│   │       ├── agent_message_body.dart  # Markdown 渲染
│   │       ├── tool_call_bubble.dart    # 工具调用气泡 + Typing
│   │       └── portal_avatar.dart
│   └── main.dart
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

---

## 技术栈

| 类别 | 选型 |
|------|------|
| 状态管理 | Riverpod 2 + riverpod_annotation |
| 路由 | go_router |
| Markdown | gpt_markdown（专为 LLM 输出优化，支持流式） |
| Matrix SDK | matrix ^0.30（登录 / session / room timeline 通路） |
| 图标 | flutter_lucide |
| 代码生成 | freezed + json_serializable + build_runner |
| 多端原生 | Android (Gradle 8.x) / Windows (CMake) / Web (CanvasKit) |

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

- **Mock 兜底**：Agent / MCP 真实通路在跑通真后端前仍用 Mock 替身；AS Admin API 已切到 HTTP 实现
- **检测前缀**：Mock 房间 id 以 `mock_` 开头，命中后走 mock 通路
- **接 backend 时**：删 `app_router.dart` 里的 mock redirect、把 `MockMcpClient` 换成真实 MCP server adapter，AS Admin API 已通过 `HttpAsClient` 接入
- **代码风格**：默认不写注释；非显然意图（why）才注释，不要写 what
- **PR 流程**：开 feature 分支 → PR 到 main → 两个 CI 都绿 → merge

---

## 贡献

PR 提到 `main` 即可。CI 会自动跑 Android + Windows 构建，两个绿才推荐 merge。

如果改动只涉及文档（`**/*.md`）或 web 入口（`web/`），CI 会自动跳过原生构建（`paths-ignore`）。

---

## License

MIT
