---
name: p2p-client-presentation-m3
description: Use when editing Flutter lib/presentation UI, visible providers, Material 3 components, empty states, headers, chat rendering, navigation, route gating, product-state display, or visual polish.
---

# P2P Client M3 UI

## Required Reads

Before editing `lib/presentation/`, read:

- `AGENTS.md`
- `lib/presentation/CLAUDE.md`
- `docs/FEATURES.md` if the visible behavior or feature status changes

If visible product behavior is unclear or conflicts with Flutter docs, verify
against `C:\Users\84960\Desktop\direxio\direxio-message-server` before
choosing UI states or route gates.

Load `p2p-client-channel-work` for channel UI, and `p2p-client-auth-session` for login/restore/session UI.

## UI Rules

Use Material 3 conventions from the local design system.

Use `context.tk` color tokens from `core/theme/design_tokens.dart`. Do not hardcode new colors or hex values.

Use `AppTheme.sans(...)` for text. Do not introduce new hardcoded font families or arbitrary font sizes.

Use `material_symbols_icons` through `Symbols.*`. Do not reintroduce `flutter_lucide`.

Prefer existing components in `lib/presentation/widgets/m3/`, including `GlassHeader`, `GlassHeaderButton`, `M3BottomNav`, `M3Card`, `M3PrimaryButton`, `M3InputField`, `PortalAvatar`, `OnlineDot`, and `AgentMessageBody`.

`GlassHeader` is not a `PreferredSizeWidget`. Place it at the top of the body instead of using `Scaffold.appBar`.

For logged-in empty states, show real empty states. Do not display demo contacts, channels, messages, or posts after login.

Transient user feedback must use the shared top toast in
`lib/presentation/widgets/center_toast.dart`: top centered, Figma toast colors,
and a 2-second display. Do not add bottom `ScaffoldMessenger.showSnackBar`
prompts for ordinary app feedback.

## State And Boundaries

Keep Riverpod state in `lib/presentation/providers/`.

Keep reusable UI/data adapters outside route pages when shared or testable.

Keep local UI-only state in a provider/store with a clear name, not in AS models.

Use Matrix SDK and AS/ProductCore providers as the sources of logged-in data.
Mock data is only for unauthenticated demos, explicit tests, or temporary
scaffolding.

The logged-in home conversation list must render a local conversation snapshot
while ProductCore conversations are still loading and Matrix rooms hydrate after
app restart. Once ProductCore conversations resolve, ProductCore is the
conversation truth: prune cached-only rooms, and use the snapshot only to fill
same-room preview, avatar, and unread fields during Matrix hydration. Do not
show stale cached conversations that ProductCore no longer returns.

Logged-in conversation entry points must open chats from ProductCore
conversations. Use the ProductCore `conversation_id` plus `matrix_room_id` to
build routes, map route type from ProductCore `kind`, and require ProductCore
`capabilities.open`/send-related flags where the code already exposes them. Do
not let contact detail, home rows, group lists, or channel conversation routes
infer direct vs group from raw Matrix rooms, display names, member-count text,
or bootstrap-only metadata.

Exited or removed group conversations remain visible in the home conversation
list and Contacts -> Groups as read-only history. They must still open the
group chat route, where the composer is replaced by the exited-group send block.
Do not treat `left`, `removed`, `kicked`, or `banned` like pending/invite group
states that should be hidden from the user's existing chat history.

Blocked contacts, groups, and channels are hidden from normal conversation,
contacts, group, and channel lists. Ordinary contact/group/channel settings
pages expose only the block action; unblock is available only from Settings ->
Blacklist, where records are grouped by contacts, groups, and channels.

The logged-in home conversation list must show the Agent conversation first by
default, ahead of pinned and recent normal conversations. Once live
ProductCore/Matrix conversation entries are available, use that merged live
projection for display instead of waiting for the local summary snapshot to be
reloaded.

Agent chat headers must show Matrix room-state availability, not Matrix typing
or streaming generation state. Source it from the real agent room
`io.direxio.agent.status` state event located by `sync.bootstrap`
`agent_room_id`; do not consume `agent.presence` SSE for this state. The
owner-facing Agent chat status text is limited to localized online/offline
labels: `commonOnline` when `online` is true and `commonOffline` otherwise; do
not show unknown, connecting, or error labels in the chat header. Agent
Markdown, cards, Matrix edits including SDK-aggregated display events, stream
fragments, typewritten appended reply updates, and `/` quick-command suggestions
belong in the chat UI while actual sends remain ordinary Matrix text sends to
the real `agent_room_id`.

Agent settings belong behind the Agent chat header settings icon. Use the same
M3 surfaces as other detail pages, read/write `agent.config`, and treat
`mcp_blocked_room_ids` as backend-enforced Agent read restrictions rather than
local-only MCP permission UI.

The logged-in home conversation list is for direct, group, and Agent
conversations. Channel conversations belong under the channel tab/detail
surfaces and must not be written to or displayed from the home conversation
summary cache.

For product event streams, use local reducers from `GET /_p2p/events` for known
events. If the event stream signals `p2p.cursor_reset`, clear product UI caches,
run one `sync.bootstrap`, then continue from the newest event `seq`.

User operation buttons and tap targets are covered by the root
`UserActionDebounce` 200ms pointer debounce. Keep new app entry builders wrapped
by it instead of adding one-off duplicate request guards to individual buttons.

## Verification

Run:

```powershell
flutter analyze --no-pub
flutter test --no-pub <relevant widget/provider tests>
```

For channel/search UI, also run:

```powershell
flutter test --no-pub test/widget_test.dart --plain-name channel
flutter test --no-pub test/widget_test.dart --plain-name 'global search'
```

For broad visual or platform-sensitive UI work, run the relevant build, such as:

```powershell
flutter build web --release
```
