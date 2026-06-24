---
name: p2p-client-channel-work
description: Channel workflow for the Flutter P2P client. Use for channel tab, channel inbox data, search, public lookup, create/review/approval, share cards, channel detail, channel posts, or /channel/:id/conversation chat send gating.
---

# P2P Client Channel Work

## Required Reads

Read these before editing channel behavior:

- `AGENTS.md`
- `docs/FEATURES.md`
- `docs/P2P_API_BOUNDARY.md` when P2P requests/responses change
- `lib/presentation/CLAUDE.md` when touching `lib/presentation/`

Also load `p2p-client-as-contract` for AS model or HTTP contract changes, and `p2p-client-presentation-m3` for UI changes.

## Channel Identity

A channel is a Matrix room marked by:

```text
p2p.room.kind = {"kind":"channel"}
```

Use `AsSyncBootstrap.channels` as the primary logged-in source for channel lists. Do not add a duplicate list endpoint without updating interface docs and tests.

Search, channel tab, channel detail, and channel chat must use the same channel identity source when logged in.

Channel search behavior is split by input shape: Matrix room ids still resolve through the P2P public room-id lookup; all other search text uses the signed IM public `/im/channel/list` endpoint with `name`.

When creating a public channel, call the signed IM public `/im/channel/join` directory registration after the local `channels.create` succeeds. When dissolving a channel, call signed `/im/channel/close` with the Matrix `room_id` after the local dissolve succeeds.

Channel conversations belong to channel surfaces only. Do not show channel
ProductCore conversations in the home message list, and do not write them to
the home conversation summary cache.

`/channel/:id/conversation` may use bootstrap channel metadata only to map a
channel id to its Matrix room id. It must still resolve an active ProductCore
channel conversation before opening chat; do not fall back to treating the raw
channel id as a Matrix room id.

Public remote channel lookup must use configured or contract-provided AS remotes. Do not guess a remote AS endpoint from a Matrix room id domain unless the contract explicitly requires a derived `remote_node_base_url`.

## Membership And Sending

Owner semantics belong to the portal owner, not the Agent/bot.

Channel roles are intentionally limited to `owner` and `member`. Do not add
third management roles, role constants, role labels, permission branches, or
compatibility mappings outside that two-role model.

Approval or invite does not mean joined. Wait for Matrix/AS join projection before enabling chat send.

Normalize member status through `AsChannel` / `AsChannelMember`, and treat only `isAsChannelMemberJoined(status)` as joined.

`invite` and `pending` are waiting states. They must not unlock channel sending, post creation, or joined-only navigation.

Channel join-request review actions return a top-level status such as
`approved`, `joining`, `joined`, or `join_failed`. Preserve that status in the
client UI; do not treat a successful approve request as successful membership
unless the returned status is `joined`.

Channel list entries with terminal lifecycle such as `deleted`, `left`,
`dissolve`, or `dissolved` must be hidden even if stale membership still says
`joined`.

For channel share/invite cards, show an in-progress joining state for
`pending`, `invite`, or delayed projection. Do not use "unfinished" failure
copy for these states; refresh bootstrap briefly and auto-open the channel when
the member projection becomes `joined`.

For `/channel/:id/conversation`, normal text/media messages send through Matrix SDK when the user is joined. Product policy remains the server-side send gate.

Channel share cards must include `channel_id` and `room_id` and must not create
invite grants. Owner and ordinary member share buttons both send recommendation
cards; receivers open the public channel detail by Matrix `room_id` and apply
through `channels.public.join_request` while preserving `channel_id` as channel
metadata. `channels.invite_grant.create` is reserved for explicit owner invite
flows outside the share button.

After `channels.join` returns `joined`, chat-channel routes should prefer the
returned ProductCore conversation (`AsChannel.productConversation`). If the
conversation is missing or not openable but the joined channel is a text
channel with a Matrix room id, open `/channel/:id/conversation` and let the
router resolve the channel id to the Matrix room from joined bootstrap/channel
metadata. Post channels still route to their post list. Pending, invite, or
failed statuses must continue to stay on the current/detail view and wait for
projection.

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
