---
name: p2p-client-as-contract
description: AS/Product API contract workflow for the Flutter P2P client. Use when changing AsClient, HttpAsClient, MockAsClient, bootstrap/sync/message APIs, AS auth, public search, product metadata, contract docs, or tests that assert AS request/response shapes.
---

# P2P Client AS Contract

## Required Reads

Before editing AS contract code, read:

- `AGENTS.md`
- `docs/P2P_API_BOUNDARY.md`
- `docs/FEATURES.md` when the behavior is user-visible

If the change also touches `lib/presentation/`, load `p2p-client-presentation-m3`.

## Contract Boundaries

Keep `lib/data/as_client.dart` as the interface contract. Update `HttpAsClient`, `MockAsClient`, focused tests, and docs together.

Use AS Product API only for product-layer data Matrix does not model cleanly: setup/bootstrap, portal auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and channel/public product search.

Signed IM/BI public endpoints are not AS ProductCore `/_p2p` actions. Keep them in the IM public client boundary with `X-BI-Nonce` / `X-BI-Signature` signing. Public channel directory registration/close, non-room-id public channel list search, BI launch/login events, and user/group/channel report submissions use those signed `/im/*` and `/bi/*` endpoints. The public base URL and secret are fixed in code; BI reporting is always enabled. Do not read these settings from dart-define or other runtime configuration.

Report submissions from UI must call `/im/report`: `targetType = 1` for friends, `2` for groups, and `3` for channels. Image evidence is sent as repeated multipart `files` fields; do not send the legacy `images` field for uploaded files.

Do not add or restore P2P ordinary message/search/backup action clients. These actions are removed, not deprecated compatibility paths: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.

Ordinary message send, media send, history, unread, message search, and recall must use Matrix Client-Server APIs. Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomID}/local_delete` with either `event_ids` or `clear`, never both.

Agent room text and `/` commands are ordinary Matrix message sends into the
real private `agent_room_id`. Do not add P2P command facades for chat text, and
do not depend on legacy pseudo agent room ids.

Do not add duplicate list APIs or duplicate client flows. If data already arrives through `/_p2p/query` action `sync.bootstrap`, prefer extending that contract and the client model.

Keep `sync.bootstrap` metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields.

Keep auth responsibilities explicit. Backend auth responses expose one `access_token`; P2P product API calls use it as bearer auth, and Matrix-native behavior should still flow through the Matrix SDK or Matrix API layer using the same token. Do not add separate token fields such as `product_token`, `matrix_token`, `product_access_token`, or `matrix_access_token`.

When AS requests fail with `M_UNKNOWN_TOKEN`, report the rejected bearer token to
auth/session handling. Delayed failures from a previous bearer after login or
password rotation must not clear a session that has already applied a newer
token.

Accepted-contact remark updates use `contacts.update` with `room_id` and
`display_name`; the backend stores that remark as contact `display_name`.

## Change Order

1. Update `AsClient` types and method signatures first.
2. Update `HttpAsClient` request bodies, response parsing, and error handling.
3. Update `MockAsClient` so demo and tests exercise the same contract shape.
4. Update Riverpod providers or UI adapters that consume the contract.
5. Add or adjust focused tests, especially `test/http_as_client_test.dart`.
6. Update `docs/P2P_API_BOUNDARY.md`; update `docs/FEATURES.md` if feature status changes.
7. If the contract rule itself changed, update this skill and `AGENTS.md` if needed.

## Current Contract Checks

Channel and group role handling is intentionally limited to `owner` and
`member`. Do not add third management roles, role constants, role labels,
permission branches, or compatibility mappings outside that two-role model.

Normalize channel member status through `AsChannel` / `AsChannelMember` helpers:

- `join`, `joined` -> `joined`
- `invite`, `invited` -> `invite`
- `pending` -> `pending`
- `reject`, `rejected` -> `rejected`

Treat only `isAsChannelMemberJoined(status)` as joined.

Channel list consumers must also honor terminal lifecycle fields from
bootstrap/list/ProductCore channel data. `deleted`, `left`, `dissolve`, and
`dissolved` channels are not visible channel-list entries even when stale
membership still normalizes to `joined`.

Public remote channel lookup must use explicitly configured AS remotes or request-provided remote base URLs. Do not infer a remote AS URL from a Matrix `room_id` domain unless the current contract document explicitly says to derive and pass a concrete remote base URL.

`users.public_channels` returns only the target user's owned/admin public channels. Cross-node profile/add-contact entry points must pass `remote_node_base_url` through `getUserPublicChannels(remoteNodeBaseUri:)` so the local AS can forward to the target owner node.

`portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`. `initialized` means the generated initial password has been changed; owner profile data is not part of initialization.

Agent header presence comes from native Matrix room state in the real
`agent_room_id`: event type `io.direxio.agent.status`, state key
`@agent:<server>`, and content field `online`. `sync.bootstrap` only supplies
the real `agent_room_id`; it must not mirror the online bit, and
`GET /_p2p/events` must not emit `agent.presence`. `agent.status` and
`agents.status` are not current Flutter APIs.

Use `sync.bootstrap` only as a baseline for cold start, login recovery, corrupt
local cache, unknown event fallback, or confirmed event gaps. Normal changes
should persist the last handled SSE `seq` and apply typed local reducers from
`GET /_p2p/events?since=<last_seq>` instead of refreshing the full bootstrap
snapshot.

Channel share cards must include `channel_id` and `room_id` and must not create
invite grants. Owner and ordinary member share buttons both send recommendation
cards; receivers open the public channel detail by Matrix `room_id` and apply
through `channels.public.join_request` while preserving `channel_id` as channel
metadata. `channels.invite_grant.create` is reserved for the owner member-list
`+` invite flow outside the share button.

`groups.create`, `groups.join`, and `channels.join` may return top-level ProductCore `conversation`.
Preserve it on `AsGroupResult.productConversation` or
`AsChannel.productConversation`, and open chat routes from that conversation.
Do not reconstruct a post-create or post-join chat route from channel id, room
id, group name, or member count when the ProductCore conversation is missing or
not openable.

`channels.join_request.approve` and `channels.join_request.reject` return a
top-level approval/join status. Preserve it separately from the returned channel
metadata so `approved`, `joining`, and `join_failed` are not mistaken for
`joined`.

`groups.invite` notifies receivers through Matrix `rooms.invite`, with an
optional metadata mirror in `sync.bootstrap.pending.group_invites`. Do not treat
the receiver contract as a private-chat group invite message.

## Verification

Run:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/http_as_client_test.dart
```

Add relevant provider/widget tests for each consumer touched by the contract change.
