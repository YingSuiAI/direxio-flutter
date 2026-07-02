# UI 开发规范（presentation 层）

> 改动 `lib/presentation/` 下任何 UI 代码前，必须先读本文件并遵守。
> 设计基准：Agent P2P 设计稿（Material 3 浅色体系）。

## 1. 总原则

- **不要硬编码颜色**。所有颜色走 `context.tk.xxx`（`PortalTokens`）。需要新色先在 `core/theme/design_tokens.dart` 加 token。设计稿要求的固定配色（如通话页深色背景）行尾标 `// theme-fixed`，`check-ui.sh` 据此白名单放行。
- **不要硬编码字号 / 字体**。文字统一走 `AppTheme.sans(...)`。
- **图标只用 `material_symbols_icons` 的 `Symbols.*`**。`flutter_lucide` 已从依赖移除，禁止再引入。
- 复用已有 M3 组件（见 §5），不要重复造头部 / 卡片 / 按钮 / 底栏。

## 2. 配色 token（`context.tk`）

通过 `import '../../core/theme/design_tokens.dart';` 后用 `context.tk`。

| token | 含义 | 浅色值 |
|---|---|---|
| `bg` | 页面背景 | `#F9F9FE` |
| `surface` | 卡片 / 容器底 | `#FFFFFF` |
| `surfaceHover` | 次级容器（输入框底等） | `#EDEDF2` |
| `surfaceHigh` | 对方气泡背景 / 表头 | `#E8E8ED` |
| `border` | 描边 / 分隔线 | `#C1C6D7` |
| `text` | 主文字 | `#1A1C1F` |
| `textMute` | 次要文字 / 图标 | `#414755` |
| `accent` | 主色（按钮 / 强调 / 选中） | `#3DCFFF` |
| `onAccent` | accent 上的文字 | `#FFFFFF` |
| `accentCool` | 辅助强调（链接 / 加密标识） | `#006B27` |
| `danger` | 错误 / 危险操作 | `#BA1A1A` |
| `primaryContainer` | 容器强调底（头像 / Agent 气泡） | `#0070EB` |
| `onPrimaryContainer` | primaryContainer 上的文字 | `#FEFCFF` |
| `secondaryContainer` | 底栏 pill 等 | `#E0DFE4` |
| `tertiaryFixed` | 在线状态绿点 | `#72FE88` |
| `agentChatBackground` | Agent 会话浅蓝消息区 | `#F5FAFF` |
| `agentSettingsBackground` | Agent 设置页背景 | `#F9F9F9` |
| `agentHeaderText` | Agent 头部黑色文字 / 图标 | `#000000` |
| `agentContentText` | Agent 卡片主文字 / 图标 | `#333333` |
| `agentMutedText` | Agent 卡片次要文字 / chevron | `#999999` |
| `agentStatusText` | Agent 离线状态文字 / 圆点 | `#9DA3AE` |
| `agentComposerSurface` | Agent 输入框底色 | `#EFF1F3` |

深色值见 `design_tokens.dart`，**用 token 名即可，不要写死十六进制**。

## 3. 字体与字阶

- 字体：**Noto Sans SC**（思源黑体），由 `AppTheme` 全局配好，中英文一致。
- 生成文字样式只用 `AppTheme.sans(size:, color:, weight:)`。`AppTheme.mono` 是历史遗留别名，等同 sans，新代码统一用 `sans`。

字号严格对齐设计稿字阶，**不要随意取值**：

| 场景 | size | weight |
|---|---|---|
| 登录页大标题 | 28 | w700 |
| 顶部主标题（消息 / 联系人…） | 24 | w600 |
| 会话名 / 子页 header 标题 | 20 | w600 |
| 消息气泡 / 输入框 / 列表项主文字 | 17 | w400 / w500 |
| 最后消息预览 / 副标题 / 按钮 | 15 | w400 |
| 时间戳 / 文件名 / 次要标签 | 13 | w400 / w500 |
| 在线状态 / AI badge / 未读数字 | 11 | w400 / w700 |

## 4. 间距 / 圆角

- 圆角：卡片 / 大容器 `16`，输入框 / 按钮 / 中等容器 `12`，小标签 `4`，胶囊 / 头像 `9999`（全圆）。
- 页面水平内边距：`16`。
- 列表项：左右 `16`，行间用底部 `1px` 分隔线（`surfaceHigh` 色），不要用卡片间距。
- 头像尺寸：会话/联系人列表 `48`，header `36`，小处 `28~32`，登录 app icon `112`。

## 5. 复用 M3 组件（`widgets/m3/`）

| 组件 | 用途 |
|---|---|
| `GlassHeader.primary` | 一级页头部（左 leading + 标题 + 右 actions），毛玻璃 |
| `GlassHeader.detail` | 子页头部（返回 + 居中标题/副标题 + actions） |
| `GlassHeaderButton` | 头部圆形图标按钮 |
| `M3BottomNav` / `M3NavItem` | 底部导航（滑动 pill 指示器） |
| `M3Card` | M3 卡片（细边 + 16 圆角 + 轻阴影） |
| `M3PrimaryButton` | 主按钮（accent 实心） |
| `M3InputField` | 图标 + 输入框组合 |
| `PortalAvatar` | 头像（默认圆形，`shape: AvatarShape.squircle` 可选） |
| `OnlineDot` | 在线状态绿点 |
| `AgentMessageBody` | Agent 消息 Markdown 渲染（表格已 M3 化） |

### 重要约束

- **`GlassHeader` 不是 `PreferredSizeWidget`**，不要当 `Scaffold.appBar`。放进 `body` 的 `Column` 顶部，它内部自取状态栏高度。Scaffold 不设 `appBar`。
- 毛玻璃效果用 `BackdropFilter` + 半透明背景，已封装在 `GlassHeader` / `M3BottomNav` 里，不要自己再写一套。

## 6. 聊天气泡规范

- 对方气泡：`surfaceHigh` 底，圆角 `topL/topR/bottomR=16, bottomL=4`，左侧带 28 头像。
- 自己气泡：`accent` 底，`onAccent` 文字，圆角 `topL/topR/bottomL=16, bottomR=4`，无头像。
- 气泡内文字 size 17；时间戳在气泡下方，size 11，`textMute`。

## 7. 提交前自检

- [ ] 没有硬编码颜色 / 字号 / 十六进制
- [ ] 图标用 `Symbols.*`
- [ ] 复用了 M3 组件而非重造
- [ ] `flutter build web --release` 通过
- [ ] 若新增页面，与设计稿对照过布局
