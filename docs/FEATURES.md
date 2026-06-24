# Direxio Client Feature Status

Last verified from current code: 2026-06-22

This document is a current implementation inventory. It is not a roadmap and does not preserve historical plans.

## Real Data Surfaces

- Authentication/session restore uses Matrix SDK session state plus the persisted `access_token`; initialization is complete once the generated initial password has been changed.
- Home conversations use ProductCore direct/group conversations, Matrix rooms, and local summary snapshots only as startup cache. Channel conversations stay under the channel surfaces.
- Direct/group/channel chat uses Matrix timelines for text, media, history, read state, local delete, and search.
- Removed or exited group conversations stay visible in home conversations and Contacts -> Groups as read-only history; opening them shows the exited-group send block.
- Contacts, follows, pending requests, group metadata, channel metadata, public profiles, and public channel lists use the integrated P2P product API/bootstrap actions.
- Group invite visibility uses Matrix room invites and `sync.bootstrap.pending.group_invites`; private chat invite messages are not the receiver contract.
- Channel search uses Matrix-room-id lookup for room ids and the signed IM public `/im/channel/list` endpoint for other search text.
- Public channel creation registers the channel in the signed IM public directory, and channel dissolve closes it there.
- User, group, and channel reports use the signed IM public `/im/report` endpoint. Report screenshots/images are sent as multipart `files`.
- BI startup reporting uses the signed IM public `/bi/events/report` endpoint with a stored device number.
- Channel shares from owners and ordinary members send recommendation cards with the channel id and Matrix room id. Receivers open the public channel detail from the Matrix room id and apply through the public join request flow.
- Channel owner member-list invites use the `+` entry, create an invite grant for the selected direct chat, and send a channel card that lets the receiver join directly.
- Contact public channels use the `users.public_channels` action through `getUserPublicChannels`.
- Owner profile updates go through the P2P product API and best-effort Matrix profile update.
- Settings, theme, language, hidden/pinned rows, and media caches are local state unless a named P2P/Matrix API handles that feature.

## Partial Or Local Surfaces

- Channel posts/comments/reactions have UI and P2P client contracts; production behavior depends on backend persistence.
- Voice/video call UI and P2P call session flows exist; runtime behavior depends on platform permissions and Matrix/WebRTC availability. Active calls consume `call.changed` P2P events for realtime rejected/hangup status.
- Favorites, likes, comments, drafts, and history pages have UI paths and partial P2P/local backing. Treat each list as real only where the code calls P2P/Matrix directly.
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
