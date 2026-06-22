# Direxio Client API Boundary

Last verified from current code: 2026-06-22

This document records the current P2P product API / Matrix boundary used by the Flutter client. It intentionally omits historical change logs.

## Token Boundary

- P2P product API calls use the portal token as bearer auth.
- Matrix Client-Server API calls use the Matrix access token managed by the Matrix SDK.
- Code paths that temporarily fall back to Matrix token for P2P product API calls are compatibility warnings, not the intended contract.

## P2P Product API Responsibilities

- Requests use `POST /_p2p/query` or `POST /_p2p/command` with an `action` and `params` body.
- Portal actions: `portal.bootstrap`, `portal.auth`, `portal.status`, `portal.password`.
- Bootstrap metadata action: `sync.bootstrap` for contacts, groups, channels, pending requests, user profile, and product summaries.
- Contact actions: `contacts.list`, `contacts.request`, `contacts.reactivate`, `contacts.requests.accept`, `contacts.requests.reject`, `contacts.requests.delete`, `contacts.update`, `contacts.delete`.
- Follow/favorite/report actions: `follows.*`, `favorites.*`, `reports.submit`.
- Group actions: `groups.create`, `groups.update`, `groups.invite`, `groups.join`, `groups.list`, `groups.members`, `groups.leave`, `groups.dissolve`, member moderation, mute, and invite policy actions.
- Channel actions: `channels.create`, `channels.update`, `channels.join`, `channels.invite_grant.create`, `channels.invite`, `channels.list`, `channels.members`, `channels.leave`, `channels.dissolve`, moderation, mute, read marker, public search/detail/join request, posts, comments, and reactions.
- Channel post responses may include `author_avatar_url` for the post author. Post media still travels in `media`/`media_json`; the UI uses the first post image as the post-list thumbnail when present.
- Public channel join requests return `pending`, `rejected`, `approved`, `joining`, `joined`, or `join_failed`. Only `joined` is openable as a joined channel; `approved`/`joining` are still in-progress states.
- Public profile/channel extension action: `users.public_channels`.
- Call actions: `calls.create`, `calls.incoming`, `calls.get`, `calls.event`, `calls.active`, `calls.list`.
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
