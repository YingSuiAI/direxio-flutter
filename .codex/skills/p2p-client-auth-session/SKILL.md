---
name: p2p-client-auth-session
description: Authentication and session workflow for the Flutter P2P client. Use for login, setup/bootstrap, portal discovery, restore, route guards, credential storage, Matrix/AS token handling, auth providers, or session-expiry behavior.
---

# P2P Client Auth Session

## Required Reads

Read these before auth/session work:

- `AGENTS.md`
- `docs/FEATURES.md`
- `docs/AS_API_CHANGES.md` when AS auth or portal/session shapes change

If the change touches `lib/presentation/`, also load `p2p-client-presentation-m3`.

## Auth Boundaries

Keep AS/Admin API auth and Matrix SDK auth responsibilities explicit. AS calls should use the current portal/session bearer credential from the AS contract. Matrix-native login/session, room, timeline, membership, media, profile, and read-marker behavior should flow through Matrix SDK or Matrix API code.

Do not add ad hoc token fallbacks. If the backend changes the token shape, update `AsClient`, `HttpAsClient`, `MockAsClient`, auth providers, focused tests, and `docs/AS_API_CHANGES.md` together.

Portal setup/bootstrap, portal token auth, and owner profile setup are AS product-layer concerns.

Only confirmed credential rejection should expire a restored session. Transient SDK/network restore failures should keep stored credentials and present a retryable logged-in shell when that is the current product behavior.

After login or portal-token refresh applies a new Matrix access token, do not
expire the session because of stale in-flight Matrix 401s from the old token.
Use the current-token check and the short recent-token retry window before
sending the user back to login.

## Implementation Pattern

Keep route guards and redirect behavior in `lib/core/router/`.

Keep auth/session state in `lib/presentation/providers/`.

Keep HTTP/session contracts in `lib/data/`.

Logged-in routes must prefer real Matrix/AS data and real empty states. Do not mask auth/session failures with mock data.

## Verification

Run:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/auth_provider_test.dart
```

Also run any touched provider/router tests and at least one login or restore widget path.
