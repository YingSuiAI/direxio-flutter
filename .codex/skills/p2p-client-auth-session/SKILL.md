---
name: p2p-client-auth-session
description: Authentication and session workflow for the Flutter P2P client. Use for login, setup/bootstrap, portal discovery, restore, route guards, credential storage, Matrix/AS token handling, auth providers, or session-expiry behavior.
---

# P2P Client Auth Session

## Required Reads

Read these before auth/session work:

- `AGENTS.md`
- `docs/FEATURES.md`
- `docs/P2P_API_BOUNDARY.md` when P2P auth or portal/session shapes change

If the change touches `lib/presentation/`, also load `p2p-client-presentation-m3`.

## Auth Boundaries

Keep P2P product API auth and Matrix SDK auth responsibilities explicit. Backend auth responses expose one `access_token`; P2P calls should use it as the bearer credential, and Matrix-native login/session, room, timeline, membership, media, profile, and read-marker behavior should flow through Matrix SDK or Matrix API code using the same token.

Do not add ad hoc token fallbacks or separate token fields such as `product_token`, `matrix_token`, `product_access_token`, or `matrix_access_token`. If the backend changes the token shape, update `AsClient`, `HttpAsClient`, test doubles, auth providers, focused tests, and `docs/P2P_API_BOUNDARY.md` together.

Portal bootstrap, password auth, and owner profile updates are P2P product-layer concerns. `initialized` is the only initialization flag and means the generated initial password has been changed; owner profile setup must not gate initialization.

Only confirmed credential rejection should expire a restored session. Transient SDK/network restore failures should keep stored credentials and present a retryable logged-in shell when that is the current product behavior.

After login or portal-token refresh applies a new Matrix access token, do not
expire the session because of stale in-flight Matrix 401s from the old token.
Use the current-token check and the short recent-token retry window before
sending the user back to login.

After `portal.password` succeeds, persist the new login password and new AS
bearer token before any Matrix or AS follow-up request can trigger auth refresh.
From that point, the old password must not be used for `portal.auth`.

After login or password change rotates the P2P/AS bearer token, do not expire
the session because of stale in-flight AS `M_UNKNOWN_TOKEN` responses from the
old bearer. AS clients should report the rejected bearer token so auth state can
compare it with the current token before clearing local session state.

When a Matrix token rejection triggers portal-token refresh, do not clear local
session state if the portal refresh fails due to timeout, network, or 5xx
server errors. Keep the stored Matrix/portal credentials and retry later; only
non-retryable AS auth rejection such as 4xx should expire the restored session.

On iOS, direct app uninstall/reinstall must not restore stale Keychain login
state. Use non-Keychain app-local install state to detect a fresh install and
clear old secure session credentials before auth restore. Normal logout must
also clear secure session credentials and return to the login route.

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
