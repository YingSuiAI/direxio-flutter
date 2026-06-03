# p2p-matrix-client

> P2P-IM 的多端客户端（Flutter）。当前阶段：Matrix / AS Gateway 接入版

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-blue.svg)](https://flutter.dev)
[![Android APK](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml)
[![Windows EXE](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml)

---

## 定位

P2P-IM 项目的多端客户端，目标覆盖 **Android / iOS / Web / macOS / Windows / Linux**。

当前仓库已经接入真实 Matrix / AS Gateway 链路，未登录状态仍保留少量演示数据用于界面开发：

- Portal Token 登录、Matrix session 持久化代码已在 `auth_provider.dart` 内实现。
- AS Admin API 已有 HTTP 客户端，用 `portal_token` 调 `/_as/*`。
- AI Bot 快捷指令通过 `AsGatewayClient` 调 `p2p-matrix-as` 的 `/api/*` Gateway 接口。

> 真后端接入路径见组织内 [`p2p-matrix-as`](https://github.com/P2P-IM/p2p-matrix-as)（Matrix Application Service）+ [`p2p-matrix-ops`](https://github.com/P2P-IM/p2p-matrix-ops)（Dendrite homeserver）。

---

## 当前进度（2026-05-24）

### 已完成

| 模块 | 状态 | 说明 |
|------|------|------|
| 会话列表 + 普通聊天 | ⚠️ 部分 | 登录后走 Matrix room；未登录展示演示会话 |
| AI Bot 会话 | ⚠️ 部分 | 快捷指令已接 AS Gateway；完整对话依赖 homeserver |
| Markdown 渲染 | ✅ | 表格 / 列表 / 引用 / 行内代码 / 代码块 / LaTeX |
| 流式输出 + Typing 指示 | ✅ | 按字符喂入 + 三点跳动 |
| 工具调用气泡 | ✅ | 可折叠看 args / warnings / latency |
| 二次确认条 | ✅ | 写类工具调用经用户确认才执行 |
| MCP 权限设置 | ⚠️ UI 就绪 | 7 个维度：工具 / 会话 / 时间 / 内容 / 频次 / 生命周期 / 审计 |
| 审计日志 | ⚠️ UI 就绪 | 每次工具调用按结果颜色编码列出 |
| Agent Tab | ⚠️ UI 就绪 | 独立底栏入口，统计 + Agent 列表 + 最近活动 |
| 长按消息菜单 | ✅ | 复制 / 引用 / 转发 / 让 AI Bot 解读 |
| AI 建议回复 | ⚠️ UI 就绪 | 普通会话输入框上方 chip |
| PC 响应式布局 | ✅ | ≥ 900px 自动 master-detail 双栏 |
| **Android APK CI** | ✅ | push / PR 自动出 debug APK |
| **Windows EXE CI** | ✅ | push / PR 自动出 release zip |
| Portal Token 登录 / 初始化 | ⚠️ 代码就绪 | `AuthStateNotifier` 已实现；当前演示路由仍跳过登录直进首页 |
| AS Admin API | ✅ HTTP | `HttpAsClient` 已接 `/_as/*`，使用 `portal_token` |
| AS Gateway / MCP 工具通路 | ⚠️ 部分 | `AsGatewayClient` 已接 `/api/*`；消息历史和搜索等依赖 AS 后续实现 |
| 真 Matrix 会话通路 | ⚠️ 部分 | 真 room / timeline 代码在；端到端依赖 Dendrite + AS registration |

### 进行中 / 计划

- [ ] macOS 包 CI（需要 GitHub Actions macOS runner 额度，按 10x 计费）
- [ ] iOS 包 CI（需要 Apple Developer 账号 + 证书）
- [ ] Web 部署（待定方案：Cloudflare Pages / Netlify / public mirror + GitHub Pages）
- [ ] Tag 触发 GitHub Releases（产物长期可下载链接）
- [ ] APK release 签名（接 keystore）
- [ ] 启用真实登录路由守卫（关闭 `P2P_MATRIX_MOCK_AUTH` 演示入口）
- [ ] 用 Dendrite + p2p-matrix-as 做端到端登录 / AS Admin API 验证
- [ ] 接入真 Matrix homeserver，完成真实 room / timeline 验证
- [ ] 接入真 MCP server adapter，替换页面内演示工具调用

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

当前认证模型是两套凭证、职责分离：

1. 首次初始化或重置登录口令时，用户扫描 `https://{domain}/setup` 上的一次性 setup QR。
2. App 用 QR 中的 `setup_code` 调 `POST /_as/bootstrap`，拿到 Matrix `access_token` 和当前 `portal_token`。
3. App 立刻调用 `PUT /_as/portal/token`，把长期登录口令旋转成用户输入的新口令。
4. 日常登录时，App 用长期 `portal_token` 调 `POST /_as/auth` 获取新的 Matrix `access_token`。
5. Matrix SDK 用 `access_token` 走标准 Matrix 消息/房间 API。
6. `asClientProvider` 请求 `/_as/*` 时统一带：

```http
Authorization: Bearer {portal_token}
```

`portal_token` 和 Matrix `access_token` 都写入 `flutter_secure_storage`，但用途不同：前者只给 AS Admin API，后者只给 Matrix SDK。

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

### AS Gateway / Agent API

AI Bot 页面中的“测试 AS 连接”会通过 `AsGatewayClient` 请求 `p2p-matrix-as` Gateway：

```bash
flutter run -d chrome \
  --dart-define=P2P_MATRIX_AS_URL=http://127.0.0.1:19091 \
  --dart-define=P2P_MATRIX_AGENT_TOKEN=<gateway-or-portal-token>
```

配置项：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `P2P_MATRIX_AS_URL` | AS Gateway 地址，提供 `/api/*` | `http://127.0.0.1:19091` |
| `P2P_MATRIX_AGENT_TOKEN` | Gateway Bearer token；本地 AS 单 token 模式下可使用 portal token | 空 |
| `P2P_MATRIX_AS_TIMEOUT_MS` | Gateway 请求超时 | `10000` |
| `P2P_MATRIX_AS_RETRY_COUNT` | GET / 幂等发送请求重试次数 | `2` |

注意：`p2p_auth_status` 只检查本地配置是否存在，不访问后端；房间列表、联系人、发送消息会真实请求 AS Gateway。若 Dendrite 未启动或 AS registration 未加载，这些请求会返回 AS 后端错误。

### 已知本地编译坑

| 问题 | 原因 | 处理 |
|------|------|------|
| `record_linux` 接口不匹配 | record 系列 transitive 版本冲突 | CI 已通过 sed patch 删除；本地若编 desktop 同样要删 |
| `flutter_webrtc` 找不到 `PluginRegistry.Registrar` | 0.9.x 用了 Flutter v1 embedding（3.29+ 已删） | 同上，未来升级到 ^1.0.0 修复 |
| Windows build 报 `symlink support required` | 未启 Developer Mode | 系统设置 → 开发者选项 → 启用 |
| Android Gradle 拉依赖超时 | 国内访问 maven.google.com 不稳 | 项目 `~/.gradle/init.gradle` 或工程 settings.gradle 加阿里云镜像 |

### 路径速览

当前演示路由默认跳过登录直接进首页。真实登录页和登录逻辑已经实现，启用真登录时将 `P2P_MATRIX_MOCK_AUTH=false`。

- **消息 tab** → 未登录展示演示会话；登录后展示 Matrix room
- **Agent tab** → Agent 中心、Agent 列表、最近活动
- **进 AI Bot** → 上方"快捷指令"可触发：
  - 测试 AS Gateway 连接
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
3. **patch pubspec.yaml**：删除当前未使用的 `record` 依赖
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

### 为什么要 patch record

仓库 pubspec 声明了 `record`，但当前代码没有直接调用录音 API；`record_linux` 与部分 runner 上的 transitive 版本组合可能触发接口签名不匹配。CI 目前只在打包时删除 `record`，让 Android/Windows 包先稳定产出。

`flutter_webrtc` 已被 Matrix VoIP、私聊语音和私聊视频通话真实使用，不能再从 CI 中删除。

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
│   │   ├── http_as_client.dart       # AS HTTP 实现，使用 portal_token
│   │   ├── as_gateway_client.dart    # AS Gateway /api/* HTTP client
│   │   ├── mock_as_client.dart       # 旧演示数据适配器
│   │   └── well_known_service.dart   # Matrix / Portal well-known 发现
│   ├── presentation/
│   │   ├── mock/
│   │   │   ├── mock_data.dart           # 未登录演示会话数据
│   │   │   ├── mcp_policy.dart          # MCP 权限模型 + store
│   │   │   ├── mcp_audit.dart           # 审计日志 store
│   │   │   └── mock_mcp_client.dart     # 旧演示工具调用适配器
│   │   ├── pages/
│   │   │   ├── home_page.dart           # 底栏 + 四个 tab（含 Agent tab）
│   │   │   ├── chat_page.dart           # Matrix timeline + AS Gateway 快捷指令
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

- **真实链路优先**：AS Admin API 使用 `HttpAsClient`，AI Bot 快捷指令使用 `AsGatewayClient`
- **演示入口**：`P2P_MATRIX_MOCK_AUTH=true` 时跳过登录，仅用于本地 UI 验证
- **后端接入**：端到端联调需要 Dendrite、p2p-matrix-as、AS registration 和 gateway token 同时就绪
- **代码风格**：默认不写注释；非显然意图（why）才注释，不要写 what
- **PR 流程**：开 feature 分支 → PR 到 main → 两个 CI 都绿 → merge

---

## 贡献

PR 提到 `main` 即可。CI 会自动跑 Android + Windows 构建，两个绿才推荐 merge。

如果改动只涉及文档（`**/*.md`）或 web 入口（`web/`），CI 会自动跳过原生构建（`paths-ignore`）。

---

## License

MIT
