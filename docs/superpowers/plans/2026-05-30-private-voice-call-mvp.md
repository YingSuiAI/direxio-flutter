# Private Voice Call MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable real 1:1 voice calls for accepted private chats in the Flutter client. The call must use Matrix VoIP signaling and WebRTC media, show correct outgoing/incoming state, and avoid presenting mock call UI as working functionality.

**Architecture:** Add one Riverpod-managed Matrix VoIP controller for the logged-in Matrix client. The controller owns the `VoIP` instance, WebRTC delegate, active `CallSession`, and UI-facing call state. Logged-in app shell initializes the controller so incoming calls can be received even when the call page is not open. Chat pages route private calls with an explicit peer MXID; the call page starts or answers the active session through the controller.

**Tech Stack:** Flutter, Riverpod, go_router, matrix SDK VoIP, flutter_webrtc, webrtc_interface, Material 3 local tokens.

---

- [x] Add a testable voice call controller abstraction.
  - [x] Define UI call states: idle, calling, ringing, connecting, connected, ended, failed.
  - [x] Map Matrix `CallState` into product UI states.
  - [x] Expose outgoing start, answer, reject, hangup, and mute actions.

- [x] Implement Matrix VoIP/WebRTC integration.
  - [x] Initialize `VoIP(client, delegate)` once per logged-in Matrix client.
  - [x] Delegate WebRTC creation to `flutter_webrtc`.
  - [x] Track incoming calls via `handleNewCall`.
  - [x] Reject or mark missed calls when another active call is already running.

- [x] Wire global logged-in lifecycle.
  - [x] Attach the controller from `HomePage` after login.
  - [x] Navigate to the call page on incoming ringing calls.
  - [x] Avoid duplicate navigation for the same active incoming call.

- [x] Replace static call page behavior.
  - [x] Start outgoing private voice calls with `roomId + peerUserId`.
  - [x] Show answer/reject only for incoming ringing calls.
  - [x] Make hangup and mute call real controller methods.
  - [x] Keep video route explicitly unsupported until video is implemented.

- [x] Update platform permissions.
  - [x] Add iOS microphone usage description.
  - [x] Keep camera permission unchanged for scan/video future use.

- [x] Verify.
  - [x] Unit-test state mapping and controller action behavior through a fake controller where practical.
  - [x] Run focused `flutter analyze`.
  - [x] Run relevant tests.
  - [x] Build iOS simulator debug package and install on both simulators.

## 2026-05-30 Verification Result

- Focused `flutter analyze` passed for the voice controller, provider, call page, home/chat routes, router, and test file.
- `flutter test test/voice_call_controller_test.dart` passed.
- `flutter build ios --simulator --debug` passed.
- Installed on `iPhone 17 Pro Max` and `P2P IM Clean Test`; both simulators had microphone permission granted.
- Real two-simulator check reached `CallState.kConnected` on both sides and showed call duration. Simulator audio quality still needs real-device validation.

## 2026-05-30 Call Record Fix Verification

- Added call timeline filtering so chat history only displays terminal call records and hides Matrix call invite/answer/candidate signaling noise.
- Added conversation preview labels for call events: normal calls show `语音通话`, missed timeout calls show `未接通语音通话`.
- Fixed call page lifecycle so remote hangup closes the peer page automatically.
- Fixed connected timer derivation so every new call starts from the current connected transition rather than reusing a previous call timestamp.
- Focused `flutter analyze` passed for changed call/chat files.
- `flutter test test/call_timeline_events_test.dart test/message_preview_test.dart test/voice_call_controller_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on both simulators.

## 2026-05-30 Call Record Accuracy Follow-up

- Verified real simulator Matrix events: unanswered calls can be `m.call.hangup` with `reason=userHangup` and no `m.call.answer`; connected calls can emit two `m.call.hangup` events for the same `call_id`, followed by late candidates/negotiate events.
- Updated chat timeline records to classify by event sequence, not only reason: any call with an answer is `语音通话 已接通 M:SS`; any terminal call without answer is `语音通话 未接通`.
- Updated duration to use `m.call.answer -> terminal hangup`, not `invite -> hangup`.
- Added display-name guard for incoming calls so route/state `owner` does not win over AS contact metadata; fallback is the peer domain instead of `owner`.
- `flutter analyze lib/presentation/chat/call_timeline_events.dart lib/presentation/call/voice_call_display_name.dart lib/presentation/pages/call_page.dart lib/presentation/pages/home_page.dart lib/presentation/utils/message_preview.dart test/call_timeline_events_test.dart test/message_preview_test.dart test/voice_call_display_name_test.dart` passed.
- `flutter test test/call_timeline_events_test.dart test/message_preview_test.dart test/voice_call_display_name_test.dart test/voice_call_controller_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Call Timeline Window Follow-up

