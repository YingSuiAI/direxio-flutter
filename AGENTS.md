# AGENTS.md - Direxio Flutter P2P Client

This repository is the Flutter client for Direxio P2P IM. This file is the authoritative repo-wide instruction file for agents. The root `CLAUDE.md` is only a legacy pointer for tools that still read that filename.

Treat these rules as current-state product and engineering instructions, not as a compatibility guide. Prefer the clean current implementation over legacy-safe shims unless the user explicitly asks for backward compatibility.

## Product Invariants

The product rule is: one person, one node, one owner. Agent/service accounts may appear as system conversations, but they are not normal human contacts.

Current membership roles are intentionally limited to `owner` and `member`.
Do not add third management roles, role constants, role labels, permission
branches, or compatibility mappings outside that two-role model.

## Operating Order

- Read this file before making changes, then read any directory-specific instruction file that applies.
- Check the current worktree with `git status --short --branch` and preserve unrelated user or generated changes.
- Classify the task before editing: UI, P2P Product API contract, signed IM/BI public API, channel workflow, auth/session, platform/build, docs-only, or mixed.
- When product behavior is unclear or Flutter docs conflict with backend facts, check `C:\Users\84960\Desktop\direxio\direxio-message-server` and treat that backend project as authoritative. Start with its `AGENTS.md`, `docs/current-project-documentation.md`, and the relevant `p2p/service_*.go`, `p2p/action_registry.go`, or `internal/productpolicy` code.
- If a change touches `lib/presentation/`, read `lib/presentation/CLAUDE.md` first and follow its Material 3 rules.
- Do not add new repo-wide rules to `CLAUDE.md`; update `AGENTS.md`.
- Check `docs/FEATURES.md` before changing user-visible behavior, and update it when a feature moves between partial, local, or real status.
- Check `docs/P2P_API_BOUNDARY.md` before changing P2P product API contracts, and update it in the same change.
- If business behavior is ambiguous, state the assumption, explain the impact, and choose the smallest concrete behavior that matches the current product model.

## Project-local Codex Skills

Project-local Codex skills live under `.codex/skills/`. Use `p2p-client-guardrails` as the entry skill for repo work, then load the focused skill that matches the classified task:

- `p2p-client-as-contract`: P2P product API contracts, models, parsing, docs, and tests.
- `p2p-client-channel-work`: channel search, join, approval, inbox, detail, share, posts, and chat send gating.
- `p2p-client-presentation-m3`: `lib/presentation/` UI, widgets, providers, empty states, and Material 3 rules.
- `p2p-client-auth-session`: login, setup, restore, route guards, credential storage, and token/session behavior.
- `p2p-client-release-build`: APK/iOS/web release builds and artifact packaging.

When business rules, API contracts, UI rules, workflow expectations, or verification requirements change, update the corresponding `.codex/skills/*/SKILL.md` in the same change so future agents receive the current rules.

## Project Layout

```text
lib/
├── core/
│   ├── router/        go_router routes and route guards
│   └── theme/         design_tokens.dart + app_theme.dart
├── data/              P2P/Matrix boundary and local stores
└── presentation/
    ├── pages/         route pages
    ├── channel/       channel inbox, share, and create/review flows
    ├── chat/          shared chat/media/record rendering helpers
    ├── widgets/       reusable widgets; widgets/m3/ is the local M3 library
    └── providers/     Riverpod providers and local state adapters
```

## Data Boundaries

Choose the integration boundary before adding or changing client behavior:

1. Use Matrix SDK or Matrix Client-Server APIs for Matrix-native behavior: login session, rooms, timeline, membership, media, profile avatar/display name, read markers, Matrix message state, ordinary sends, history, unread, message search, and recall.
2. Use the integrated P2P Product API for product-layer data Matrix does not model cleanly: setup/bootstrap, access-token auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, ProductCore conversations, and channel/public product search.
3. Use signed IM/BI public endpoints for `/im/*` and `/bi/*` calls that require `X-BI-Nonce` and `X-BI-Signature`; this boundary is separate from P2P Product API actions.

