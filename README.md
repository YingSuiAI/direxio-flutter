# Direxio Flutter Client

Direxio is the Flutter client for the Matrix-backed Direxio messenger.

This file describes the current codebase only. Historical design notes and rollout plans are intentionally not kept in this repository because they create ambiguity for human and AI analysis.

## Current Identity

- App display name: `Direxio`
- Flutter package name: `portal_app`
- Android package / application id: `com.direxio.ai`
- Android main activity package: `com.direxio.ai`
- iOS bundle id: `com.direxio.app`
- Default production domain references in UI: `im2.direxio.ai`

The Flutter package name remains `portal_app` because it is the Dart import namespace used by the current tests and source files. Do not treat it as the product name or Android package id.

## Data Boundary

- Matrix SDK owns Matrix-native behavior: login session, rooms, timelines, media, membership, profile avatar/display name, read state, message search, and message send.
- The integrated Direxio P2P product API owns product-layer state: portal bootstrap/auth, contacts, follows, group/channel metadata, channel posts/comments/reactions, Agent/MCP state, and public profile/channel extension data.
- Product API requests go to `/_p2p/query` or `/_p2p/command` with an `action` and `params` body. This matches the current backend in `/Users/niki/de-as`.
- The portal token is for P2P product API auth. Matrix access tokens are for Matrix Client-Server APIs.
- Runtime UI must use real Matrix/P2P data or a real empty state. It must not silently fall back to placeholder fixture data.
- Test doubles belong under `test/support/` or inside tests.

## Important Paths

```text
lib/
├── core/          router and design tokens
├── data/          Matrix/P2P clients, contracts, stores
└── presentation/  pages, widgets, providers, channel/chat UI

android/           Android package, resources, app icon, native helpers
ios/               iOS bundle, launch screen, app icon
docs/              current feature/API facts only
test/              unit and widget tests
```

## Local Verification

Use the local wrapper while iterating. It checks required generated files, removes
Flutter crash logs, and runs `flutter test` commands serially to avoid native
assets manifest races:

```sh
scripts/local_verify.sh
scripts/local_verify.sh -- test/auth_provider_test.dart --plain-name '<case name>'
```

The two generated files needed by local builds are tracked exceptions to the
repo-wide `*.g.dart` ignore rule:

```text
lib/core/router/app_router.g.dart
lib/presentation/providers/auth_provider.g.dart
```

If they are missing, regenerate them before validating:

```sh
dart run build_runner build --delete-conflicting-outputs
```

For the broad pre-finish check, include Flutter analysis:

```sh
scripts/local_verify.sh --flutter-analyze
```

For iOS simulator builds, ask the wrapper to report or restore build-tool-only
project file churn:

```sh
scripts/local_verify.sh --ios-simulator-build --restore-ios-noise --skip-tests
```

Focused checks can still be run directly when needed:

```sh
flutter analyze --no-pub
flutter test --no-pub test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test --no-pub test/widget_test.dart --plain-name channel
```

For Android package/resource changes:

```sh
flutter build apk --debug
```

## Code Quality

- Keep Flutter/Dart source files under 3000 lines. If a touched file is already over that limit, split focused widgets, controllers, helpers, or tests into smaller files instead of growing it further.
- Production UI should use real Matrix/P2P data or real empty states. Mock data belongs in tests, `test/support/`, or clearly unauthenticated demos only.

## Current Docs

- `AGENTS.md`: repository rules for coding agents.
- `lib/presentation/CLAUDE.md`: Material 3 UI rules for presentation-layer edits.
- `docs/FEATURES.md`: current feature implementation status.
- `docs/P2P_API_BOUNDARY.md`: current P2P/Matrix client contract boundary.
