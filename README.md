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
- AS Admin API owns product-layer state: portal bootstrap/auth, contacts, follows, group/channel metadata, channel posts/comments/reactions, Agent/MCP state, and public profile/channel extension data.
- The portal token is for AS Admin API. Matrix access tokens are for Matrix Client-Server APIs.
- Logged-in UI must use real Matrix/AS data. It must not silently fall back to demo data.
- Test doubles belong under `test/support/` or inside tests.

## Important Paths

```text
lib/
├── core/          router and design tokens
├── data/          Matrix/AS clients, contracts, stores
└── presentation/  pages, widgets, providers, channel/chat UI

android/           Android package, resources, app icon, native helpers
ios/               iOS bundle, launch screen, app icon
docs/              current feature/API facts only
test/              unit and widget tests
```

## Local Verification

Use focused checks while iterating:

```sh
flutter analyze --no-pub
flutter test --no-pub test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test --no-pub test/widget_test.dart --plain-name channel
```

For Android package/resource changes:

```sh
flutter build apk --debug
```

## Current Docs

- `AGENTS.md`: repository rules for coding agents.
- `lib/presentation/CLAUDE.md`: Material 3 UI rules for presentation-layer edits.
- `docs/FEATURES.md`: current feature implementation status.
- `docs/AS_API_CHANGES.md`: current AS/Matrix client contract boundary.
