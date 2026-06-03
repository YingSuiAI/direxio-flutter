# Private Video Call MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the verified 1:1 Matrix VoIP voice-call path into real 1:1 video calls without duplicating controller or timeline logic.

**Architecture:** Keep one call controller and one call page. Add a product call type to the existing call state, pass `CallType.kVideo` to Matrix VoIP for video routes, render local/remote WebRTC streams on the call page, and reuse the same incoming-call, timer, hangup, call-record, and timeline protections from voice calls. Preserve the product-level video intent with a hidden `p2p.call.intent.v1` event because Matrix SDK may infer `voice` when simulator camera is unavailable or initially muted.

**Tech Stack:** Flutter, Riverpod, go_router, matrix SDK VoIP, flutter_webrtc, Material Symbols, iOS Simulator.

---

### Task 1: Product Call Type

**Files:**
- Modify: `lib/presentation/call/voice_call_controller.dart`
- Test: `test/voice_call_controller_test.dart`

- [x] Add a `ProductCallType` enum with `voice` and `video`.
- [x] Store `callType` in `VoiceCallUiState`.
- [x] Make labels type-aware: incoming video says `邀请你视频通话`; connected video says `视频通话中`.
- [x] Keep voice behavior unchanged by default.

### Task 2: Matrix Video Signaling

**Files:**
- Modify: `lib/presentation/call/voice_call_controller.dart`
- Test: `test/voice_call_controller_test.dart`

- [x] Add `callType` parameter to `startOutgoing`, defaulting to voice.
- [x] Map product video to Matrix `CallType.kVideo`.
- [x] Derive incoming call type from `CallSession.type`, then override voice with recent `p2p.call.intent.v1` when the product intent says video.
- [x] Keep busy rejection and duplicate invite handling shared for voice and video.

### Task 3: Video Call Page

**Files:**
- Modify: `lib/presentation/pages/call_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/presentation/pages/chat_page.dart`
- Modify: `lib/presentation/pages/home_page.dart`

- [x] Remove the old “视频通话暂未开放” guard.
- [x] Route chat header video button to `/video-call/:roomId`.
- [x] Route incoming video calls to `/video-call/:roomId?incoming=1`.
- [x] Render remote video full screen when available.
- [x] Render local video as a small preview when available.
- [x] Fall back to the existing avatar/status layout while video streams are not ready.
- [x] After a video call is connected, switch immediately to a dedicated full-screen video layout instead of reusing the voice-call sheet.
- [x] Keep a draggable local preview window in connected video calls, even before the remote first frame arrives.

### Task 4: Controls And Permissions

**Files:**
- Modify: `lib/presentation/call/voice_call_controller.dart`
- Modify: `lib/presentation/pages/call_page.dart`
- Modify: `ios/Runner/Info.plist`

- [x] Add camera mute/unmute for video calls.
- [x] Keep microphone mute shared for voice and video.
- [x] Update camera and microphone permission text to include video calls.
- [x] Do not implement group calls or screen share in this MVP.

### Task 5: Verification And Documentation

**Files:**
- Modify: `docs/superpowers/plans/2026-05-30-private-video-call-mvp.md`
- Modify: Desktop development/test planning docs.

- [x] Run focused Flutter tests.
- [x] Run focused Flutter analyze.
- [x] Build iOS simulator debug app.
- [x] Install and launch on both simulators.
- [x] Manually test outgoing video, incoming video recognition, missed-call timeline records, and conversation preview.
- [x] Record remaining simulator limitations, especially camera availability and real-device video quality.
- [ ] Manually test answer, connected timer, mute, camera toggle, hangup, and remote close after Simulator UI automation recovers or user can click.

### Verification Result

Commands run:

