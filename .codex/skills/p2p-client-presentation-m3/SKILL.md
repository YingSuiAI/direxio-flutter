---
name: p2p-client-presentation-m3
description: Material 3 UI workflow for the Flutter P2P client. Use when editing lib/presentation pages, widgets, providers that drive visible UI state, local M3 components, empty states, headers, chat rendering, navigation UI, or visual polish.
---

# P2P Client M3 UI

## Required Reads

Before editing `lib/presentation/`, read:

- `AGENTS.md`
- `lib/presentation/CLAUDE.md`
- `docs/FEATURES.md` if the visible behavior or feature status changes

Load `p2p-client-channel-work` for channel UI, and `p2p-client-auth-session` for login/restore/session UI.

## UI Rules

Use Material 3 conventions from the local design system.

Use `context.tk` color tokens from `core/theme/design_tokens.dart`. Do not hardcode new colors or hex values.

Use `AppTheme.sans(...)` for text. Do not introduce new hardcoded font families or arbitrary font sizes.

Use `material_symbols_icons` through `Symbols.*`. Do not reintroduce `flutter_lucide`.

Prefer existing components in `lib/presentation/widgets/m3/`, including `GlassHeader`, `GlassHeaderButton`, `M3BottomNav`, `M3Card`, `M3PrimaryButton`, `M3InputField`, `PortalAvatar`, `OnlineDot`, and `AgentMessageBody`.

`GlassHeader` is not a `PreferredSizeWidget`. Place it at the top of the body instead of using `Scaffold.appBar`.

For logged-in empty states, show real empty states. Do not display demo contacts, channels, messages, or posts after login.

## State And Boundaries

Keep Riverpod state in `lib/presentation/providers/`.

Keep reusable UI/data adapters outside route pages when shared or testable.

Keep local UI-only state in a provider/store with a clear name, not in AS models.

Use Matrix SDK and AS providers as the sources of logged-in data. Mock data is only for unauthenticated demos, explicit tests, or temporary scaffolding.

The logged-in home conversation list must render a local conversation snapshot
while ProductCore conversations are still loading and Matrix rooms hydrate after
app restart. Once ProductCore conversations resolve, ProductCore is the
conversation truth: prune cached-only rooms, and use the snapshot only to fill
same-room preview, avatar, and unread fields during Matrix hydration. Do not
show stale cached conversations that ProductCore no longer returns.

Logged-in conversation entry points must open chats from ProductCore
conversations. Use the ProductCore `conversation_id` plus `matrix_room_id` to
build routes, and map route type from ProductCore `kind`; do not let contact
detail, home rows, group lists, or channel conversation routes infer direct vs
group from raw Matrix rooms or bootstrap-only metadata.

Exited or removed group conversations remain visible in the home conversation
list and Contacts -> Groups as read-only history. They must still open the
group chat route, where the composer is replaced by the exited-group send block.
Do not treat `left`, `removed`, `kicked`, or `banned` like pending/invite group
states that should be hidden from the user's existing chat history.

The logged-in home conversation list must show the Agent conversation first by
default, ahead of pinned and recent normal conversations. Once live
ProductCore/Matrix conversation entries are available, use that merged live
projection for display instead of waiting for the local summary snapshot to be
reloaded.

User operation buttons and tap targets are covered by the root
`UserActionDebounce` 500ms pointer debounce. Keep new app entry builders wrapped
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
