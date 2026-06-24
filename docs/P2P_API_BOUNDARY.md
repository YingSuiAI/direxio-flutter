# Direxio Client API Boundary

Last verified from current code: 2026-06-23

This document records the current P2P product API / Matrix boundary used by the Flutter client. It intentionally omits historical change logs.

## Token Boundary

- P2P product API calls use the portal token as bearer auth.
- Matrix Client-Server API calls use the Matrix access token managed by the Matrix SDK.
- P2P product API clients must use a `/_p2p` base URI and send action envelopes to `/_p2p/query` or `/_p2p/command`.
- Matrix access tokens are never a fallback credential for P2P product API calls.
- After `portal.password` succeeds, persist the new login password and new P2P bearer token before any Matrix or P2P follow-up request can refresh authentication.
- When login or password changes rotate the bearer token, delayed Matrix or P2P `M_UNKNOWN_TOKEN` responses from the previous token must not expire a session that has already applied the newer token.

## P2P Product API Responsibilities

- Requests use `POST /_p2p/query` or `POST /_p2p/command` with an `action` and `params` body.
- Portal actions: `portal.bootstrap`, `portal.auth`, `portal.status`, `portal.password`.
- Bootstrap metadata action: `sync.bootstrap` for contacts, groups, channels, pending requests, user profile, and product summaries.
- Conversation actions: `conversations.list`, `conversations.get`.
- Contact actions: `contacts.list`, `contacts.request`, `contacts.reactivate`, `contacts.requests.accept`, `contacts.requests.reject`, `contacts.requests.delete`, `contacts.update`, `contacts.delete`.
- Contact request remarks travel as `remark` on `contacts.request` and may be mirrored in contact or `sync.bootstrap.pending.friend_requests` metadata for the verifier UI.
- Accepted-contact remark updates use `contacts.update` with `room_id` and `display_name`; the backend stores the remark as the contact `display_name`, not as a separate `remark` field.
- Contact identity writes preserve the peer profile: `contacts.request`, `contacts.requests.accept`, and `contacts.update` may send `display_name`, `avatar_url`, and `domain`; `ContactEntry` reads `avatar_url` back for contact and direct-conversation caches.
- Follow/favorite/report actions: `follows.*`, `favorites.*`, `reports.submit`.
- Favorite message snapshots may include `sender_avatar_url`; the favorites UI uses it for the source sender avatar when present. Unified `favorites.add` sends media details inside a Matrix-style `content` snapshot so P2P responses can restore image/file URLs even when only `content` is persisted.
- Group actions: `groups.create`, `groups.update`, `groups.invite`, `groups.join`, `groups.list`, `groups.members`, `groups.leave`, `groups.dissolve`, member moderation, mute, and invite policy actions.
- `groups.invite` is surfaced to receivers as a Matrix room invite and may also appear in `sync.bootstrap.pending.group_invites`; it is not delivered as a private-chat invite message.
- Channel actions: `channels.create`, `channels.update`, `channels.join`, `channels.invite_grant.create`, `channels.invite`, `channels.list`, `channels.members`, `channels.leave`, `channels.dissolve`, moderation, mute, read marker, public search/detail/join request, posts, comments, and reactions.
- `sync.bootstrap.pending.channel_notices` represents channel invitations for the current user. It is not the owner/admin pending-review count; review badges and review lists must use joined owner/admin channels plus pending channel members.
- Channel member responses may include `avatar_url`; member UIs use it before falling back to Matrix room member avatars.
- Channel post responses may include `author_avatar_url` for the post author. Post media still travels in `media`/`media_json`; the UI uses the first post image as the post-list thumbnail when present.
- Public channel join requests return `pending`, `rejected`, `approved`, `joining`, `joined`, or `join_failed`. Only `joined` is openable as a joined channel; `approved`/`joining` are still in-progress states.
- Channel join-request review actions return a top-level status with the same approval/join states. The client must preserve that top-level status; approving a request is not a successful join unless the returned status is `joined`.
- Public profile/channel extension action: `users.public_channels`.
- Call actions: `calls.create`, `calls.incoming`, `calls.get`, `calls.event`, `calls.active`, `calls.list`. `calls.event` supports `connected`, `ended`, `rejected`, `missed`, and `failed`; `GET /_p2p/events` can push `call.changed` with `payload.call` so active call UI can show the other party rejected or hung up in real time. Outgoing direct calls time out after 60 seconds without connection, write P2P state `missed`, and send an `m.call.hangup` with `reason=invite_timeout` so the chat page shows an unconnected voice-call record and the receiver cannot join that call late.
- Agent/API actions: `agent.*` and `apis.*`.

## Matrix Responsibilities

- Login session and Matrix account identity.
- Room membership and timeline state.
- Ordinary text/media message send.
- Media upload/download.
- Message history via Matrix room messages.
- Message search via Matrix search.
- Local delete/clear through the Matrix `io.direxio` local visibility endpoint.
- Read markers and sync via Matrix `/sync`.

## Bootstrap Privacy

- Bootstrap is metadata-only.
- Do not add historical read message bodies, `last_message`, or other message content fields to bootstrap.
- Unread, history, message bodies, message search, and ordinary recall remain Matrix responsibilities.

## Conversation And Channel Rules

- ProductCore conversations are the openable conversation source.
- UI must not reconstruct chat routes from names, member counts, or local placeholder ids when ProductCore denies or omits a conversation.
- Channel list uses P2P/bootstrap channel metadata for logged-in users.
- Channel search uses P2P public search.
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
