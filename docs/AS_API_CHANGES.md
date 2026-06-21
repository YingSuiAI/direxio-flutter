# AS API Change Log

Last updated: 2026-06-21

This document records frontend-impacting AS/Admin API changes. It is the client-side companion to the server work recorded in Codex thread `019edf7c-54fa-7ba3-a8f8-99c8dac1e838`.

## 2026-06-21 ProductCore ConversationView Contract

Change:

- `conversations.list` and `conversations.get` return hydrated ProductCore conversation fields:
  - `member_count`
  - `membership`
  - `relationship_status`
  - `role`
  - `hydration_state`
  - `hydration_reason`
  - `capabilities.open`
  - `capabilities.send`
  - `capabilities.invite`
  - `capabilities.manage_members`

Frontend alignment:

- `AsConversation` parses the new fields and exposes `canOpen`, `canSend`, `canInvite`, and `canManageMembers`.
- Product conversation route generation now fails closed when `canOpen` is false, so message list, contact detail, search, and group entry points no longer independently infer whether a conversation can be opened.

## 2026-06-20 Final Message Contract Alignment

Change:

- P2P ordinary message/search/backup actions are removed, not deprecated compatibility entries: `sync.unread`, `sync.messages`, `search`, `rooms.send`, `rooms.send_media`, `rooms.messages.delete`, `rooms.messages.delete_batch`, `rooms.messages.delete_range`, `rooms.messages.recall`, `contacts.export`, `contacts.download`, and `contacts.import`.
- Ordinary text/media send, incremental sync/unread, history, search, and recall use Matrix Client-Server APIs: room send, `/sync`, `/rooms/{roomId}/messages`, `/search`, and Matrix redaction.
- Local delete/clear uses `POST /_matrix/client/v1/io.direxio/rooms/{roomId}/local_delete` with either `{ "event_ids": [...] }` or `{ "clear": true }`. It hides events only for the current user's local Matrix read path and is not a redaction.
- Ordinary `m.room.message` is not projected into P2P message tables. Only Matrix messages with `p2p_kind=channel_post` or `p2p_kind=channel_comment` project into channel product post/comment tables.
- Room classification must come from product metadata (`contacts.list`, `groups.list`, `channels.list`, bootstrap contacts/groups/channels/pending) and Matrix `io.direxio.room.profile`, not from message content.
- Channel share cards create an invite grant first with `channels.invite_grant.create`, passing `channel_id` or `room_id` plus `share_room_id`; the receiver joins with `channels.join` using `grant_id` and `share_room_id`.

Frontend alignment:

- Removed ordinary message/search/backup methods and models from `AsClient`, `HttpAsClient`, and `MockAsClient`.
- Added Matrix boundary clients for message search and local visibility delete/clear.
- Private, group, and channel conversation search now use Matrix `/search` for message hits.
- Direct/group/channel message send and card send use Matrix room events; group invite cards are no longer sent through AS `rooms.send`.
- Channel share cards create an AS invite grant, then send the share card as a Matrix room message containing `grant_id` and `share_room_id`.
- App warmup, event-stream refresh, chat pages, and home lists no longer use recovered unread or AS history message recovery.

## 2026-06-20 Request-Provided Remote Nodes And Unified Token

### Public Remote Channel Lookup

Change:

- Public remote channel lookup no longer uses a server-side remote-node env table.
- Requests for remote Matrix room IDs must pass `remote_node_base_url` with the owner node's `/_p2p` base URL.
- The backend validates `room_id` and `remote_node_base_url`; missing or invalid remote URL returns `400`.

Frontend alignment:

- `HttpAsClient.getPublicChannelByRoomId` and `joinChannelByRoomId` accept `remoteNodeBaseUri` and send it as `remote_node_base_url`.
- Public-channel search/detail/join flows derive `remoteNodeBaseUri` from the searched Matrix room ID and include it in lookup/join requests.

### Portal Session Token

Change:

- `portal.bootstrap`, `portal.auth`, and `portal.password` return only `access_token`.
- `admin_access_token` and `matrix_access_token` are removed and are not parsed by the client.

Frontend alignment:

- `AsPortalSession` stores a single `accessToken`.
- Matrix SDK login/session setup and protected P2P API bearer auth both use that same token.

## 2026-06-19 Server Sync

Server reference:

- Branch: `p2p-integrated-as`
- Commit: `4bd44609 fix: harden p2p multi-node communication`
- Docker image tags: `direxio/message-server:latest`, `direxio/message-server:4bd44609`
- Image digest: `sha256:e2e0f2...`

### Public Remote Channel Lookup

Change:

- Public remote channel lookup now requires `remote_node_base_url` in the request.
- TLS verification is enabled by default.
- The client supplies the target node `/_p2p` base URL for remote Matrix room IDs.

Frontend alignment:

- `ChannelSearchPage` includes `remote_node_base_url` for Matrix room-id lookup.
- Widget coverage asserts the derived remote node base URI is passed to lookup and join requests.

### Channel Join / Approval Status

Change:

- Public channel join and owner approval no longer imply immediate membership `join`.
- Join/approval may return top-level `status: "invited"` and member membership/status `invite`.
- Actual `joined` is only valid after Matrix join projection confirms membership.

Frontend alignment:

- `AsChannel.memberStatus` and `AsChannelMember.status` normalize these aliases:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `reject`, `rejected` -> `rejected`
- `isAsChannelMemberJoined` is the only positive joined predicate.
- `isAsChannelMemberAwaitingJoin` covers `pending` and `invite`.
- Channel search/detail/post/chat join flows show waiting messages for `pending`/`invite` and do not navigate into joined chat until status is `joined`.
- Channel conversation sending is blocked for `invite` and `pending`.
- `HttpAsClient.joinChannelByRoomId` merges top-level join status into the returned channel for current-user join flows only.
- `HttpAsClient.approveChannelJoin` does not merge top-level status into current-user state because approval status belongs to the target member.
- `MockAsClient` now simulates public join as `invite` or `pending`, and approval as `invite`.

### `portal.status`

Change:

- `portal.status` now returns unified fields:
  - `initialized`
  - `user_id`
  - `homeserver`
  - `store_mode`
  - `projector_started`
  - `policy_index_mode`
  - `policy_index_ready`
  - `event_stream_ready`
- Legacy `dendrite` / `federation` / `agent` health subtrees are not guaranteed.

Frontend alignment:

- `PortalStatus` accepts both legacy and unified response shapes.
- `PortalStatus.allHealthy` treats the unified shape as healthy only when initialized, user id, homeserver, store mode, projector state, policy index, and event stream are usable. `policy_index_mode` is diagnostic: production Matrix transport normally reports `matrix_state` and ready, while unavailable test/degraded modes may report false.
- Existing tests cover the unified response.

### Bootstrap And Privacy

Change:

- Product state events are published for group/channel create/update/dissolve.
- The projector supports dissolved rooms and ignores unknown non-product rooms.
- New-device bootstrap remains metadata-only.

Frontend alignment:

- Channel list still uses `AsSyncBootstrap.channels` as the primary logged-in source.
- Empty real bootstrap channels produce a real empty state instead of mock channels.
- Client privacy rule remains: no `last_message` or historical read bodies in `/_as/sync/bootstrap`.
- Unread, history, search, and ordinary message recall stay on Matrix Client-Server APIs.

## 2026-06-20 Client Follow-Up

### Pending Group Invitations

Frontend alignment:

- `/_as/sync/bootstrap.pending.group_invites[]` is now treated as actionable pending group invitations on the New Friends page.
- Each pending group invite uses `id` as the Matrix room id and `title` as the group display name.
- Accepting the invite calls `POST /_as/groups/{roomId}/join`, then runs one Matrix one-shot sync and refreshes bootstrap.
- The Home contacts badge now includes pending group invites and channel notices, not only friend requests.

