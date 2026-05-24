# 复刻规范（每个 subagent 必读）

## 目标
把 `C:\Users\13185\my-project\P2P-APP-UI\index.html` 内对应的 `<div id="s-xxx" class="screen">` 段，**1:1 复刻成 Flutter widget 树**写入 `C:\Users\13185\my-project\p2p-matrix-client\lib\presentation\pages\<对应>_page.dart`。

## 必读文件
1. **`P2P-APP-UI/index.html`** — 完整设计稿，每段顶部有注释如 `<!-- ═══════════════════ CHAT DETAIL ═══════════════════ -->`，你只取自己负责的 screen。
2. **`p2p-matrix-client/lib/presentation/CLAUDE.md`** — UI 规范，必须遵守：
   - 不许硬编码颜色；用 `context.tk.xxx`（来自 `core/theme/design_tokens.dart`）
   - 不许硬编码字号；用 `AppTheme.sans(size:, weight:, color:)`
   - 图标统一 `Symbols.*`（material_symbols_icons），不要 flutter_lucide
   - 复用 `widgets/m3/`：`GlassHeader.primary/.detail`、`GlassHeaderButton`、`M3Card`、`M3PrimaryButton`、`M3InputField`、`PortalAvatar`、`OnlineDot`
3. **`p2p-matrix-client/lib/core/theme/design_tokens.dart`** — token 定义（PortalTokens light/dark），用 `context.tk.accent/bg/surface/...` 取值
4. **`p2p-matrix-client/lib/core/theme/app_theme.dart`** — `AppTheme.sans/.mono`
5. 看一遍**其他已经做好的 page**（比如 `login_page.dart`、`home_page.dart`）当作格式参考。

## Token 速查（index.html tailwind → context.tk）
- `bg-background` / `bg-surface` → `t.bg`
- `bg-surface-container-lowest` → `t.surface`
- `bg-surface-container-low` / `bg-surface-container` → `t.surfaceHover`
- `bg-surface-container-high` → `t.surfaceHigh`
- `text-on-surface` / `text-on-background` → `t.text`
- `text-on-surface-variant` → `t.textMute`
- `border-outline-variant` → `t.border`
- `text-primary` / `bg-primary` → `t.accent`
- `bg-primary-container` → `t.primaryContainer`
- `bg-tertiary-fixed` (在线点) → `t.tertiaryFixed`
- `text-tertiary` → `t.accentCool`
- `text-error` / `bg-error` → `t.danger`
- `bg-secondary-container` → `t.secondaryContainer`
- 灰圆角分组容器：`surface` 底 + `border.withValues(alpha:0.3)` 描边 + `12` 圆角
- 头部：用 `GlassHeader.detail(...)` 或 `.primary(...)`

## 字号速查（index.html → AppTheme.sans）
- `font-display-lg-mobile` (28 w700) → `AppTheme.sans(size:28, weight:FontWeight.w700)`
- `font-headline-md` (24 w600) → `AppTheme.sans(size:24, weight:FontWeight.w600)`
- `font-headline-sm` (20 w600) → `AppTheme.sans(size:20, weight:FontWeight.w600)`
- `font-body-lg` (17 w400) → `AppTheme.sans(size:17)`
- `font-body-sm` (15 w400) → `AppTheme.sans(size:15)`
- `font-label-md` (13 w500) → `AppTheme.sans(size:13, weight:FontWeight.w500)`
- `font-label-sm` (11 w400) → `AppTheme.sans(size:11)`

## 间距/圆角速查
- `px-margin-horizontal` = 16
- `rounded-xl` = 12
- `rounded-2xl` = 16
- `rounded-full` = 9999
- 头像直径：会话列表 48，header 36，profile 96

## 重写指南
- 保留 page 既有的 Riverpod / Matrix client / Provider 调用（如果是 ConsumerWidget，不要降级成 StatelessWidget）
- 保留 page 既有的功能逻辑（发消息、API 调用等），**只重写 widget 树**
- 没有真实数据的 placeholder：写死 mock 文本/头像首字母占位
- 不要管 mock_data.dart 内容，直接读 index.html 的硬编码

## 提交要求
- 写完后**自己用 Grep 验证不留 `Color(0xFF` 硬编码**（少数渐变可以保留）
- **不要**改 `core/`、`widgets/m3/`、`data/`、`router/`、`providers/` —— 只改自己那个 page 文件
- 报告："完成 X_page.dart 的复刻，主要做了 ABCD"，再列举遗留疑问

## 设计文件路径
- index.html: `C:\Users\13185\my-project\P2P-APP-UI\index.html`
- pages 目录: `C:\Users\13185\my-project\p2p-matrix-client\lib\presentation\pages\`
- 主题: `C:\Users\13185\my-project\p2p-matrix-client\lib\core\theme\design_tokens.dart` + `app_theme.dart`
- M3 widgets: `C:\Users\13185\my-project\p2p-matrix-client\lib\presentation\widgets\m3\`
