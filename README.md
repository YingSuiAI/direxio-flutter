# p2p-matrix-client

> P2P-IM 的多端客户端（Flutter）。当前阶段：Matrix / 统一消息服务接入版

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-blue.svg)](https://flutter.dev)
[![Android APK](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/android-apk.yml)
[![Windows EXE](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml/badge.svg)](https://github.com/P2P-IM/p2p-matrix-client/actions/workflows/windows-exe.yml)

---

## 定位

P2P-IM 项目的多端客户端，目标覆盖 **Android / iOS / Web / macOS / Windows / Linux**。

当前仓库已经接入真实 Matrix / 统一消息服务链路，未登录状态仍保留少量演示数据用于界面开发：

- Portal Token 登录、Matrix session 持久化代码已在 `auth_provider.dart` 内实现。
- 业务 API 已统一到 `HttpAsClient`，用 `portal_token` 调 `/_p2p/*`。
- AI Bot 演示会话不再连接独立 `/api/*` Gateway；真实 Agent 会话走 Matrix room 与统一业务 API。

> 真后端接入路径见组织内 [`p2p-matrix-as`](https://github.com/P2P-IM/p2p-matrix-as)（Matrix Application Service）+ [`p2p-matrix-ops`](https://github.com/P2P-IM/p2p-matrix-ops)（Dendrite homeserver）。

---

## 当前进度（2026-06-20）

### Matrix 原生化迁移状态

- Matrix SDK 负责登录 session、room/timeline、普通文本消息、普通媒体消息、redaction、成员状态和媒体上传下载。
- `HttpAsClient` 负责 Direxio 产品层能力：好友申请、频道审批、群/频道管理、本地删除/隐藏、收藏、Agent/API 权限、portal status、bootstrap/unread/search 等。
- `GET /_p2p/events?since=<seq>` SSE 已接入为轻量刷新提示；客户端收到消息、redaction、profile、join request 等事件后刷新 Matrix sync 和必要的 P2P query，不再依赖高频 `sync.messages` 轮询。
- `sync.messages` 使用 cursor pagination，不再发送 `page` / `page_size` / `limit`。
- `portal.status` 解析 `policy_index_mode`、`policy_index_ready`、`event_stream_ready`，这些字段用于能力和诊断，不假设所有环境都为 ready。
- Direct invite 显示识别 native `io.direxio.room.profile`，不再依赖新 direct invite stripped state 写 legacy `p2p.contact.request`。
- 频道 post/comment 的 Matrix content 约定是：`p2p_kind=channel_post` / `channel_comment` 表示 Direxio 产品分类，Matrix `msgtype` 保持 `m.text` / `m.image` / `m.file` 等真实消息类型；`post_id`、`media_json`、`mentions`、`mentions_json` 等结构化字段需要保留。

普通聊天媒体和撤回已经迁到 Matrix Client-Server API。频道帖子/评论、频道点赞历史仍通过 AS 产品 API 查询/变更，直到对应 Matrix 原生 post/comment 投影接口具备完整客户端读写语义。

### 已完成

| 模块 | 状态 | 说明 |
|------|------|------|
| 会话列表 + 普通聊天 | ✅ Matrix | 登录后走 Matrix room/timeline；普通文本、媒体、撤回走 Matrix SDK；未登录展示演示会话 |
| AI Bot 会话 | ⚠️ 部分 | 演示快捷指令保留本地逻辑；真实 Agent 对话依赖 homeserver |
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
| 统一业务 API | ✅ HTTP/SSE | `HttpAsClient` 已接 `/_p2p/*` 查询/命令和 SSE，使用 `portal_token` |
| Agent / MCP 工具通路 | ⚠️ 部分 | 页面演示逻辑保留本地实现；真实 Agent 消息走 Matrix room |
| 真 Matrix 会话通路 | ✅ | 真 room / timeline、普通消息、媒体、redaction 已走 Matrix SDK；ProductPolicy 由服务端执行 |

### 进行中 / 计划

- [ ] macOS 包 CI（需要 GitHub Actions macOS runner 额度，按 10x 计费）
- [ ] iOS 包 CI（需要 Apple Developer 账号 + 证书）
- [ ] Web 部署（待定方案：Cloudflare Pages / Netlify / public mirror + GitHub Pages）
- [ ] Tag 触发 GitHub Releases（产物长期可下载链接）
- [ ] APK release 签名（接 keystore）
- [ ] 启用真实登录路由守卫（关闭 `P2P_MATRIX_MOCK_AUTH` 演示入口）
- [ ] 用 Dendrite + 统一 message-server 做端到端登录 / 业务 API 验证
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

### 登录、Matrix SDK 与 P2P API

当前认证模型是两套凭证、职责分离：

1. 首次初始化或重置登录口令时，用户扫描 `https://{domain}/setup` 上的一次性 setup QR。
2. App 用 QR 中的 `setup_code` 调 `POST /_as/bootstrap`，拿到 Matrix `access_token` 和当前 `portal_token`。
3. App 立刻调用 `PUT /_as/portal/token`，把长期登录口令旋转成用户输入的新口令。
4. 日常登录时，App 用长期 `portal_token` 调 `POST /_as/auth` 获取新的 Matrix `access_token`。
5. Matrix SDK 用 Matrix `access_token` 走标准 Matrix 消息/房间 API。
6. `asClientProvider` 请求 `/_p2p/*` 产品 API 时统一带 portal token：

```http
Authorization: Bearer {portal_token}
```

`portal_token` 和 Matrix `access_token` 都写入 `flutter_secure_storage`，但用途不同：前者只给 AS Admin API，后者只给 Matrix SDK。

P2P 产品 API 当前主要保留给 Matrix 不建模或本地产品状态能力：

| 能力 | 方法 |
|------|------|
| Portal 状态 | `portal.status` |
| SSE 刷新提示 | `GET /_p2p/events?since=<seq>` |
| Bootstrap / unread / search | `sync.bootstrap` / `sync.unread` / search |
| 好友/群/频道管理 | friend request、group/channel management、channel approval |
| 本地状态 | local delete/hide、favorites |
| Agent / API 权限 | Agent/MCP/API policy |

部署路径约定：

- 生产：`https://{domain}/_p2p/*`
- 本地 AS：如果 homeserver 是 `http://127.0.0.1:8008` / `localhost`，client 自动映射到本地 P2P API 端口

Matrix 普通消息、媒体、reaction、redaction 应优先走 Matrix SDK。P2P command 不应用来绕过服务端 ProductPolicy。

### 统一业务 API / Agent API

客户端只连接 homeserver 暴露的统一 `/_p2p/*` 业务接口，不再连接独立 `19091` Gateway 或 `/api/*` 服务。

登录成功后，`HttpAsClient` 会从 Matrix homeserver 推导 `/_p2p` base URL，并使用登录返回的 `admin_access_token` 访问联系人、群聊、频道、搜索、Agent 状态和消息分页等业务接口。

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

- **真实链路优先**：业务 API 统一使用 `HttpAsClient`，不要新增独立 Gateway 客户端
- **演示入口**：`P2P_MATRIX_MOCK_AUTH=true` 时跳过登录，仅用于本地 UI 验证
- **后端接入**：端到端联调需要统一 message-server、PostgreSQL 和 portal token 就绪
- **代码风格**：默认不写注释；非显然意图（why）才注释，不要写 what
- **PR 流程**：开 feature 分支 → PR 到 main → 两个 CI 都绿 → merge

---

## 贡献

PR 提到 `main` 即可。CI 会自动跑 Android + Windows 构建，两个绿才推荐 merge。

如果改动只涉及文档（`**/*.md`）或 web 入口（`web/`），CI 会自动跳过原生构建（`paths-ignore`）。

---

## License

MIT