```bash
flutter test test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/utils/message_preview.dart lib/presentation/pages/call_page.dart lib/core/router/app_router.dart lib/presentation/pages/home_page.dart lib/presentation/pages/chat_page.dart test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused tests passed: 20 related Flutter tests.
- Focused analyze passed with no issues.
- iOS Simulator debug build succeeded.
- The new build was installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.
- Real two-simulator check confirmed: caller enters video-call page; callee receives `视频通话 / 邀请你视频通话`; missed video call renders as `视频通话 未接通` in the chat; conversation preview uses neutral `通话`, not the wrong `语音通话`.

Remaining limitation:

- Computer Use lost the Simulator window accessibility handle during the answer step, so the connected video-call path could not be auto-clicked to completion in this unattended run.
- iOS Simulator camera availability is not a substitute for real video-quality validation. Two real devices must still verify camera permission, preview/remote stream, audio/video sync, and real network quality.

### Heartbeat Recheck 2026-05-30 02:33 Asia/Shanghai

Commands rerun:

```bash
flutter test test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/utils/message_preview.dart lib/presentation/pages/call_page.dart lib/core/router/app_router.dart lib/presentation/pages/home_page.dart lib/presentation/pages/chat_page.dart test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter build ios --simulator --debug
git diff --check
```

Observed result:

- Focused tests still pass: 20 related Flutter tests.
- Focused analyze still reports no issues.
- iOS Simulator debug build still succeeds.
- `git diff --check` reports no whitespace errors.
- Current build was reinstalled to `iPhone 17 Pro Max` and `P2P IM Clean Test`.
- Both simulators launched to the message list. Screenshots show the direct chat preview uses neutral `通话`, confirming it did not regress to the wrong `语音通话` preview.
- Computer Use still cannot access the Simulator window (`cgWindowNotFound`), so the remaining connected-call manual flow is unchanged.

### Connected Video Layout Update 2026-05-30 Asia/Shanghai

Product rule:

- A connected video call must look and behave like a video call: one full-screen large video area plus one draggable local preview.
- The UI must switch to this layout as soon as the call status becomes connected. It must not wait for the remote camera's first frame, otherwise users see a voice-call-like page after answer.
- Voice calls and pre-connected video calls keep the existing call sheet layout.

Implementation:

- Added `shouldUseConnectedVideoCallLayout` to make the routing condition explicit and testable.
- Added a connected-video screen in `lib/presentation/pages/call_page.dart`.
- The large stage shows remote video when a remote video track exists, otherwise a full-screen waiting-for-video state.
- The small local preview is draggable and shows either local camera preview or a camera placeholder.
- Existing mute, camera toggle, speaker, hangup, timer, and remote-close behavior are reused.
- If the app has no local video track, the local preview and camera control explicitly show `摄像头不可用` instead of pretending the camera can be turned off.
- Debug builds log call media state every 10 seconds with `p2p-call-media`, including audio/video track counts and WebRTC connection/ICE state, so intermittent audio dropouts can be separated from AS/backend signaling issues.

Verification:

```bash
flutter analyze lib/presentation/pages/call_page.dart test/call_page_layout_test.dart
flutter test test/call_page_layout_test.dart test/voice_call_controller_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused analyze passed with no issues.
- Focused tests passed: 9 related Flutter tests.
- iOS Simulator debug build succeeded.
- The new build was installed and launched on `iPhone 17 Pro Max` and `P2P IM Clean Test`.
- Camera and microphone permissions were granted to both simulator app instances for the next manual camera-frame check.

Follow-up verification:

- The focused analyze command was expanded to include `lib/presentation/call/voice_call_controller.dart`.
- Focused tests now cover 11 related Flutter tests, including camera-unavailable labeling.
- The app was rebuilt and reinstalled to both simulators after the camera-unavailable UI and periodic media diagnostics were added.

### TURN Stabilization 2026-05-30 Asia/Shanghai

Root cause evidence:

- Before TURN was configured, voice calls could connect and both sides had live audio tracks, but the media path later moved to ICE disconnected and the call ended.
- Dendrite v0.13.8 exposes Matrix TURN credentials through `/_matrix/client/v3/voip/turnServer` from `client_api.turn`.
- Both current nodes had empty or missing `client_api.turn`, so the Matrix Dart SDK returned an empty `iceServers` list and WebRTC relied on direct ICE only.

Implementation:

- Added coturn generation support to `p2p-im-deploy`:
  - install `coturn`
  - persist `/etc/p2p-im/turn_shared_secret`
  - write `/etc/turnserver.conf`
  - patch Dendrite `client_api.turn`
  - verify coturn UDP `3478`
