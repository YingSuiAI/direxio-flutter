# Direxio Client API Boundary

Last verified from current code: 2026-07-02

This document records the current P2P product API / Matrix boundary used by the Flutter client. It intentionally omits historical change logs.

## Signed IM/BI Public API Boundary

- The IM/BI public endpoints are separate from the authenticated P2P ProductCore `/_p2p` action boundary.
- The client sends IM/BI public endpoint requests to the fixed base URL `https://imadmin.direxio.ai/api` and signs requests with `X-BI-Nonce` plus `X-BI-Signature`.
- The fixed public secret is `f88c10fe-4559-fa77-b8b9-beadf468ddba`.
- Public channel directory registration uses `POST /im/channel/join` after a public channel is created locally; directory closure uses `POST /im/channel/close` after local channel dissolve.
- Channel search keeps Matrix-room-id lookup on the existing P2P public room detail action. All other channel search text uses signed `GET /im/channel/list` with `name`.
- User-facing report submissions use signed `POST /im/report`; friend reports send `targetType = 1`, group reports send `targetType = 2`, and channel reports send `targetType = 3`. Report images are uploaded as repeated multipart `files` fields, not `images`.
- BI startup events are always enabled and use signed `POST /bi/events/report`. First install reports `eventType = launch`; every app startup/login path reports `eventType = login`; payload is currently empty.

## Token Boundary

- Backend auth responses expose one `access_token`.
- Startup/session P2P calls use `access_token` as bearer auth. Logged-in product calls use WS when the realtime transport is already ready; if WS is not ready or disconnected at click time, the current action falls back to owner HTTP immediately while the realtime stream reconnects in the background.
- Matrix Client-Server API calls use the same `access_token` through the Matrix SDK.
- P2P product API clients must use a `/_p2p` base URI. After login, non-MCP product methods send WS `client.request` frames to `GET /_p2p/ws` only after `server.ready`; if realtime is not ready, the same action envelope is sent to HTTP `/_p2p/query` or `/_p2p/command` with the owner bearer token immediately. HTTP is still the primary path for portal bootstrap/auth/status/password, `realtime.ws_ticket.create`, fixed `mcp.*` actions, and node-to-node public/callback actions.
- Matrix access tokens are never a fallback credential for P2P product API calls.
- After `portal.password` succeeds, persist the new login password and new P2P bearer token before any Matrix or P2P follow-up request can refresh authentication.
- When login or password changes rotate the bearer token, delayed Matrix or P2P `M_UNKNOWN_TOKEN` responses from the previous token must not expire a session that has already applied the newer token.
- Do not add `product_token`, `matrix_token`, `product_access_token`, or `matrix_access_token` fields.
- `initialized` is the single initialization flag. It means the generated initial password has been changed; owner profile data is optional and must not gate initialization.

## P2P Product API Responsibilities