- Root cause: `Room.getTimeline()` initially loads Matrix SDK `defaultHistoryCount = 30` raw events. Voice calls generate many raw Matrix call events, so several calls can crowd text/images out of the initial window even though those messages still exist in the local Matrix database.
- Fixed call record rendering to use raw call context events for `m.call.answer` lookup while keeping the visible chat timeline filtered. This prevents connected calls from being marked as missed after `m.call.answer` is hidden from the UI.
- Added local-only chat-open backfill: when the visible message count is low and older events already exist in the device database, ChatPage appends local stored events without requesting server history. This preserves the new-device privacy rule that chat open must not pull read history from the server.
- `flutter analyze lib/presentation/chat/chat_history_backfill_policy.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/pages/chat_page.dart test/call_timeline_events_test.dart test/chat_history_backfill_policy_test.dart` passed.
- `flutter test test/call_timeline_events_test.dart test/chat_history_backfill_policy_test.dart test/message_preview_test.dart test/voice_call_display_name_test.dart test/voice_call_controller_test.dart test/chat_timeline_items_test.dart test/chat_visibility_policy_test.dart test/recovered_unread_events_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Call Record Bubble Ownership Follow-up

- Root cause: call records were rendered as `_SChatSystemNotice`, so they were always centered and could not show who initiated the call.
- Added call record ownership by matching the terminal call record to the same `call_id`'s `m.call.invite.senderId`; this uses the original caller, not whichever side sent the final hangup.
- ChatPage now renders call records as normal left/right chat bubbles. Outgoing calls appear on the current user's side; incoming calls appear on the peer side.
- `flutter test test/call_timeline_events_test.dart` passed, including the case where the peer hangs up a call originally started by the current user.
- `flutter analyze lib/presentation/chat/call_timeline_events.dart lib/presentation/pages/chat_page.dart test/call_timeline_events_test.dart` passed.
- `flutter test test/call_timeline_events_test.dart test/message_preview_test.dart test/voice_call_display_name_test.dart test/voice_call_controller_test.dart test/chat_history_backfill_policy_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Connected Call Unread Badge Follow-up

- Root cause: the message page unread badge used Matrix `Room.notificationCount` directly. Matrix can count a peer `m.call.hangup` after an already connected call as one unread event, while the product rule is that only missed calls should create an unread call reminder.
- Added `conversationUnreadCount` as the product-layer filter for conversation rows: connected/normal call signaling subtracts the call event from the displayed badge, while `invite_timeout` missed calls still count as unread.
- HomePage conversation rows now display the product unread count instead of raw Matrix unread count.
- `flutter test test/message_preview_test.dart test/call_timeline_events_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart` passed.
- `flutter analyze lib/presentation/chat/call_timeline_events.dart lib/presentation/utils/message_preview.dart lib/presentation/pages/home_page.dart test/message_preview_test.dart test/call_timeline_events_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Connected Call Read Marker Follow-up

- Root cause follow-up: UI-level filtering still depends on Matrix `lastEvent` and `notificationCount` arriving in a stable order. Matrix VoIP can emit multiple events for one call, and those events may arrive around hangup in different orders on different devices.
- Added a call-controller-level read marker: once a call reaches connected, the controller remembers its `room_id + call_id`; when the terminal `m.call.hangup` event for that connected call arrives, the room is locally marked read and Matrix `m.read` is sent to that terminal event.
- Missed/unanswered calls remain unread because only connected calls qualify, and `invite_timeout` terminal events are explicitly excluded.
- `flutter test test/voice_call_controller_test.dart test/message_preview_test.dart test/call_timeline_events_test.dart test/call_page_layout_test.dart` passed.
- `flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/utils/message_preview.dart lib/presentation/pages/home_page.dart test/voice_call_controller_test.dart test/message_preview_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Stale Incoming Call Follow-up

- Edge case: if the callee app is backgrounded, the caller rings and hangs up, then the callee resumes later, Matrix/VoIP can surface the old invite as a fresh incoming call.
- Root cause: the SDK filters some expired timeline invites, but stale to-device/room event ordering can still create a `CallSession` before the app-level controller has checked whether the call already ended.
- Added an app-level stale incoming guard before binding an incoming call:
  - If the call session has already ended, do not ring.
  - If a terminal event for the same `room_id + call_id` was already observed, do not ring.
  - If the room last event or recent local Matrix database events contain `m.call.hangup`/`m.call.reject` for the same `call_id`, do not ring.
  - If our generated `call_id` timestamp is older than 75 seconds, do not ring.
- Stale incoming calls are terminated locally without sending a new reject/hangup event, so an old call does not create new Matrix noise.
- `flutter test test/voice_call_controller_test.dart test/message_preview_test.dart test/call_timeline_events_test.dart test/call_page_layout_test.dart` passed.
- `flutter analyze lib/presentation/call/voice_call_controller.dart test/voice_call_controller_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 Missed Call Unread Badge Follow-up

- Root cause: the conversation-list UI filter tried to infer connected versus missed calls from only the last Matrix call event. A missed call can end with `reason=user_hangup` when the caller hangs up before the callee answers, so the UI filter incorrectly subtracted the only unread event and hid the unread reminder.
- Current rule: conversation rows display the unread count produced by Matrix/local read state. Connected-call cleanup is handled at the call-controller layer by sending/recording a read marker after a connected call terminates; missed/unanswered calls therefore remain unread.
- Removed the call-event-specific unread subtraction from `conversationUnreadCount`; it now clamps negative/zero values only and otherwise preserves the count.
- `flutter test test/message_preview_test.dart --plain-name 'keeps matrix unread counts in conversation badges'` passed.
- `flutter test test/voice_call_controller_test.dart test/message_preview_test.dart test/call_timeline_events_test.dart test/call_page_layout_test.dart` passed.
- `flutter analyze lib/presentation/utils/message_preview.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/pages/home_page.dart test/message_preview_test.dart test/call_timeline_events_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart` passed.
- `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.