- Updated deploy verification and deploy-skill docs so future VPS nodes open `3478/tcp`, `3478/udp`, and relay range `49152-49200/tcp,udp`.
- Applied the same TURN configuration to the existing `p2p-im.com` EC2 node and `p2p-liyanan.com` Lightsail node.

Verification:

- Both cloud firewalls now allow TURN `3478` and relay range `49152-49200`.
- Both VPS nodes report Dendrite, AS, nginx, and coturn active.
- Both public Matrix `/_matrix/client/versions` endpoints still return successfully after Dendrite restart.
- Authenticated `/_matrix/client/v3/voip/turnServer` returns non-empty TURN URIs and redacted dynamic credentials on both nodes.
- Two-simulator voice-call stability test passed from 11:33:31 to 11:36:12:
  - caller stayed `RTCPeerConnectionStateConnected` / `RTCIceConnectionStateCompleted`
  - callee stayed `RTCPeerConnectionStateConnected` / `RTCIceConnectionStateConnected`
  - both sides kept `localAudio=1`, `remoteAudio=1`, `localAudioState=on/live`, `remoteAudioState=on/live`

Remaining validation:

- Real devices still need camera-frame and real network audio/video quality validation, because iOS Simulator cannot prove physical camera capture quality.

### Outgoing Call Network Failure Guard 2026-05-30 Asia/Shanghai

Root cause evidence:

- On the EC2-backed `p2p-im.com` node, an outgoing call could temporarily show no
  peer ringing and no call record, then both sides received the call record later
  after delayed Matrix sync.
- Endpoint checks later returned normally, so this was not a bad iOS build. It
  was a node/network reliability problem where call signaling events were not
  available quickly enough for the realtime call UX.

Product rule:

- Outgoing calls must not continue as a normal Matrix call if the product call
  intent cannot be written first.
- The user should see a stable network failure message instead of a fake calling
  state when the node drops the handshake or times out.
- Deployment readiness must verify call-record immediacy, not only service
  process state.

Implementation:

- Added a testable outgoing-call preflight guard to block duplicate starts and
  missing service/room/peer state.
- Changed product call intent sending from best-effort logging to a required
  step before `inviteToCall`.
- Added a stable user-facing failure message for handshake, connection, socket,
  timeout, and `Future not completed` failures.

Verification:

```bash
flutter test test/voice_call_controller_test.dart
flutter test test/voice_call_controller_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart test/voice_call_controller_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused controller tests pass, including duplicate-start preflight and network
  failure message coverage.
- Related call/timeline/message preview tests pass: 27 tests.
- Focused analyze passed with no issues.
- iOS Simulator debug build succeeded and was installed/launched on `iPhone 17
  Pro Max` and `P2P IM Clean Test`.

### Three-Layer Call Network Feedback 2026-05-30 Asia/Shanghai

Product rule:

- If the local app cannot write the product call intent or Matrix call invite,
  show `拨打失败，请检查你的网络或节点后重试`.
- If the outgoing call is sent but the peer does not answer within 30 seconds,
  end the attempt and show `对方暂无响应，已结束拨打`.
- If a connected call becomes intermittently unhealthy, show
  `网络不稳定`.
- If the connected call does not recover after 10 seconds, end it and show
  `通话中断`.

Implementation:

- Added a 30-second outgoing no-response timer after Matrix `inviteToCall`
  succeeds.
- Added connected-call media health monitoring that checks WebRTC transport
  state and inbound media byte growth.
- Kept video camera availability separate from network health: missing remote
  video with healthy audio/transport still shows camera unavailable, not network
  failure.
- Connected call status text now shows active network warnings before the
  elapsed timer.

Verification:

```bash
flutter test test/voice_call_controller_test.dart test/call_page_layout_test.dart
flutter test test/voice_call_controller_test.dart test/call_page_layout_test.dart test/call_timeline_events_test.dart test/message_preview_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/call_page.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused tests passed: 25 tests.
- Related call/timeline/message preview tests passed: 39 tests.
- Focused analyze passed with no issues.
- iOS Simulator debug build succeeded and was installed/launched on `iPhone 17
  Pro Max` and `P2P IM Clean Test`.
