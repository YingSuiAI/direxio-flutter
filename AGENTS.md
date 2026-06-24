# AGENTS.md - p2p-client

This repository is the Flutter client for P2P IM. This file is the authoritative repo-wide instruction file for agents. The root `CLAUDE.md` is only a legacy pointer for tools that still read that filename.

The product rule is: one person, one node, one owner. Agent/service accounts may appear as system conversations, but they are not normal human contacts.

## Before Editing

- If a change touches `lib/presentation/`, read `lib/presentation/CLAUDE.md` first and follow its Material 3 rules.
- For directories without a more specific instruction file, follow this file.
- Do not add new repo-wide rules to `CLAUDE.md`; update `AGENTS.md`.
- Check `docs/FEATURES.md` before changing user-visible behavior, and update it when a feature moves between partial, local, or real status.
- Check `docs/P2P_API_BOUNDARY.md` before changing P2P product API contracts, and update it in the same change.

## Project-local Codex Skills

Project-local Codex skills live under `.codex/skills/`. Use `p2p-client-guardrails` as the entry skill, then use the focused skill that matches the task:

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

- Use Matrix SDK for Matrix-native behavior: login session, rooms, timeline, membership, media, profile avatar/display name, read markers, and Matrix message state.
- Use the integrated P2P product API for product-layer data Matrix does not model cleanly: setup/bootstrap, portal token auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and channel/public product search.
- P2P product API calls use the portal token as bearer auth. Matrix access tokens are for Matrix SDK/Matrix API behavior. Do not conflate the two token types.
- Product API calls go through `/_p2p/query` or `/_p2p/command` with an `action` and `params` envelope. Do not add new URL-shaped client contracts unless the backend does.
- Do not create duplicate list APIs or duplicate client flows. If data already arrives through `sync.bootstrap`, prefer extending that action contract and the client model.
- Runtime views must prefer real Matrix/P2P data. Placeholder fixture data is not allowed in production UI.
- Do not silently fall back to fixture data. A real empty state is better than fake data.

## Current P2P Product Contract Rules

- `sync.bootstrap` is metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields to bootstrap.
- P2P ordinary message/search/backup actions are removed, not compatibility entries: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.
- `portal.setup` is removed. First-time setup must use `portal.status` / `portal.auth`, then password/profile update flows.
- Ordinary message send, media send, history, unread, message search, and recall use Matrix Client-Server APIs.
- Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomID}/local_delete` with either `event_ids` or `clear`, never both. It hides only the current user's local Matrix read path and is not a redaction.
- Public remote channel lookup must pass the request-provided `remote_node_base_url` required by the backend. Do not infer a remote P2P URL from a Matrix `room_id` domain.
- Channel member status must be normalized through `AsChannel` / `AsChannelMember` helpers:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `reject`, `rejected` -> `rejected`
- Treat only `isAsChannelMemberJoined(status)` as joined. `invite` and `pending` are waiting states and must not unlock channel sending.
- Channel join-request review actions return top-level statuses such as `approved`, `joining`, `joined`, and `join_failed`; approving a request must not be treated as joined unless the returned status is `joined`.
- Channel list entries with terminal lifecycle such as `deleted`, `left`, `dissolve`, or `dissolved` must be hidden even if stale membership still says `joined`.
- `portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`.
- Channel share cards must include `channel_id` and `room_id`. Owner/admin shares create `channels.invite_grant.create` and send `grant_id` plus `share_room_id` so receivers join through `channels.join`; ordinary member shares do not create invite grants and receivers apply through `channels.public.join_request` using the card Matrix `room_id` while preserving `channel_id` as channel metadata.
- When the product API contract changes, update `AsClient`, `HttpAsClient`, test doubles under `test/support/`, focused tests, and `docs/P2P_API_BOUNDARY.md` together.

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

- Product room classification comes from `io.direxio.room.profile` and P2P product APIs. Do not add new code that depends on legacy `p2p.room.kind`.
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