### Group Invite Cards

Frontend alignment:

- Existing group member invitations record invitees on the owner node, then send `msgtype: "p2p.group.invite.v1"` through the Matrix direct room.
- The Matrix message payload carries `msgtype: "p2p.group.invite.v1"`, `group_room_id`, `group_name`, `inviter_mxid`, optional `inviter_display_name`, and `direct_room_id`.
- `POST /_as/groups/{roomId}/join` rejects invite-card joins with `403` when the joining MXID does not have a recorded group invite.

### Group Invite Response

Frontend alignment:

- `groups.invite` may return `status: "ok"` plus `members[]` without a top-level `room_id`.
- `HttpAsClient.inviteGroupMembers` treats that response as successful and derives the group room id from the request path while using `members.length` as the recorded invite count.

### Channel Text Messages

Frontend alignment:

- Private chat, group chat, and `/channel/:id/conversation` normal text/media messages send through Matrix SDK `m.room.message`.
- Normal message recall uses Matrix redaction. Local delete/hide uses the Matrix `io.direxio` local delete extension because it is not a server-side redaction.
- New direct invites are recognized from native `io.direxio.room.profile` state with `room_type=io.direxio.room.direct`, `requester_mxid`, and `target_mxid`; the client no longer assumes new direct invite stripped state contains legacy `p2p.contact.request`.
- Joined channel members are allowed to type/send when AS bootstrap says their `member_status` is `joined`; Matrix ProductPolicy is the authoritative server-side send gate.
- Group/channel Matrix message content preserves product mention metadata as `mentions` and `mentions_json`. Reply sends Matrix `m.relates_to` and keeps `reply_to` as a product compatibility field.
- `invite` and `pending` channel member statuses still block sending until Matrix/AS projection confirms `joined`.

### P2P Event Stream

Change:

- `GET /_p2p/events?since=<seq>` is available as an authenticated SSE refresh stream.
- `Last-Event-ID` is supported for replay after reconnect.
- Event data includes `seq`, `type`, optional `room_id` / `event_id`, `payload`, and `created_at`.

Frontend alignment:

- `HttpAsClient.streamEvents` opens the SSE endpoint with bearer auth and parses SSE records into `AsEventStreamEvent`.
- `asEventStreamRefreshProvider` starts after login, reconnects with the latest seq, and treats events as refresh hints.
- Event-stream records are refresh hints: the client runs Matrix one-shot sync and AS bootstrap refresh. Ordinary message unread recovery is handled by Matrix, not AS.

### Channel Post / Comment Matrix Content

Frontend alignment:

- Compatibility facade calls remain available for existing channel post/comment product flows.
- When a future client path sends channel posts/comments directly through Matrix SDK, it must include `p2p_kind=channel_post` or `p2p_kind=channel_comment`.
- For channel media post/comment content, Matrix `msgtype` remains the media type such as `m.image`, `m.video`, or `m.file`; Direxio classification is carried by `p2p_kind=channel_post` / `p2p_kind=channel_comment`.
- Channel comments must include `post_id`; channel post/comment media must include `media_json`; product fields such as `channel_id`, `comment_id`, `reply_to_comment_id`, `reply_to_author_mxid`, `mentions`, and `mentions_json` should be preserved in Matrix event content.

### Concrete Room History Restore

Frontend alignment:

- Bootstrap remains metadata-only.
- Opening a concrete private chat, group, or channel conversation may request the first visible Matrix timeline history page so restored apps can show/sync messages after restart.

### Message And Call Query Compatibility

Change:

- `calls.active` filters all terminal states.

Frontend alignment:

- Existing active call flows rely on AS active-call filtering and do not need client-side terminal-state patching.

## Maintenance Rule

When AS contracts change:

- Update `lib/data/as_client.dart` first.
- Update `lib/data/http_as_client.dart` and `lib/data/mock_as_client.dart` together.
- Update focused tests in `test/http_as_client_test.dart` and affected widget tests.
- Update this document in the same frontend change.
