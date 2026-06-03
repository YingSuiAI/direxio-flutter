# AGENTS.md - p2p-matrix-client

This repository is the Flutter client for P2P IM. AGENTS.md is the authoritative repo-wide agent instruction file. The root `CLAUDE.md` is kept only as a legacy pointer for tools that still read that filename.

Keep changes aligned with the product rule: one person, one node, one owner. Agent/service accounts can appear as system conversations, but they are not normal human contacts.

## Before Editing

- If a change touches `lib/presentation/`, read `lib/presentation/CLAUDE.md` first and follow its Material 3 UI rules.
- For directories without a more specific instruction file, follow this AGENTS.md.
- Do not add new repo-wide rules to `CLAUDE.md`; update this file instead.

## Project Structure

```text
lib/
├── core/
│   ├── router/        go_router routes
│   └── theme/         design_tokens.dart + app_theme.dart
├── data/              backend interface layer: well_known_service / as_client / http_as_client / mock_as_client
└── presentation/
    ├── pages/         route pages
    ├── widgets/       reusable widgets; widgets/m3/ is the local M3 component library
    ├── providers/     Riverpod providers
    └── mock/          mock data / mock MCP client / permission and audit stores
```

## Core Boundaries

- Use Matrix SDK for Matrix-native behavior: login session, rooms, timeline, media, profile avatar/display name, read markers, membership, and sending messages.
- Use AS Admin API only for product-layer data Matrix does not model cleanly: setup/bootstrap, portal token auth, unread recovery overlay, follows, channel metadata, public profile extensions, and Agent/MCP state.
- AS Admin API calls use the portal token as bearer auth. Matrix access tokens are for Matrix SDK/Matrix API behavior; do not conflate the two token types.
- Do not create duplicate APIs or duplicate client flows. If data already arrives through `/_as/sync/bootstrap`, prefer extending that contract instead of adding another list endpoint.
- Logged-in views must prefer real Matrix/AS data. Mock data is allowed only for unauthenticated demos, explicit tests, or temporary UI scaffolding.
- Do not silently fall back to mock after login; a real empty state is better than fake data.

## Architecture

- State management is Riverpod 2 with riverpod_annotation.
- Keep API abstractions in `lib/data/`: `AsClient` defines contracts, `HttpAsClient` implements real HTTP, `MockAsClient` stays test/demo only.
- New external/backend capabilities should follow the same interface + implementation injection pattern.
- Keep Riverpod state in `lib/presentation/providers/`.
- Keep reusable UI/data adapters outside pages when they are shared or testable, for example `lib/presentation/channel/channel_inbox_data.dart`.

## UI Rules

- Follow `lib/presentation/CLAUDE.md`: Material 3 design, `context.tk` color tokens, `AppTheme.sans` typography, `Symbols.*` icons, and reuse of `widgets/m3/` components.
- Do not hardcode colors, font sizes, font families, or hex values in UI code.
- Do not reintroduce `flutter_lucide`; icons should come from `material_symbols_icons` via `Symbols.*`.
- `GlassHeader` is not a `PreferredSizeWidget`; put it at the top of the page body instead of using it as `Scaffold.appBar`.

## Privacy Rules

- New-device bootstrap must not load historical read message bodies.
- `/_as/sync/bootstrap` is metadata only. It must not introduce `last_message` or historical content fields.
- Recovered unread is an overlay, not canonical history. Merge with Matrix timeline by stable `event_id` and never render duplicates.
- Do not write recovered unread into Matrix SDK persistent timeline unless a separate privacy design explicitly approves it.

## Channel Rules

- A channel is a Matrix room marked by `p2p.room.kind = {"kind":"channel"}`.
- Channel list uses `AsSyncBootstrap.channels` in the first phase. Do not add a duplicate `GET /_as/channels` list API unless the interface docs are updated first.
- `POST /_as/channels` creates a channel through AS, but the channel owner semantics belong to the portal owner, not the Agent/bot.
- Search, channel tab, and channel detail must use the same channel source when logged in.

## Code Style

- Keep changes scoped to the requested behavior and the local architecture.
- Do not leave dead code, duplicate shims, or unused mock paths.
- Write comments only when the reason is not obvious; do not comment what the code already says.
- Add new dependencies only after confirming existing dependencies cannot reasonably solve the problem.

## Verification

Run focused checks for the files you touch:

```sh
flutter analyze <changed dart files>
flutter test <relevant tests>
```

For channel/search work, at minimum run:

```sh
flutter test test/channel_page_real_test.dart test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test test/widget_test.dart --plain-name channel
flutter test test/widget_test.dart --plain-name 'global search'
```

For platform/build changes, run the relevant target build, for example `flutter build ios --simulator` or the web release build when the change targets web.

When an AS contract changes, update the desktop planning docs and the matching AS tests in `p2p-matrix-as`.
