# Direxio Client Feature Status

Last verified from current code: 2026-07-02

This document is a current implementation inventory. It is not a roadmap and does not preserve historical plans.

## Real Data Surfaces

- Authentication/session restore uses Matrix SDK session state plus the persisted `access_token`; initialization is complete once the generated initial password has been changed. Runtime current-token rejection signs the user out, clears saved login secrets, shows the session-expired dialog, and requires manual password entry before logging in again.
- Home conversations use ProductCore direct/group conversations, Matrix rooms, and local summary snapshots only as startup cache. Channel conversations stay under the channel surfaces.
- Direct/group/channel chat uses Matrix timelines for text, media, history, read state, local delete, and search, and opens at the latest visible message by default unless a target message is requested.
- Agent chat opens the real private Matrix `agent_room_id`, sends ordinary text and `/` commands as Matrix text, renders Agent Markdown/cards, projects Matrix edits, SDK-aggregated edits, or stream fragments into one in-progress reply, typewrites appended reply updates, and offers localized `/` command shortcuts in the composer.
- Agent conversation headers read user-facing availability from the real agent room Matrix state event `io.direxio.agent.status` (`online`). `sync.bootstrap` only supplies the real `agent_room_id`. The chat header only displays localized online/offline labels: `commonOnline` when the Agent state is online and `commonOffline` otherwise; unknown, connecting, and error states are not shown as separate user-facing labels.
- Agent chat headers expose an Agent settings entry. The settings page reads and updates `agent.config`, including Agent nickname, uploaded `avatar_url`, and `mcp_blocked_room_ids`; avatar editing uses the same image picker/crop/upload flow as user profile avatars, and the room picker is populated from current direct/group/channel conversations with already blocked rooms selected.
- Channel message rooms are muted by default for local sound/vibration notifications, and channel list items show unread presence as a red dot rather than an unread count.
- Removed or exited group conversations stay visible in home conversations and Contacts -> Groups as read-only history; opening them shows the exited-group send block.
- Contacts, follows, pending requests, group metadata, channel metadata, public profiles, and public channel lists use the integrated P2P product API/bootstrap actions.
- User blacklists use the integrated P2P `blocks.*` actions for contacts only. Blocked friends and matching direct conversation rows are hidden from normal lists; other routes into blocked contacts or direct rooms are intercepted with an already-blocked prompt. Settings -> Blacklist shows blocked contacts with display names and is the only unblock entry.
- Group invite visibility uses Matrix room invites and `sync.bootstrap.pending.group_invites`; private chat invite messages are not the receiver contract.
- Channel search uses Matrix-room-id lookup for room ids and the signed IM public `/im/channel/list` endpoint for other search text. Public channel tags come from signed `/im/tag/public/list` and are cached locally for one day; public channel list entries preserve `tag_id`, `rating_count`, and `average_score`.
- Public channel creation registers the channel in the signed IM public directory, and channel dissolve closes it there.
- User, group, and channel reports use the signed IM public `/im/report` endpoint. Report screenshots/images are sent as multipart `files`.
- BI startup reporting uses the signed IM public `/bi/events/report` endpoint with a stored device number.
- Channel shares from owners and ordinary members send recommendation cards with the channel id and Matrix room id. Receivers open the public channel detail from the Matrix room id and apply through the public join request flow.
- Channel owner member-list invites use the `+` entry, create an invite grant for the selected direct chat, and send a channel card that lets the receiver join directly.
- Contact public channels use the `users.public_channels` action through `getUserPublicChannels`; remote add-contact/profile entry points pass the target owner node base for cross-node lookup.
- Owner profile updates go through the P2P product API and best-effort Matrix profile update.
- Settings, theme, language, hidden/pinned rows, and media caches are local state unless a named P2P/Matrix API handles that feature.

## Partial Or Local Surfaces

- Channel posts/comments/reactions have UI and P2P client contracts; production behavior depends on backend persistence.
- Voice/video call UI and P2P call session flows exist; runtime behavior depends on platform permissions and Matrix/WebRTC availability. Video call controls support front/rear camera switching when a local video track is available. Active calls consume `call.changed` P2P events for realtime rejected/hangup status.
- Favorites, likes, comments, drafts, and history pages have UI paths and partial P2P/local backing. Treat each list as real only where the code calls P2P/Matrix directly.
- Offline push registers a platform token as a Matrix HTTP pusher after login: Android uses FCM with app id `com.direxio.ai`, and iOS uses APNs with app id `com.direxio.app`. The production gateway is `https://push.direxio.ai/_matrix/push/v1/notify`; local HTTP is allowed only for local development hosts. Logged-in clients report lifecycle, hidden/background flags, current room, and handled sequence over the realtime WS stream (`client.lifecycle`, `client.focus`, `client.ack`), while Matrix global account data `io.direxio.push.context` remains a 30-second heartbeat fallback during migration. The server applies 60-second freshness using server time and suppresses system push only for a foreground, non-hidden session focused on the same room; other rooms and hidden/background/disconnected state still push. Message pushes are grouped locally by `room_id`; repeated pushes for the same direct chat or group update one visible notification with the latest unread or local pending count. Notification taps open the pushed `room_id` in the matching direct, group, text-channel, or call route when the gateway supplies Direxio routing metadata. Channel post pushes are ignored.
- MCP permission list/status UI is local-only; server-backed MCP room blacklist editing lives under Agent settings through `agent.config.mcp_blocked_room_ids`.

## Removed Runtime Fallbacks

- Runtime UI must not hydrate contacts, groups, channels, messages, avatars, or profiles from placeholder fixture data.
- Legacy direct routes and management surfaces, including blacklist and channel management member/moderation views, render real empty states when no backend/source data is available.
- Runtime fixture-data directories are not part of the app.
- Test doubles remain allowed in `test/support/` and individual tests.

## Current Product Identity

- Display name: `Direxio`
- Android package/application id: `com.direxio.ai`
- iOS bundle id: `com.direxio.app`
- Flutter package/import namespace: `portal_app`