- Logged-in non-MCP product requests use WS `client.request` frames with an `action` and `params` body when WS is ready. If WS is not ready or disconnected, the client falls back immediately to HTTP `POST /_p2p/query` or `POST /_p2p/command` with the same `action` and `params`; the realtime stream reconnects separately. If a WS request was already sent and the response is lost, HTTP fallback is allowed only for safe repeated actions such as contact request decisions, joins, read markers, and product queries. Business errors returned by WS are not retried over HTTP.
- Portal actions: `portal.bootstrap`, `portal.auth`, `portal.status`, `portal.password`.
- Bootstrap metadata action: `sync.bootstrap` for contacts, groups, channels, pending requests, user profile, and product summaries.
- Conversation actions: `conversations.list`, `conversations.get`.
- Contact actions: `contacts.list`, `contacts.request`, `contacts.reactivate`, `contacts.requests.accept`, `contacts.requests.reject`, `contacts.requests.delete`, `contacts.update`, `contacts.delete`.
- Contact request remarks travel as `remark` on `contacts.request` and may be mirrored in contact or `sync.bootstrap.pending.friend_requests` metadata for the verifier UI.
- Accepted-contact remark updates use `contacts.update` with `room_id` and `display_name`; the backend stores the remark as the contact `display_name`, not as a separate `remark` field.
- Contact identity writes preserve the peer profile: `contacts.request`, `contacts.requests.accept`, and `contacts.update` may send `display_name`, `avatar_url`, and `domain`; `ContactEntry` reads `avatar_url` back for contact and direct-conversation caches.
- Block actions: `blocks.list`, `blocks.add`, and `blocks.remove`. `blocks.list` returns grouped `contacts`, `groups`, and `channels`; the client does not require a merged total list. Contact blocks are keyed by peer Matrix id, while group and channel blocks are keyed by Matrix `room_id`. Block entries must include `display_name` and may include `avatar_url` so the blacklist UI can show recognizable names instead of ids.
- The client hides blocked contacts, groups, channels, and matching conversation rows from normal lists. Unblock is only exposed from Settings -> Blacklist; ordinary contact/group/channel settings pages keep only the block action.
- Follow/favorite actions: `follows.*`, `favorites.*`. Flutter user-facing report screens use the signed imadmin `/im/report` boundary, not P2P `reports.submit`.
- Favorite message snapshots may include `sender_avatar_url`; the favorites UI uses it for the source sender avatar when present. Unified `favorites.add` sends media details inside a Matrix-style `content` snapshot so P2P responses can restore image/file URLs even when only `content` is persisted.
- Group actions: `groups.create`, `groups.update`, `groups.invite`, `groups.join`, `groups.list`, `groups.members`, `groups.leave`, `groups.dissolve`, member moderation, mute, and invite policy actions.
- `groups.invite` is surfaced to receivers as a Matrix room invite and may also appear in `sync.bootstrap.pending.group_invites`; it is not delivered as a private-chat invite message.
- `groups.members` returns visible members in backend order: owner first, then joined members by `joined_at`, then stable user id fallback. Group avatars and member grids use this order when available, with Matrix/local caches only as fallback.
- Channel actions: `channels.create`, `channels.update`, `channels.join`, `channels.invite_grant.create`, `channels.invite`, `channels.list`, `channels.members`, `channels.leave`, `channels.dissolve`, moderation, mute, read marker, public search/detail/join request, posts, comments, and reactions. Channel share cards always carry `channel_id`/`room_id` and never create invite grants; receivers request access through public join request using the Matrix `room_id`. `channels.invite_grant.create` is reserved for the owner member-list `+` invite flow outside the share button.
- `sync.bootstrap.pending.channel_notices` represents channel invitations for the current user. It is not the owner pending-review count; review badges and review lists must use joined owner channels plus pending channel members.
- Channel member responses may include `avatar_url`; member UIs use it before falling back to Matrix room member avatars.
- Channel post responses may include `author_avatar_url` for the post author. Post media still travels in `media`/`media_json`; the UI uses the first post image as the post-list thumbnail when present.
- Public channel join requests return `pending`, `rejected`, `approved`, `joining`, `joined`, or `join_failed`. Only `joined` is openable as a joined channel; `approved`/`joining` are still in-progress states.
- Channel join-request review actions return a top-level status with the same approval/join states. The client must preserve that top-level status; approving a request is not a successful join unless the returned status is `joined`.
- Public profile/channel extension action: `users.public_channels`. It returns the target user's owned/admin public channels, not channels where the target is only an ordinary member. Cross-node callers pass `remote_node_base_url` so the local AS can forward to the target owner node.
- Call actions: `calls.create`, `calls.incoming`, `calls.get`, `calls.event`, `calls.active`, `calls.list`. `calls.event` supports `connected`, `ended`, `rejected`, `missed`, and `failed`; WS `server.event` can push `call.changed` with `payload.call` so active call UI can show the other party rejected or hung up in real time. Outgoing direct calls time out after 60 seconds without connection, write P2P state `missed`, and send an `m.call.hangup` with `reason=invite_timeout` so the chat page shows an unconnected voice-call record and the receiver cannot join that call late.
- Agent actions: `agent.*`. Agent room header presence uses
  native Matrix room state in the real `agent_room_id`: event type
  `io.direxio.agent.status`, state key `@agent:<server>`, and content field
  `online`. `sync.bootstrap` only supplies the real `agent_room_id`; it does
  not mirror the online bit, and WS `server.event` does not emit
  `agent.presence`. Typing, thinking, and streaming reply generation are
  separate chat UI states. Agent settings use `agent.config.get/update` for
  `display_name`, `avatar_url`, `context_window`, and
  `mcp_blocked_room_ids`; blocked rooms are backend-enforced for MCP and should
  be presented as Agent read restrictions, not local-only UI state.
  `agent.status` and `agents.status` are not current client APIs.
