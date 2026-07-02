---
name: p2p-client-as-contract
description: Use when changing Flutter P2P Product API or signed IM/BI contracts, including AsClient, HttpAsClient, MockAsClient, bootstrap/events, auth, ProductCore conversations, public search, reports, metadata, docs, or tests asserting request/response shapes.
---

# Direxio Flutter Product API Contract

## Required Reads

Before editing AS contract code, read:

- `AGENTS.md`
- `docs/P2P_API_BOUNDARY.md`
- `docs/FEATURES.md` when the behavior is user-visible

If any contract rule is unclear or conflicts with Flutter docs, check
`C:\Users\84960\Desktop\direxio\direxio-message-server` and follow the backend.
Start with backend `AGENTS.md` and `docs/current-project-documentation.md`, then
inspect `p2p/action_registry.go`, the relevant `p2p/service_*.go` handler, and
`internal/productpolicy` for Matrix write rules.

If the change also touches `lib/presentation/`, load `p2p-client-presentation-m3`.

## Contract Boundaries

Keep `lib/data/as_client.dart` as the interface contract. Update `HttpAsClient`, `MockAsClient`, focused tests, and docs together.

Use AS Product API only for product-layer data Matrix does not model cleanly: setup/bootstrap, portal auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and channel/public product search.

Current public Product API actions are `portal.bootstrap`, `portal.auth`,
`portal.status`, `contacts.reactivate`, `channels.public.search`,
`channels.public.get`, `channels.public.join_request`,
`channels.public.join_result`, and `users.public_channels`.
`channels.public.join_result` is an internal node-to-node callback, not a
normal Flutter workflow entry.

Signed IM/BI public endpoints are not AS ProductCore `/_p2p` actions. Keep them in the IM public client boundary with `X-BI-Nonce` / `X-BI-Signature` signing. Public channel tags, public channel directory registration/close, non-room-id public channel list search, public channel rating, BI launch/login events, and Flutter user-facing report screens use those signed `/im/*` and `/bi/*` endpoints. The public base URL and secret are fixed in code; BI reporting is always enabled. Do not read these settings from dart-define or other runtime configuration.

Signed public channel contracts use documented snake_case fields: `/im/tag/public/list?type=channel` supplies channel tags and should be cached locally for one day; `/im/channel/list` uses `page_size`, `sort_by`, and optional `tag_id`, and may return `tag_id`, `rating_count`, and `average_score`; `/im/channel/join` uses `channel_domain`, `room_id`, and optional `tag_id`; `/im/channel/rating` uses `uid`, `room_id`, and `score`.

User-facing reports must call imadmin `/im/report`, not Direxio Message Server
ProductCore. Use `targetType = 1` for friends, `2` for groups, and `3` for
channels. Image evidence is sent as repeated multipart `files` fields; do not
send the legacy `images` field for uploaded files. Do not add Flutter
`AsClient` / `HttpAsClient` report methods or connect report UI to P2P
`reports.submit`.

Do not add or restore P2P ordinary message/search/backup action clients. These actions are removed, not deprecated compatibility paths: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.

Ordinary message send, media send, history, unread, message search, and recall must use Matrix Client-Server APIs. Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomID}/local_delete` with either `event_ids` or `clear`, never both.

Agent room text and `/` commands are ordinary Matrix message sends into the
real private `agent_room_id`. Do not add P2P command facades for chat text, and
do not depend on legacy pseudo agent room ids.

Agent settings are server-backed through `agent.config.get/update`. Keep
`display_name`, `avatar_url`, `context_window`, and `mcp_blocked_room_ids` in
`AgentConfig`, `HttpAsClient`, tests, and docs. `mcp_blocked_room_ids` is the
backend-enforced MCP room blacklist, not local-only preference state.

MCP permission listing and status changes are local-only in Flutter unless the
backend exposes a new contract. Do not add or restore ProductCore helper
methods or action mappings for server-backed MCP permission list/status
management.

Do not add duplicate list APIs or duplicate client flows. If data already arrives through `/_p2p/query` action `sync.bootstrap`, prefer extending that contract and the client model.

Keep `sync.bootstrap` metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields.

Keep auth responsibilities explicit. Backend auth responses expose one `access_token`; P2P product API calls use it as bearer auth, and Matrix-native behavior should still flow through the Matrix SDK or Matrix API layer using the same token. Do not add separate token fields such as `product_token`, `matrix_token`, `product_access_token`, or `matrix_access_token`.

`portal.bootstrap`, `portal.auth`, and `portal.password` create a new exclusive
Matrix device session for the portal owner. Old owner devices should receive
Matrix `M_UNKNOWN_TOKEN`; `agent.matrix_session.create` is the exception and
must not evict the user's phone/browser session.

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

Product room classification comes from native Direxio Matrix state
`m.room.create.content.type`, `io.direxio.room.profile`, `io.direxio.member.policy`,
`io.direxio.join_request`, plus ProductCore metadata. Do not add new contract
code that depends on legacy `p2p.room.kind`.

Normalize channel member status through `AsChannel` / `AsChannelMember` helpers:

- `join`, `joined` -> `joined`
- `invite`, `invited` -> `invite`
- `pending` -> `pending`
- `approved` -> `approved`
- `joining` -> `joining`
- `join_failed` -> `join_failed`
- `reject`, `rejected` -> `rejected`

Treat only `isAsChannelMemberJoined(status)` as joined. Use
`isAsChannelMemberAwaitingJoin(status)` for `pending`, `invite`, `approved`,
and `joining`, and keep `join_failed` separate from rejected/terminal copy.

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

If `GET /_p2p/events` reports a cursor reset through the `p2p.cursor_reset`
control event or `X-Direxio-P2P-Events-Cursor-Reset: true`, clear local product
projections, call `sync.bootstrap` once, persist the newest handled event `seq`,
and resume normal delta consumption.

Foreground Matrix refreshes should use filtered `/sync` with a low timeline
limit and `lazy_load_members=true`. Do not use Product API actions for ordinary
message send, media history, unread, search, recall, or local delete.

Channel post/comment list methods may keep local progressive-loading arguments,
but `HttpAsClient` must not send uncontracted `limit`, `before_ts`, `page`, or
`page_size` params until the backend documents a stable pagination contract.

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
