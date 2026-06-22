# Direxio Client API Boundary

Last verified from current code: 2026-06-22

This document records the current AS/Matrix boundary used by the Flutter client. It intentionally omits historical change logs.

## Token Boundary

- AS Admin API calls use the portal token as bearer auth.
- Matrix Client-Server API calls use the Matrix access token managed by the Matrix SDK.
- Code paths that temporarily fall back to Matrix token for AS are compatibility warnings, not the intended contract.

## AS Admin API Responsibilities

- Portal setup, portal auth, portal password, portal status.
- `/_as/sync/bootstrap` metadata for contacts, groups, channels, pending requests, user profile, and product summaries.
- Contact request/update/delete.
- Follow/unfollow and public profile extensions.
- Group create/join/invite/member/profile/leave/dissolve operations.
- Channel create/search/join/invite-grant/member/mute/profile operations.
- Channel post/comment/reaction product data where implemented by backend.
- Agent/MCP status and product policy surfaces where implemented.

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
- UI must not reconstruct chat routes from names, member counts, or local mock ids when ProductCore denies or omits a conversation.
- Channel list uses AS/bootstrap channel metadata for logged-in users.
- Channel search uses AS public search.
- Channel member status must be normalized:
  - `join`, `joined` -> `joined`
  - `invite`, `invited` -> `invite`
  - `pending` -> `pending`
  - `reject`, `rejected` -> `rejected`
- Only normalized `joined` unlocks channel sending.

## Test Doubles

- AS test doubles live in `test/support/` or in test files.
- Production code must not depend on test doubles or runtime mock data.
