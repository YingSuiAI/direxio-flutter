---
name: p2p-client-channel-work
description: Channel workflow for the Flutter P2P client. Use for channel tab, channel inbox data, search, public lookup, create/review/approval, share cards, channel detail, channel posts, or /channel/:id/conversation chat send gating.
---

# P2P Client Channel Work

## Required Reads

Read these before editing channel behavior:

- `AGENTS.md`
- `docs/FEATURES.md`
- `docs/AS_API_CHANGES.md` when AS requests/responses change
- `lib/presentation/CLAUDE.md` when touching `lib/presentation/`

Also load `p2p-client-as-contract` for AS model or HTTP contract changes, and `p2p-client-presentation-m3` for UI changes.

## Channel Identity

A channel is a Matrix room marked by:

```text
p2p.room.kind = {"kind":"channel"}
```

Use `AsSyncBootstrap.channels` as the primary logged-in source for channel lists. Do not add a duplicate list endpoint without updating interface docs and tests.

Search, channel tab, channel detail, and channel chat must use the same channel identity source when logged in.

Public remote channel lookup must use configured or contract-provided AS remotes. Do not guess a remote AS endpoint from a Matrix room id domain unless the contract explicitly requires a derived `remote_node_base_url`.

## Membership And Sending

Owner semantics belong to the portal owner, not the Agent/bot.

Approval or invite does not mean joined. Wait for Matrix/AS join projection before enabling chat send.

Normalize member status through `AsChannel` / `AsChannelMember`, and treat only `isAsChannelMemberJoined(status)` as joined.

`invite` and `pending` are waiting states. They must not unlock channel sending, post creation, or joined-only navigation.

For `/channel/:id/conversation`, normal text/media messages send through Matrix SDK when the user is joined. Product policy remains the server-side send gate.

## Implementation Pattern

Keep reusable channel data shaping outside route pages when shared or testable, for example `lib/presentation/channel/channel_inbox_data.dart`.

Keep local UI-only state out of AS models. Use providers or stores with clear names.

Use real Matrix/AS data after login. Mock channels are only for unauthenticated demos, explicit tests, or temporary scaffolding.

## Verification

At minimum, run:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/channel_page_real_test.dart test/channel_inbox_data_test.dart test/http_as_client_test.dart
flutter test --no-pub test/widget_test.dart --plain-name channel
flutter test --no-pub test/widget_test.dart --plain-name 'global search'
```

Add focused tests for new channel status transitions, remote lookup request fields, route gating, or send gating.
