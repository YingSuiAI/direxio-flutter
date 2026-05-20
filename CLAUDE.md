# p2p-matrix-client — 项目开发规范

P2P-IM 的多端 Flutter 客户端。当前阶段：UI Mock + Matrix / AS 接入过渡版。

## 开始任何任务前

1. 判断改动涉及哪一层，**先读对应目录的 `CLAUDE.md`**：
   - 改 `lib/presentation/` 下的 UI（页面 / 组件 / 样式）→ **必须先读 [`lib/presentation/CLAUDE.md`](lib/presentation/CLAUDE.md)** 并严格遵守其中的 M3 设计规范。
2. 没有专属 `CLAUDE.md` 的目录，遵守本文件的通用规范。

## 项目结构

```
lib/
├── core/
│   ├── router/        go_router 路由
│   └── theme/         design_tokens.dart（M3 配色）+ app_theme.dart（主题/字体）
├── data/              后端接口层：well_known_service / as_client / http_as_client / mock_as_client
└── presentation/
    ├── pages/         路由页（见 lib/presentation/CLAUDE.md）
    ├── widgets/       可复用 widget；widgets/m3/ 是 M3 组件库
    ├── providers/     Riverpod providers
    └── mock/          Mock 数据 / Mock MCP Client / 权限·审计 store
```

## 通用约定

### 设计 / UI
- UI 一律遵循 [`lib/presentation/CLAUDE.md`](lib/presentation/CLAUDE.md)：M3 设计体系、`context.tk` 配色 token、`AppTheme.sans` 字阶、`Symbols.*` 图标、复用 `widgets/m3/` 组件。
- **不要硬编码颜色、字号、十六进制色值**。

### 架构
- 状态管理：Riverpod 2 + riverpod_annotation。
- 后端能力走接口 + 实现注入模式（如 `AsClient` → `HttpAsClient` / `MockAsClient`）。新接外部能力照此抽象。
- AS Admin API 默认走 `HttpAsClient`，复用 Matrix `access_token` 调 `/_as/*`；AS 不单独登录。
- Mock 兜底：真后端未就绪前，Agent / MCP 通路仍用 Mock 替身。Mock 房间 id 以 `mock_` 开头。
- 当前 `app_router.dart` 仍保留 mock redirect 跳过登录；启用真实登录时先移除该 redirect，再走 `AuthStateNotifier.login/register`。

### 代码风格
- 默认不写注释；仅在「为什么」非显然时写一行。不写「做了什么」的注释。
- 不留废代码 / 不做无谓的向后兼容 shim。
- 改动需求范围内的最小实现，不过度抽象。

### 依赖
- 加新依赖前先确认现有依赖能否满足。
- Flutter 3.41.9（Dart 3.7+，`gpt_markdown` 要求）。

## 构建验证

改完务必本地验证编译：
```
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run
```
国内网络设镜像：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

## CI

push / PR 到 `main` 自动跑 Android APK + Windows EXE 构建（`.github/workflows/`）。两个 check 绿才 merge。
