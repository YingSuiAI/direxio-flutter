# Direxio Client Feature Status

Last verified from current code: 2026-06-22

This document is a current implementation inventory. It is not a roadmap and does not preserve historical plans.

## Real Data Surfaces

- Authentication/session restore uses Matrix SDK session state plus the persisted portal token.
- Home conversations use ProductCore conversations, Matrix rooms, and local summary snapshots only as startup cache.
- Direct/group/channel chat uses Matrix timelines for text, media, history, read state, local delete, and search.
- Removed or exited group conversations stay visible in home conversations and Contacts -> Groups as read-only history; opening them shows the exited-group send block.
- Contacts, follows, pending requests, group metadata, channel metadata, public profiles, and public channel lists use the integrated P2P product API/bootstrap actions.
- Group invite visibility uses Matrix room invites and `sync.bootstrap.pending.group_invites`; private chat invite messages are not the receiver contract.
- Channel search uses the P2P public search action. Remote node URLs must be request-provided; the client must not infer a remote P2P URL from a Matrix room id.
- Contact public channels use the `users.public_channels` action through `getUserPublicChannels`.
- Owner profile updates go through the P2P product API and best-effort Matrix profile update.
- Settings, theme, language, hidden/pinned rows, and media caches are local state unless a named AS/Matrix API handles that feature.

## Partial Or Local Surfaces

- Channel posts/comments/reactions have UI and P2P client contracts; production behavior depends on backend persistence.
- Voice/video call UI and P2P call session flows exist; runtime behavior depends on platform permissions and Matrix/WebRTC availability. Active calls consume `call.changed` P2P events for realtime rejected/hangup status.
- Favorites, likes, comments, drafts, and history pages have UI paths and partial AS/local backing. Treat each list as real only where the code calls AS/Matrix directly.
- Android offline push registers an FCM token as a Matrix HTTP pusher after login. The production gateway is `https://push.direxio.ai/_matrix/push/v1/notify`; local HTTP is allowed only for local development hosts.
- MCP permission UI is local until wired to a server-backed policy endpoint.
- Blacklist UI is local until server enforcement is implemented.

## Removed Runtime Fallbacks

- Runtime UI must not hydrate contacts, groups, channels, messages, avatars, or profiles from placeholder fixture data.
- Runtime fixture-data directories are not part of the app.
- Test doubles remain allowed in `test/support/` and individual tests.

## Current Product Identity

- Display name: `Direxio`
- Android package/application id: `com.direxio.ai`
- Flutter package/import namespace: `portal_app`