- Backend auth responses expose one `access_token`. P2P product API calls use it as bearer auth, and Matrix SDK/Matrix API behavior uses the same token. Do not add separate product or Matrix token fields.
- Foreground/background push context is Matrix-native account data. Logged-in clients write global account data type `io.direxio.push.context`: `resumed` writes `{"foreground": true}` immediately and every 30 seconds; every other lifecycle state writes `{"foreground": false}` and stops the heartbeat. The server stamps foreground writes with a server-clock 60-second expiry. Do not model this as a P2P action, pusher data field, or `/sync` heuristic.
- Product API calls go through `/_p2p/query` or `/_p2p/command` with an `action` and `params` envelope. Do not add new URL-shaped client contracts unless the backend does.
- Current public P2P Product API actions are `portal.bootstrap`, `portal.auth`, `portal.status`, `contacts.reactivate`, `channels.public.search`, `channels.public.get`, `channels.public.join_request`, `channels.public.join_result`, and `users.public_channels`. `channels.public.join_result` is an internal node-to-node callback, not a normal client workflow entry.
- Do not create duplicate list APIs or duplicate client flows. If data already arrives through `sync.bootstrap`, prefer extending that action contract and the client model.
- ProductCore conversations are the openable conversation source. Do not reconstruct chat routes from names, member counts, local placeholder ids, or bootstrap-only metadata when ProductCore denies or omits an openable conversation.
- Runtime views must prefer real Matrix/P2P data. Placeholder fixture data is not allowed in production UI.
- Do not silently fall back to fixture data. A real empty state is better than fake data.

## Current P2P Product Contract Rules

