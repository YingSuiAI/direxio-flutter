# AS API Change Log

Last updated: 2026-06-20

This document records frontend-impacting AS/Admin API changes. It is the client-side companion to the server work recorded in Codex thread `019edf7c-54fa-7ba3-a8f8-99c8dac1e838`.

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
- Legacy `dendrite` / `federation` / `agent` health subtrees are not guaranteed.

Frontend alignment:

- `PortalStatus` accepts both legacy and unified response shapes.
- `PortalStatus.allHealthy` treats the unified shape as healthy only when initialized, user id, homeserver, store mode, and projector state are usable.
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
- Recovered unread remains overlay-only and is not written to Matrix SDK persistent timeline.

## 2026-06-20 Client Follow-Up

### Pending Group Invitations

Frontend alignment:

- `/_as/sync/bootstrap.pending.group_invites[]` is now treated as actionable pending group invitations on the New Friends page.
- Each pending group invite uses `id` as the Matrix room id and `title` as the group display name.
- Accepting the invite calls `POST /_as/groups/{roomId}/join`, then runs one Matrix one-shot sync and refreshes bootstrap.
- The Home contacts badge now includes pending group invites and channel notices, not only friend requests.

### Channel Text Messages

Frontend alignment:

- `/channel/:id/conversation` sends text through existing `POST /_as/rooms/{roomId}/send` instead of direct Matrix `sendTextEvent`.
- Joined channel members are allowed to type/send when AS bootstrap says their `member_status` is `joined`; Matrix `m.room.message` power level is no longer used as the frontend text-send gate.
- `invite` and `pending` channel member statuses still block sending until Matrix/AS projection confirms `joined`.

### Concrete Room History Restore

Frontend alignment:

- Bootstrap remains metadata-only.
- Opening a concrete private chat, group, or channel conversation may request the first visible Matrix timeline history page so restored apps can show/sync messages after restart.

### Message And Call Query Compatibility

Change:

- `sync.messages.limit` is accepted as an alias for `page_size`.
- `calls.active` filters all terminal states.

Frontend alignment:

- Current `HttpAsClient.syncMessages` continues to send `page_size`; no frontend contract change required.
- Existing active call flows rely on AS active-call filtering and do not need client-side terminal-state patching.

## Maintenance Rule

When AS contracts change:

- Update `lib/data/as_client.dart` first.
- Update `lib/data/http_as_client.dart` and `lib/data/mock_as_client.dart` together.
- Update focused tests in `test/http_as_client_test.dart` and affected widget tests.
- Update this document in the same frontend change.
