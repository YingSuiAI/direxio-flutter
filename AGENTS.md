# AGENTS.md - p2p-client

This repository is the Flutter client for P2P IM. This file is the authoritative repo-wide instruction file for agents. The root `CLAUDE.md` is only a legacy pointer for tools that still read that filename.

The product rule is: one person, one node, one owner. Agent/service accounts may appear as system conversations, but they are not normal human contacts.

## Before Editing

- If a change touches `lib/presentation/`, read `lib/presentation/CLAUDE.md` first and follow its Material 3 rules.
- For directories without a more specific instruction file, follow this file.
- Do not add new repo-wide rules to `CLAUDE.md`; update `AGENTS.md`.
- Check `docs/FEATURES.md` before changing user-visible behavior, and update it when a feature moves between demo, partial, local, or real status.
- Check `docs/AS_API_CHANGES.md` before changing AS/Admin API contracts, and update it in the same change.

## Project Layout

```text
lib/
├── core/
│   ├── router/        go_router routes and route guards
│   └── theme/         design_tokens.dart + app_theme.dart
├── data/              AS/Matrix boundary and local stores
└── presentation/
    ├── pages/         route pages
    ├── channel/       channel inbox, share, and create/review flows
    ├── chat/          shared chat/media/record rendering helpers
    ├── widgets/       reusable widgets; widgets/m3/ is the local M3 library
    ├── providers/     Riverpod providers and local state adapters
    └── mock/          unauthenticated demo and explicit test data
```

## Data Boundaries

- Use Matrix SDK for Matrix-native behavior: login session, rooms, timeline, membership, media, profile avatar/display name, read markers, and Matrix message state.
- Use AS Admin API for product-layer data Matrix does not model cleanly: setup/bootstrap, portal token auth, unread recovery overlay, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and product search.
- AS Admin API calls use the portal token as bearer auth. Matrix access tokens are for Matrix SDK/Matrix API behavior. Do not conflate the two token types.
- Do not create duplicate list APIs or duplicate client flows. If data already arrives through `/_as/sync/bootstrap`, prefer extending that contract and the client model.
- Logged-in views must prefer real Matrix/AS data. Mock data is allowed only for unauthenticated demos, explicit tests, or temporary UI scaffolding.
- Do not silently fall back to mock after login. A real empty state is better than fake data.

## Current AS Contract Rules

- `/_as/sync/bootstrap` is metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields to bootstrap.
- Public remote channel lookup must use explicitly configured AS remotes. Do not infer a remote AS URL from a Matrix `room_id` domain.
- Channel member status must be normalized through `AsChannel` / `AsChannelMember` helpers:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `reject`, `rejected` -> `rejected`
- Treat only `isAsChannelMemberJoined(status)` as joined. `invite` and `pending` are waiting states and must not unlock channel sending.
- `portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`.
- When the AS contract changes, update `AsClient`, `HttpAsClient`, `MockAsClient`, focused tests, and `docs/AS_API_CHANGES.md` together.

## Architecture

- State management is Riverpod 2 with `riverpod_annotation` where generated providers are used.
- Keep API abstractions in `lib/data/`: `AsClient` defines contracts, `HttpAsClient` implements real HTTP, and `MockAsClient` stays demo/test-only.
- New backend capabilities should follow the same interface + implementation injection pattern.
- Keep Riverpod state in `lib/presentation/providers/`.
- Keep reusable UI/data adapters outside route pages when shared or testable, for example `lib/presentation/channel/channel_inbox_data.dart`.
- Local UI-only state belongs in a provider/store with a clear name, not in AS models.

## UI Rules

- Follow `lib/presentation/CLAUDE.md`: Material 3, `context.tk` color tokens, `AppTheme.sans` typography, `Symbols.*` icons, and `widgets/m3/` components.
- Do not hardcode new colors, font sizes, font families, or hex values in UI code.
- Do not reintroduce `flutter_lucide`; icons come from `material_symbols_icons` via `Symbols.*`.
- `GlassHeader` is not a `PreferredSizeWidget`; place it at the top of the body rather than in `Scaffold.appBar`.
- For logged-in empty states, show the real empty state. Do not show demo contacts/channels/messages.

## Privacy Rules

- New-device bootstrap must not load historical read message bodies.
- Recovered unread is an overlay, not canonical history. Merge by stable `event_id` and never render duplicates.
- Do not write recovered unread into Matrix SDK persistent timeline unless a separate privacy design explicitly approves it.
- Local clear/delete/hide actions must not imply server deletion unless the AS/Matrix API call actually deletes server state.

## Channel Rules

- A channel is a Matrix room marked by `p2p.room.kind = {"kind":"channel"}`.
- Channel list uses `AsSyncBootstrap.channels` as the primary logged-in source. Do not add a duplicate list endpoint without updating interface docs and tests.
- `POST /_as/channels` creates a channel through AS, but owner semantics belong to the portal owner, not the Agent/bot.
- Search, channel tab, channel detail, and channel chat must use the same channel identity source when logged in.
- Approval/invite does not mean joined. Wait for Matrix join projection before enabling chat send.

## Testing And Verification

Run focused checks for touched files:

```sh
flutter analyze --no-pub
flutter test --no-pub <relevant tests>
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
- Do not leave dead code, duplicate shims, or unused mock paths.
- Add comments only when the reason is not obvious.
- Add dependencies only after confirming existing dependencies cannot reasonably solve the problem.
- Do not edit generated files by hand unless the repo already tracks generated outputs and the matching source file is updated in the same change.