- Sync strategy: use `sync.bootstrap` only for cold start, login recovery,
  corrupt local cache, unknown event fallback, or confirmed event gaps. Normal
  updates should create a `realtime.ws_ticket.create` ticket, connect
  `GET /_p2p/ws`, persist the last handled `seq`, send `client.ack`, and apply
  typed local reducers from WS `server.event` frames instead of full bootstrap
  refreshes.
- If WS emits `server.cursor_reset`, the client clears local product
  projection caches, runs one `sync.bootstrap` over WS, persists the response
  `max_seq` as the recovered cursor when present, and resumes deltas from that sequence.
  The cursor-reset control event itself must not advance `last_seq`.
- Foreground Matrix refreshes use `/sync` filters with a low timeline limit and
  `lazy_load_members=true`. Ordinary chat, media history, search, unread, local
  delete, and redaction remain Matrix Client-Server responsibilities.
- Foreground/background and current-room push context use WS frames:
  `client.lifecycle` reports foreground plus optional `state`, `hidden`, and
  `flags`; `client.focus` reports the currently opened room plus optional
  `focused` and `flags`; `client.ack` reports the latest handled event
  sequence. A foreground, non-hidden, same-room WS session suppresses push;
  background, hidden, disconnected, expired, no-focus, or different-room state
  keeps normal push behavior. Logged-in clients still write Matrix global
  account data `io.direxio.push.context` every 30 seconds as a migration
  fallback. The backend stamps session/account-data freshness with server time;
  the client must not send expiry timestamps.
- Channel post/comment list actions currently do not have a documented
  cursor/page contract. Client method signatures may keep local progressive
  loading parameters, but the HTTP client must not send uncontracted
  `limit`, `before_ts`, `page`, or `page_size` params until the backend
  contract is added.

## Matrix Responsibilities

- Login session and Matrix account identity.
- Room membership and timeline state.
- Ordinary text/media message send.
- Agent room conversation text, including `/` commands, uses ordinary Matrix
  message send into the real private `agent_room_id`. Agent replies come from
  `@agent:<server>` and may use Matrix edits, stream-fragment content, Markdown,
  or structured card fields. Clients must not depend on pseudo agent room ids.
  Agent online display reads `io.direxio.agent.status` from this room's Matrix
  state.
  Flutter slash-command shortcuts are local composer suggestions derived from
  the connect command surface as of `@direxio/connent@1.3.5`; choosing one only
  fills Matrix text and does not execute a local client command.
- Media upload/download.
- Message history via Matrix room messages.
- Message search via Matrix search.
- Local delete/clear through the Matrix `io.direxio` local visibility endpoint.
- Read markers and sync via Matrix `/sync`.
- Foreground/background/hidden/current-room push context via WS, with
  `io.direxio.push.context` retained as fallback.

## Bootstrap Privacy

- Bootstrap is metadata-only.
- Do not add historical read message bodies, `last_message`, or other message content fields to bootstrap.
- Unread, history, message bodies, message search, and ordinary recall remain Matrix responsibilities.

## Conversation And Channel Rules

- ProductCore conversations are the openable conversation source.
- UI must not reconstruct chat routes from names, member counts, or local placeholder ids when ProductCore denies or omits a conversation.
- Channel list uses P2P/bootstrap channel metadata for logged-in users.
- Channel search uses P2P room-id lookup only for Matrix room ids; other search text uses the signed IM public channel list.
- Channel member status must be normalized:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `approved` -> `approved`
  - `joining` -> `joining`
  - `join_failed` -> `join_failed`
  - `reject`, `rejected` -> `rejected`
- Only normalized `joined` unlocks channel sending.
- Channel list consumers hide terminal channel lifecycles: `deleted`, `left`,
  `dissolve`, and `dissolved`, even if stale membership still says `joined`.

## Test Doubles

- P2P API test doubles live in `test/support/` or in test files.
- Production code must not depend on test doubles or runtime fixture data.
