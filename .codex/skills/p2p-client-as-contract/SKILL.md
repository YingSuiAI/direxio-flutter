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

Use AS Admin API only for product-layer data Matrix does not model cleanly: setup/bootstrap, portal auth, unread recovery overlay, follows, friend requests, group/channel metadata, public profile extensions, calls, Agent/MCP state, and product search.

Do not add duplicate list APIs or duplicate client flows. If data already arrives through `/_as/sync/bootstrap`, prefer extending that contract and the client model.

Keep `/_as/sync/bootstrap` metadata-only. Do not add historical read message bodies, `last_message`, or other message content fields.

Keep auth responsibilities explicit. AS Admin API calls use the current portal/session bearer credential defined by the contract; Matrix-native behavior should still flow through the Matrix SDK or Matrix API layer.

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

Public remote channel lookup must use explicitly configured AS remotes or request-provided remote base URLs. Do not infer a remote AS URL from a Matrix `room_id` domain unless the current contract document explicitly says to derive and pass a concrete remote base URL.

`portal.status` may use the unified shape: `initialized`, `user_id`, `homeserver`, `store_mode`, `projector_started`.

## Verification

Run:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/http_as_client_test.dart
```

Add relevant provider/widget tests for each consumer touched by the contract change.
