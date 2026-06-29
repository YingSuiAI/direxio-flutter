---
name: p2p-client-channel-work
description: "Use when changing Flutter channel behavior: channel tab, inbox data, search, public lookup, create/update, public join request approval, share/invite cards, detail, posts/comments/reactions, or /channel/:id/conversation gating."
---

# P2P Client Channel Work

## Required Reads

Read these before editing channel behavior:

- `AGENTS.md`
- `docs/FEATURES.md`
- `docs/P2P_API_BOUNDARY.md` when P2P requests/responses change
- `lib/presentation/CLAUDE.md` when touching `lib/presentation/`

If channel behavior conflicts with Flutter docs, verify against
`C:\Users\84960\Desktop\direxio\direxio-message-server`. Backend references:
`docs/current-project-documentation.md`, `p2p/service_channel*.go`,
`p2p/action_registry.go`, `p2p/projection`, and `internal/productpolicy`.

Also load `p2p-client-as-contract` for AS model or HTTP contract changes, and `p2p-client-presentation-m3` for UI changes.

## Channel Identity

A channel is a Matrix room identified by native Direxio state and ProductCore
metadata: `m.room.create.content.type=io.direxio.room.channel`,
`io.direxio.room.profile.room_type=io.direxio.room.channel`, and an explicit
ProductCore `channel_id`. Do not add new code that depends on legacy
`p2p.room.kind`.

Use `AsSyncBootstrap.channels` as the primary logged-in source for channel lists. Do not add a duplicate list endpoint without updating interface docs and tests.

Search, channel tab, channel detail, and channel chat must use the same channel identity source when logged in.

Channel search behavior is split by input shape: Matrix room ids still resolve through the P2P public room-id lookup; all other search text uses the signed IM public `/im/channel/list` endpoint with `name`.

When creating a public channel, call the signed IM public `/im/channel/join` directory registration after the local `channels.create` succeeds. When dissolving a channel, call signed `/im/channel/close` with the Matrix `room_id` after the local dissolve succeeds.

Channel type is creation-time metadata. Post channels (`channel_type=post`) use
shared Matrix history so new members can see existing posts/comments/reactions;
chat/text channels use joined history visibility. Do not add UI or client
mutations that try to change channel type after creation.

Channel conversations belong to channel surfaces only. Do not show channel
ProductCore conversations in the home message list, and do not write them to
the home conversation summary cache.

Channel message rooms are locally muted by default for sound/vibration
notifications. Channel list rows should signal unread channel messages with a
red dot only; do not show unread counts for channel rows.

`/channel/:id/conversation` may use bootstrap channel metadata only to map a
channel id to its Matrix room id. It must still resolve an active ProductCore
channel conversation before opening chat; do not fall back to treating the raw
channel id as a Matrix room id.

Public remote channel lookup must use configured or contract-provided AS remotes. Do not guess a remote AS endpoint from a Matrix room id domain unless the contract explicitly requires a derived `remote_node_base_url`.

Contact/profile "his channels" surfaces use `users.public_channels`. They should show only public channels owned/administered by the target user, and cross-node add-contact/profile flows must pass the target owner node base as `remote_node_base_url`.

## Membership And Sending

Owner semantics belong to the portal owner, not the Agent/bot.

Channel roles are intentionally limited to `owner` and `member`. Do not add
third management roles, role constants, role labels, permission branches, or
compatibility mappings outside that two-role model.

Approval or invite does not mean joined. Matrix `m.room.member membership=join`
is the final joined fact. Wait for Matrix/ProductCore join projection before
enabling chat send.

Normalize member status through `AsChannel` / `AsChannelMember`:

- `join`, `joined` -> `joined`
- `invite`, `invited` -> `invite`
- `pending` -> `pending`
- `approved` -> `approved`
- `joining` -> `joining`
- `join_failed` -> `join_failed`
- `reject`, `rejected` -> `rejected`

Treat only `isAsChannelMemberJoined(status)` as joined. `invite`, `pending`,
`approved`, and `joining` are waiting states. They must not unlock channel
sending, post creation, or joined-only navigation. `join_failed` and `rejected`
are not joined states.

Post creation is owner-only. Show the post-list create entry only when the user
is joined, the channel type is `post`, the resolved role is `owner`, and the
ProductCore `postCreate` capability allows it. Ordinary `member` roles must not
see the create entry even if stale capabilities report `postCreate: true`.

Public channel join requests expose `pending`, `rejected`, `approved`,
`joining`, `joined`, or `join_failed`. Channel join-request review actions
return a top-level status from that lifecycle. Preserve that status in the
client UI; do not treat a successful approve request as successful membership
unless the returned status is `joined`. Backend approval writes
`io.direxio.join_request status=approved`; requester-node Matrix join must
finish before the projection becomes joined.

Channel list entries with terminal lifecycle such as `deleted`, `left`,
`dissolve`, or `dissolved` must be hidden even if stale membership still says
`joined`.

For channel share/invite cards, show an in-progress joining state for
`pending`, `invite`, `approved`, `joining`, or delayed projection. Do not use
failure copy for these states. Show failure only for `join_failed`/`rejected`,
refresh bootstrap briefly, and auto-open the channel when the member projection
becomes `joined`.

For `/channel/:id/conversation`, normal text/media messages send through Matrix SDK when the user is joined. Product policy remains the server-side send gate.

Channel share cards must include `channel_id` and `room_id` and must not create
invite grants. Owner and ordinary member share buttons both send recommendation
cards; receivers open the public channel detail by Matrix `room_id` and apply
through `channels.public.join_request` while preserving `channel_id` as channel
metadata. `channels.invite_grant.create` is reserved for the owner member-list
`+` invite flow outside the share button.

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
