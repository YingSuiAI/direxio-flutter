# P2P Client Feature Inventory

Last updated: 2026-06-21

This document records the currently implemented client features and whether each module is backed by real Matrix/AS data, local-only state, or demo/mock data. Logged-in product views must prefer real Matrix/AS state; mock data is reserved for unauthenticated demos and tests.

## Status Legend

- Real: backed by Matrix SDK and/or AS Admin API.
- Real + local: backed by real data with local cache/preferences for UI-only state.
- Demo/test: intentionally mock when unauthenticated or under explicit test configuration.
- Partial: UI exists, but some data or platform behavior depends on backend/platform completion.

## Core And Authentication

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| App restore and redirect | `/restore`, `auth_provider.dart`, `app_router.dart` | Real | Restores Matrix session plus portal token. Transient SDK/network/portal refresh failures keep stored credentials and present a retryable logged-in shell; Matrix token rejection plus non-retryable AS auth 4xx expires the session. Newly refreshed Matrix tokens have a short retry window so stale in-flight 401s do not immediately send the user to login. |
| Portal discovery | `well_known_service.dart`, `/login`, `/setup/*` | Real | Uses owner well-known discovery and supports Matrix SDK HTTP wrapper clients. |
| Portal setup and first profile | `/init`, `/setup/scan`, `/setup/password` | Real | Completes owner setup through AS, then moves to home. |
| Token boundary | `as_client_provider.dart`, `matrix_token_refreshing_http_client.dart` | Real | Portal token is for AS Admin API; Matrix access token is for Matrix API only. Fallbacks are logged as warnings and should not be relied on. |
| Bootstrap cache | `as_bootstrap_store.dart`, `as_sync_cache_provider.dart` | Real + local | Caches AS bootstrap metadata and validates it belongs to the current user. |
| User action debounce | `PortalApp`, `user_action_debounce.dart` | Local | App-level pointer debounce blocks repeat taps for 500ms after a primary tap, preventing duplicate button-triggered API requests across pages, dialogs, and sheets. |

## Home, Messages, And Chat

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Home tabs | `/home`, `home_page.dart` | Real + demo | Logged-in messages/contacts/channels use real Matrix/AS data. Unauthenticated demo uses `MockData`. |
| Direct conversation list | `home_page.dart`, `home_conversation_snapshot_store.dart` | Real + local | Accepted contacts come from AS bootstrap; current display name/avatar prefer Matrix room member state. The home conversation list writes a local snapshot and renders it while Matrix rooms hydrate after app restart, then Matrix/AS incremental updates replace the cached row state. Locally hidden rows reappear when opened from contact detail or when new unread activity arrives. |
| Agent/system room | `chat_page.dart`, `agentStatusProvider` | Real + local | Agent is a system conversation, not a normal contact. Header reflects AS connection state. |
| Direct chat timeline | `/chat/:roomId`, `chat_page.dart` | Real | Uses Matrix room/timeline for text, media, unread, history, redaction, and local delete behavior; opening a concrete chat may request the first Matrix history page to refill the local SQLite timeline. Bootstrap stays metadata-only. |
| Group/channel chat timeline | `/group/:roomId`, `/channel/:id/conversation`, `group_chat_page.dart` | Real | Supports Matrix timeline, Matrix SDK text/media send, quote/reply metadata, mentions, local outbox, redaction/local delete, and read state. Opening a concrete group/channel conversation may request the first Matrix history page to refill the local SQLite timeline. Bootstrap stays metadata-only. |
| Reply/quote rendering | `group_chat_page.dart` | Real | Sends Matrix `m.relates_to` reply metadata and keeps product-compatible quote fields in Matrix content. |
| Message privacy clearing | `chat_clear_state_provider.dart`, `matrix_message_visibility_client.dart` | Real + local | Calls Matrix `io.direxio` local delete/clear and records local clear boundaries without redacting server messages. |
| Room search | `/room-search/:roomId` | Real | Searches room messages through Matrix `/search`. |

## Contacts, Follows, And Requests

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Contacts tab | `home_page.dart` | Real + demo | Logged-in contacts come from AS bootstrap; demo uses mock contacts. |
| Add contact | `/add-contact`, `add_contact_page.dart` | Real | Resolves portal domain/URL queries and opens detail or verification flow. If owner well-known still returns the default localpart name, the client queries Matrix profile once as a display-name fallback. |
| Contact detail and verification | `/add-contact/detail/:userId`, `/add-contact/verify/:userId` | Real + demo | Sends AS contact requests; unauthenticated examples use mock identities. |
| Friend/group/channel pending requests | `/requests`, `requests_page.dart` | Real | Uses AS pending state and Matrix native direct profile metadata; new direct invites do not require legacy `p2p.contact.request`. AS `pending.group_invites` are discoverable from the New Friends entry and can be accepted through AS group join. |
| Visitor home | `/contact-home/:userId`, `contact_home_page.dart` | Real + demo | Shows follow state, friend state, public channels, and dynamics. Demo data is used only when not logged in. |
| Delete contact | `contact_home_page.dart`, `contact_detail_page.dart` | Real | Calls AS delete, removes local Matrix room immediately, then refreshes bootstrap best-effort. |
| Follows list | `/follows`, `follows_list_page.dart` | Real + demo | Logged-in follows come from AS; demo follows route to visitor home. |
| Blacklist | `/settings/blacklist`, `blacklist_page.dart` | Local UI | UI exists for address-book blacklist entry; backend persistence should be confirmed before treating it as server-enforced. |