## 2026-05-30 iOS Background Incoming Call Follow-up

- Current limitation: the implemented Matrix/WebRTC call path works while the app is foregrounded or still actively running, but it is not a production-grade iOS background/lock-screen incoming-call path.
- Product requirement deferred to true-device testing: incoming voice/video calls should alert the user when the app is backgrounded, suspended, locked, or killed, similar to WeChat/FaceTime behavior.
- Required architecture for production iOS calls:
  - iOS client registers a PushKit VoIP token.
  - The user's node stores each device's VoIP token.
  - On incoming call, the callee's node sends an APNs VoIP push with `apns-push-type: voip` and topic `<bundle id>.voip`.
  - iOS wakes the app and the native layer reports the incoming call through CallKit.
  - Answer/reject/hangup actions from CallKit are bridged back into the existing Matrix/WebRTC call controller.
  - If the caller has already canceled or the call timed out, backend/client state must end the CallKit call immediately to avoid stale incoming-call UI.
- Apple-side prerequisites: Apple Developer Program, stable Bundle ID, Push Notifications capability, Background Modes for Voice over IP/audio as needed, APNs auth key or VoIP-capable certificate, and at least one real iPhone for validation.
- App Store risk: CallKit may need regional gating or fallback if distributing in mainland China, because CallKit support has historically been restricted for apps available in the China App Store.
- Do not claim lock-screen/background incoming calls are complete until verified on a real iPhone with APNs/PushKit/CallKit end to end.

## 2026-05-31 AS Call State Follow-up

- Root cause: when the callee app returned from background, Matrix could replay the old invite before the later hangup/timeout state arrived. The UI route listened to `ringing + roomId` and could briefly push the stale incoming-call page before AS state caught up.
- Product rule: private-call UI may open an incoming-call route only after the controller has an AS call id for that incoming call. A Matrix-only ringing session is not enough to show the call page.
- Implementation:
  - Added `p2pIncomingCallCanOpenRoute` and made `HomePage` use it before pushing `/call` or `/video-call`.
  - Incoming Matrix sessions no longer expose `callId` in UI state until `registerIncomingCall` confirms the AS session is still non-terminal.
  - If AS says the call is already terminal, the stale incoming session is discarded and the active call state returns to idle.
  - Chat call records can now read the AS call session by `call_id` and prefer AS media type, terminal state, and duration over Matrix-only answer/hangup inference.
- Expected behavior:
  - Background-resume stale calls should no longer flash an old incoming-call page.
  - Call records may still be eventually consistent across nodes, but visible records should converge faster because the chat page warms AS call sessions when call records are visible.
- Verification:
  - `flutter test test/voice_call_controller_test.dart --plain-name 'incoming call route waits for AS call id before opening UI'` passed.
  - `flutter test test/call_timeline_events_test.dart --plain-name 'formats call records from AS session before Matrix answer arrives'` passed.
  - `flutter test test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/call_page_layout_test.dart test/group_call_controller_test.dart test/group_call_page_test.dart test/http_as_client_test.dart` passed.
  - `flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/home_page.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/pages/chat_page.dart test/voice_call_controller_test.dart test/call_timeline_events_test.dart` passed.
  - `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro`, `iPhone 17 Pro Max`, and `P2P IM Clean Test`.

## 2026-06-05 Stale Active Call Gate Follow-up

- Root cause: AS `/_as/calls/active` can still return a `connected` call if a terminal `ended/missed/failed` report failed, raced, or arrived late. The client previously trusted any AS active call and blocked a new outgoing call with `已有通话正在进行`, even when the local call page had already been closed.
- Product rule: if the local client has no active call state, stale AS `connected` sessions must be reconciled before blocking the next outgoing call. A true active `ringing` session or another non-terminal active session still blocks.
- Implementation:
  - `AsCallStateReporter` now records a local terminal call id before attempting the AS terminal update, so a failed terminal report cannot keep blocking the same client forever.
  - The outgoing AS active-call gate filters call ids known locally as terminal.
  - If the local client is idle but AS returns `connected` calls, the reporter marks those calls `ended` with reason `stale_local_inactive` before the gate makes the final decision.
- Verification:
  - `flutter test test/voice_call_controller_test.dart` passed.
  - `flutter analyze lib test` passed.
  - `flutter test` passed.
  - `flutter build ios --simulator --debug` passed; new build installed and launched on `iPhone 17 Pro`, `iPhone 17 Pro Max`, and `P2P IM Clean Test`.
