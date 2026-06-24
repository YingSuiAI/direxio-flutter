---
name: p2p-client-guardrails
description: Repo-wide workflow for the Flutter P2P client. Use for any task in C:\Users\84960\Desktop\direxio\p2p-client, especially code edits, docs updates, tests, commits, or deciding which more specific p2p-client skill applies.
---

# P2P Client Guardrails

## Start Here

Read `AGENTS.md` before making changes. Treat it as the repo-wide authority, with `CLAUDE.md` only as a legacy pointer.

Check the current worktree before editing:

```powershell
git status --short --branch
```

Preserve user or generated changes that are already present. Stage only files that belong to the requested task.

## Skill Routing

Use this skill as the entry point, then load a focused skill when the task matches:

- `p2p-client-presentation-m3`: UI or widget work under `lib/presentation/`.
- `p2p-client-as-contract`: AS/Admin API contracts, models, HTTP parsing, mocks, or AS docs.
- `p2p-client-channel-work`: channel search, join, approval, inbox, detail, share, or channel chat behavior.
- `p2p-client-auth-session`: login, setup, restore, route guards, portal session, or auth token behavior.
- `p2p-client-release-build`: rebuild APK/web/iOS artifacts or package release output.

If a business rule, contract, UI rule, workflow, or verification requirement changes, update the relevant `.codex/skills/*/SKILL.md` in the same change. Keep `AGENTS.md`, `docs/FEATURES.md`, `docs/AS_API_CHANGES.md`, and the skills consistent.

## Repo Rules

Keep the product rule intact: one person, one node, one owner. Agent/service accounts may appear as system conversations, but they are not normal human contacts.

Use Matrix SDK for Matrix-native behavior: login session, rooms, timeline, membership, media, profile avatar/display name, read markers, and Matrix message state.

Use AS Admin API for product-layer data Matrix does not model cleanly: setup/bootstrap, portal auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and channel/public product search.

Do not add or restore P2P ordinary message/search/backup action clients. Removed actions include `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.

Ordinary message send, media send, unread, history, message search, and recall belong to Matrix Client-Server APIs. Local delete/clear belongs to the Matrix `io.direxio` local delete extension.

Do not silently fall back to mock data after login. A real empty state is better than fake data. Mock data belongs only in unauthenticated demos, explicit tests, or temporary UI scaffolding.

Keep Flutter/Dart source files under 3000 lines. When touching an oversized file, extract focused widgets, controllers, helpers, or tests into smaller files instead of adding more code to the oversized file.

Before user-visible behavior changes, read `docs/FEATURES.md` and update it if a feature moves between demo, partial, local, or real status.

Before AS/Admin API contract changes, read `docs/AS_API_CHANGES.md` and update it in the same change.

## Verification

Run focused checks for touched files, then the broadest practical check before finishing:

```powershell
flutter analyze --no-pub
flutter test --no-pub <relevant tests>
```

For local iteration with less Flutter tool noise, prefer `scripts/local_verify.sh`.
It checks the generated files needed by local builds, deletes `flutter_*.log`
crash logs, runs `flutter test` commands serially to avoid native assets
manifest races, and reports iOS project-file churn from simulator builds. If
`lib/core/router/app_router.g.dart` or
`lib/presentation/providers/auth_provider.g.dart` is missing, regenerate with:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

For channel/search work, run:

```powershell
flutter test --no-pub test/channel_page_real_test.dart test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test --no-pub test/widget_test.dart --plain-name channel
flutter test --no-pub test/widget_test.dart --plain-name 'global search'
```

For auth/session changes, run the auth/provider tests and at least one login or restore widget path.

For platform/build changes, run the relevant target build.

If a check cannot be run, record the exact reason in the final answer.