## Groups

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Create group | Home plus menu, `group_creation_flow.dart` | Real | Uses accepted AS contacts, calls AS group invite for selected contacts after creation, and opens the created Matrix room. |
| Group list | `/groups`, `groups_list_page.dart` | Real | Uses AS bootstrap groups and excludes stale direct metadata. Pending group invitations remain in `/requests` until accepted and projected into bootstrap groups. Existing group member invitations are sent as direct-chat cards after the owner node records invited MXIDs; card joins are accepted only for recorded invitees. |
| Group chat | `/group/:roomId`, `group_chat_page.dart` | Real | Matrix timeline with Matrix SDK text send, media outbox, mentions, quote, recall/delete where supported. |
| Group detail/info/manage | `/group-detail/:roomId`, `/group-info/:roomId`, `/group-manage/:roomId` | Real | Uses AS group metadata for invite policy, profile, member management, leave/dissolve flows. |
| Missing group handling | `group_chat_page.dart` | Real | Missing room page keeps a usable back button; recovery is only attempted when AS bootstrap confirms the group. |

## Channels

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Channel tab | Home tab 3, `channel_home_tab.dart` | Real + demo | Logged-in channel list uses `AsSyncBootstrap.channels`; unauthenticated demo uses mock channels. |
| Channel search | `/channels/search`, `channel_search_page.dart` | Real | Uses AS public search. Matrix room id lookup stays on the configured AS; remote node inference is not allowed. |
| Create channel | Home plus menu / channel FAB, `create_channel_sheet.dart` | Real | Calls AS create; owner semantics belong to portal owner. |
| Channel detail/join | `/channel/:id/detail`, `channel_detail_info_page.dart` | Real | Join request handles `pending`, `invite`, and `joined`. UI shows an in-progress state while waiting and opens chat/detail only after joined projection. |
| Channel chat | `/channel/:id/conversation`, `group_chat_page.dart` | Real | Chat channels are Matrix rooms with channel metadata; joined members send normal text through Matrix SDK and server ProductPolicy enforces the send gate. Sending is still blocked until AS/Matrix membership is `joined`. |
| Channel posts | `/channel/:id`, `/channel/:id/post/create`, `/channel/:id/post/:postId` | Partial | UI and local post store exist; confirm production AS persistence before relying on cross-device post state. |
| Channel review | `/channels/review`, `ChannelReviewPage` | Real + demo | Logged-in owners/admins load pending members from AS; unauthenticated demo shows local review samples. Approval now returns `invite` until Matrix join projection. |
| Channel management | `/channels/manage`, `/channels/manage/:channelId` | Partial | Management UI exists; server-side enforcement depends on AS channel metadata endpoints. |

## Calls And Media

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Direct voice/video call | `/call/:roomId`, `/video-call/:roomId`, `call_page.dart` | Partial | UI and AS call sessions are implemented; full behavior depends on platform media permissions and Matrix/VoIP runtime. |
| Group voice/video call | `/group-call/:roomId`, `/group-video-call/:roomId`, `group_call_page.dart` | Partial | Group call lifecycle, invite selection, AS call history merge, and autotest routing exist. Platform media remains runtime-dependent. |
| Media send/download | `chat_media_send_flow.dart`, `product_room_media_send_flow.dart` | Real + local | Uses Matrix upload/download and Matrix `m.room.message` send for normal chat media; local outbox records failures. Channel post/comment product content must carry `p2p_kind=channel_post` or `p2p_kind=channel_comment` when projected. |
| Thumbnail/media cache | `matrix_media_cache_provider.dart`, `media_thumbnail_cache_provider.dart` | Real + local | Local cache optimization only; server media remains canonical. |

## Search, Profile, And Personal Space

| Module | Routes / files | Status | Notes |
|---|---|---|---|
| Global search | `/search`, `search_page.dart` | Real | Uses Matrix `/search` for message hits and local Matrix/AS metadata for contacts, groups, and channels. |
| Owner profile | `/me/profile`, `profile_info_page.dart` | Real | Updates AS owner profile and best-effort Matrix display name/avatar. AS update is not rolled back if Matrix sync is unavailable. |
| Me tab | Home tab 4, `me_home_tab.dart` | Real + demo | Shows profile, UID QR entry, owned channel entry, and dynamic timeline. Personal-space feed uses provider data. |
| QR code | `/me/qr`, `me_qr_page.dart` | Real | Shows current owner/domain identity for sharing. |
| Favorites/likes/comments/drafts/history | `/me/*`, `me_menu_page.dart` | Partial | Pages and local/mock content exist. AS-backed favorites/comments/reactions exist in `AsClient`; verify backend persistence before marking every list fully real. |
| Notifications/settings | `/settings`, `/me/notifications` | Real + local | Preferences are local Riverpod/local-store state unless backed by a platform service. |
| Theme/language | `app_theme_provider.dart`, `app_locale_provider.dart` | Local | User preference state; UI follows Material 3 tokens. |
| MCP permissions | `/mcp-permission`, `/mcp-permission/:agentId` | Demo/local | Mock permission/policy stores exist for UI flow. Server-backed Agent/MCP policy should be verified before production use. |

## Verification Snapshot

As of this update:

- `flutter analyze --no-pub` passes.
- `flutter test --no-pub` passes, 844 tests.
- Focused contract/UI checks pass: `test/channel_page_real_test.dart test/channel_inbox_data_test.dart test/http_as_client_test.dart`, `test/widget_test.dart --plain-name channel`, and `test/widget_test.dart --plain-name "global search"`.
- Targeted tests cover Matrix message search/local delete clients, channel invite grants, channel member status normalization, channel send gating, profile/contact refresh, group invite cards, group quote behavior, friend/contact deletion, group/channel member management, channel mute, and group/channel leave or dissolve flows.
