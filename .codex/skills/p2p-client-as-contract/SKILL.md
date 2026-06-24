---
name: p2p-client-as-contract
description: AS/Admin API contract workflow for the Flutter P2P client. Use when changing AsClient, HttpAsClient, MockAsClient, bootstrap/sync/message APIs, AS auth, public search, product metadata, contract docs, or tests that assert AS request/response shapes.
---

# P2P Client AS Contract

## Required Reads

Before editing AS contract code, read:

- `AGENTS.md`
- `docs/AS_API_CHANGES.md`
- `docs/FEATURES.md` when the behavior is user-visible

If the change also touches `lib/presentation/`, load `p2p-client-presentation-m3`.

## Contract Boundaries

Keep `lib/data/as_client.dart` as the interface contract. Update `HttpAsClient`, `MockAsClient`, focused tests, and docs together.

Use AS Admin API only for product-layer data Matrix does not model cleanly: setup/bootstrap, portal auth, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and channel/public product search.

Do not add or restore P2P ordinary message/search/backup action clients. These actions are removed, not deprecated compatibility paths: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.

Ordinary message send, media send, history, unread, message search, and recall must use Matrix Client-Server APIs. Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomID}/local_delete` with either `event_ids` or `clear`, never both.

Do not add duplicate list APIs or duplicate client flows. If data already arrives through `/_p2p/query` action `sync.bootstrap`, prefer extending that contract and the client model.

Keep `sync.bootstrap` metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields.

Keep auth responsibilities explicit. AS Admin API calls use the current portal/session bearer credential defined by the contract; Matrix-native behavior should still flow through the Matrix SDK or Matrix API layer.

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
6. Update `docs/AS_API_CHANGES.md`; update `docs/FEATURES.md` if feature status changes.
7. If the contract rule itself changed, update this skill and `AGENTS.md` if needed.

## Current Contract Checks

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

`portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`.

Channel share cards must include `channel_id` and `room_id`. Owner/admin shares
create `channels.invite_grant.create` and send `grant_id` plus `share_room_id`
so receivers join through `channels.join`; ordinary member shares do not create
invite grants and receivers apply through `channels.public.join_request` just
using the card Matrix `room_id` while preserving `channel_id` as channel
metadata.

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