- `sync.bootstrap` is metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields to bootstrap.
- Use `sync.bootstrap` only as a baseline for cold start, login recovery, corrupt local cache, unknown event fallback, or confirmed event gaps. Normal changes should persist the last handled SSE `seq` and apply typed local reducers from `GET /_p2p/events?since=<last_seq>` instead of refreshing full bootstrap snapshots.
- If `GET /_p2p/events` signals `p2p.cursor_reset`, clear local product projections, run one `sync.bootstrap`, persist the newest handled event `seq`, and resume delta consumption.
- P2P ordinary message/search/backup actions are removed, not compatibility entries: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.
- `portal.setup` is removed. First-time setup must use `portal.status` / `portal.auth`, then password/profile update flows.
- `portal.bootstrap`, `portal.auth`, and `portal.password` create a new exclusive Matrix device session for the portal owner. Old owner devices should receive `M_UNKNOWN_TOKEN`; `agent.matrix_session.create` is the exception and must not evict the user's phone/browser session.
- Ordinary message send, media send, history, unread, message search, and recall use Matrix Client-Server APIs.
- Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomID}/local_delete` with either `event_ids` or `clear`, never both. It hides only the current user's local Matrix read path and is not a redaction.
- Group invites are surfaced to receivers as Matrix room invites and may also appear in `sync.bootstrap.pending.group_invites`; do not treat the receiver contract as a private-chat invite message.
- Public remote channel lookup must pass the request-provided `remote_node_base_url` required by the backend. Do not infer a remote P2P URL from a Matrix `room_id` domain.
- Agent chat header display is Matrix-native room state: read `io.direxio.agent.status` from the real `agent_room_id`. Do not read or add `sync.bootstrap.agent_online` or `agent.presence` SSE reducers. The owner-facing Agent chat status text is limited to localized online/offline labels: `commonOnline` when `online` is true and `commonOffline` otherwise; do not show unknown, connecting, or error status labels in the chat header.
- Channel member status must be normalized through `AsChannel` / `AsChannelMember` helpers:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `approved` -> `approved`
  - `joining` -> `joining`
  - `join_failed` -> `join_failed`
  - `reject`, `rejected` -> `rejected`
- Treat only `isAsChannelMemberJoined(status)` as joined. `invite`, `pending`, `approved`, and `joining` are waiting states and must not unlock channel sending; `join_failed` and `rejected` are not joined states.
- Channel join-request review actions return top-level statuses such as `approved`, `joining`, `joined`, and `join_failed`; approving a request must not be treated as joined unless the returned status is `joined`.
- Channel list entries with terminal lifecycle such as `deleted`, `left`, `dissolve`, or `dissolved` must be hidden even if stale membership still says `joined`.
- `portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`. `initialized` means the generated initial password has been changed; owner profile completion is not part of initialization.
- Channel share cards must include `channel_id` and `room_id` and must not include invite-grant fields. Sharing a channel is a recommendation card for both owners and ordinary members; receivers open the public channel detail by Matrix `room_id` and apply through `channels.public.join_request`. Direct invite grants are reserved for the owner member-list `+` invite flow, not the share button.
- When the product API contract changes, update `AsClient`, `HttpAsClient`, test doubles under `test/support/`, focused tests, and `docs/P2P_API_BOUNDARY.md` together.
- User-facing reports use the imadmin signed public API, not Direxio Message Server ProductCore. Call signed `POST /im/report` through the IM public client; use target type `1` for friends, `2` for group chats, and `3` for channels; upload evidence images as repeated multipart `files`. Do not wire report UI to P2P `reports.submit`.
- Public channel directory search/register/close uses signed `/im/channel/list`, `/im/channel/join`, and `/im/channel/close`. Only Matrix room-id channel search stays on the existing P2P room-id lookup path.

## Architecture

- State management is Riverpod 2 with `riverpod_annotation` where generated providers are used.
- Keep API abstractions in `lib/data/`: `AsClient` defines contracts and `HttpAsClient` implements real HTTP. Test doubles stay under `test/support/` or inside test files.
- New backend capabilities should follow the same interface + implementation injection pattern.
- Keep Riverpod state in `lib/presentation/providers/`.
- Keep reusable UI/data adapters outside route pages when shared or testable, for example `lib/presentation/channel/channel_inbox_data.dart`.
- Local UI-only state belongs in a provider/store with a clear name, not in P2P API models.

## UI Rules

- Follow `lib/presentation/CLAUDE.md`: Material 3, `context.tk` color tokens, `AppTheme.sans` typography, `Symbols.*` icons, and `widgets/m3/` components.
- Do not hardcode new colors, font sizes, font families, or hex values in UI code.
- Do not reintroduce `flutter_lucide`; icons come from `material_symbols_icons` via `Symbols.*`.
- `GlassHeader` is not a `PreferredSizeWidget`; place it at the top of the body rather than in `Scaffold.appBar`.
- For empty states, show the real empty state. Do not show placeholder contacts/channels/messages.

## Privacy Rules

- New-device bootstrap must not load historical read message bodies.
- Unread and message history come from Matrix `/sync` and `/rooms/{roomID}/messages`, not P2P bootstrap or P2P action facades.
- Local clear/delete/hide actions must not imply server deletion unless the P2P/Matrix API call actually deletes server state.

## Channel Rules

- Product room classification comes from native Direxio Matrix state (`m.room.create.content.type`, `io.direxio.room.profile`) and P2P Product API metadata. Do not add new code that depends on legacy `p2p.room.kind`; when touching an existing fallback, keep new behavior driven by the native profile/Product API source.
- Channel list uses `AsSyncBootstrap.channels` as the primary logged-in source. Do not add a duplicate list endpoint without updating interface docs and tests.
- `channels.create` creates a channel through the P2P product API, but owner semantics belong to the portal owner, not the Agent/bot.
- Search, channel tab, channel detail, and channel chat must use the same channel identity source when logged in.
- Channel conversations belong to the channel surfaces and must not appear in the home message list or home conversation summary cache.
- Approval/invite does not mean joined. Wait for Matrix join projection before enabling chat send.

## Testing And Verification

Run focused checks for touched files:

```sh
flutter analyze --no-pub
flutter test --no-pub <relevant tests>
```

For low-noise local iteration, prefer `scripts/local_verify.sh`. It runs test
commands serially, checks the required generated files, removes `flutter_*.log`
crash logs, and reports iOS project-file churn from simulator builds. If
`lib/core/router/app_router.g.dart` or
`lib/presentation/providers/auth_provider.g.dart` is missing, regenerate with:

```sh
dart run build_runner build --delete-conflicting-outputs
```

For channel/search work, at minimum run:

```sh
flutter test --no-pub test/channel_page_real_test.dart test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test --no-pub test/widget_test.dart --plain-name channel
flutter test --no-pub test/widget_test.dart --plain-name 'global search'
```

For auth/session changes, run the auth/provider tests and at least one login or restore widget path.

For platform/build changes, run the relevant target build, for example `flutter build ios --simulator` or a web release build when the change targets web.

Before claiming completion, run `flutter analyze --no-pub` and the broadest practical test set. If a test cannot be run, document why.

## Code Style

- Keep changes scoped to the requested behavior and local architecture.
- Keep source files under 3000 lines. When touching an oversized file, prefer extracting focused widgets, controllers, helpers, or tests into smaller files as part of the change instead of adding more code to the oversized file.
- Do not leave dead code, duplicate shims, or unused fixture-data paths.
- Add comments only when the reason is not obvious.
- Add dependencies only after confirming existing dependencies cannot reasonably solve the problem.
- Do not edit generated files by hand unless the repo already tracks generated outputs and the matching source file is updated in the same change.
