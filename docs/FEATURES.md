# Direxio Client Feature Status

Last verified from current code: 2026-06-22

This document is a current implementation inventory. It is not a roadmap and does not preserve historical plans.

## Real Data Surfaces

- Authentication/session restore uses Matrix SDK session state plus the persisted portal token.
- Home conversations use ProductCore conversations, Matrix rooms, and local summary snapshots only as startup cache.
- Direct/group/channel chat uses Matrix timelines for text, media, history, read state, local delete, and search.
- Contacts, follows, pending requests, group metadata, channel metadata, public profiles, and public channel lists use AS Admin API/bootstrap.
- Channel search uses AS public search. Remote node URLs must be request-provided; the client must not infer a remote AS URL from a Matrix room id.
- Contact public channels use AS `getUserPublicChannels`.
- Owner profile updates go through AS and best-effort Matrix profile update.
- Settings, theme, language, hidden/pinned rows, and media caches are local state unless a named AS/Matrix API handles that feature.

## Partial Or Local Surfaces

- Channel posts/comments/reactions have UI and AS client contracts; production behavior depends on backend persistence.
- Voice/video call UI and AS call session flows exist; runtime behavior depends on platform permissions and Matrix/WebRTC availability.
- Favorites, likes, comments, drafts, and history pages have UI paths and partial AS/local backing. Treat each list as real only where the code calls AS/Matrix directly.
- MCP permission UI is local/demo unless wired to a server-backed policy endpoint.
- Blacklist UI is local until server enforcement is implemented.

## Removed Runtime Fallbacks

- Logged-in views must not hydrate contacts, groups, channels, messages, avatars, or profiles from runtime mock data.
- Runtime mock data files under `lib/presentation/mock/` are not part of the current app.
- Test doubles remain allowed in `test/support/` and individual tests.

## Current Product Identity

- Display name: `Direxio`
- Android package/application id: `com.direxio.ai`
- Flutter package/import namespace: `portal_app`
