# Group Voice and Video Call MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable foreground group voice and video calls inside real Matrix-backed P2P IM group chats.

**Architecture:** Reuse the existing Matrix `VoIP` instance owned by `MatrixVoiceCallController` and add a separate group-call state stream on the same controller. Group calls use Matrix SDK `GroupCallSession` with mesh WebRTC and room-scoped membership events. The UI gets a dedicated group call route/page because group calls are joinable room calls with multiple participants, not one-to-one ringing calls.

**Tech Stack:** Flutter, Riverpod, go_router, Matrix Dart SDK `GroupCallSession`, `MeshBackend`, flutter_webrtc, Material 3 local tokens, iOS Simulator.

---

## Product And Technical Boundaries

- Group calls are foreground MVP only. Background, lock-screen, and killed-app incoming reliability still requires PushKit, APNs VoIP push, and CallKit on real iPhone.
- A group call is a room call. Members can join an active room call; this is different from private calls where one user directly rings another.
- Invited group members must not be treated as joined until they explicitly tap `加入`; an incoming group call route must keep the `加入/挂断` controls visible even if Matrix group-call state has already produced a joining snapshot.
- Group call UI must show joined participants using Matrix member display name/avatar when available. Participant count must prefer unique participant identities over raw device-count snapshots.
- If a real multi-member group call later shrinks to only the local participant, the app should automatically leave and close the call page for the remaining user. This rule only applies after at least two participants were seen once, so a user is not kicked during initial connection before others join.
- The current Matrix SDK group-call mesh backend uses Matrix room state `com.famedly.call.member` and to-device WebRTC signaling.
- The app must not create another `VoIP` instance for group calls. One Matrix client should have one VoIP delegate to avoid duplicated call handling.
- If the current user cannot enable or join group calls because of Matrix power levels, the UI must show a clear permission/capability message instead of a generic failure.
- Voice and video group calls share one group-call controller path. Video uses full-screen layout with remote participant tiles and local preview; voice uses participant/audio-focused layout.

## File Structure

- Modify `lib/presentation/call/voice_call_controller.dart`
  - Add group-call UI state, product call helpers, and methods on the existing controller.
  - Handle `handleNewGroupCall` and `handleGroupCallEnded` in the existing WebRTC delegate.
  - Keep private-call state and behavior unchanged.
- Create `lib/presentation/pages/group_call_page.dart`
  - Dedicated group voice/video call screen.
  - Shows room name, participants, timer, mute/camera/speaker/leave controls, and video stage when needed.
- Modify `lib/core/router/app_router.dart`
  - Add `/group-call/:roomId` and `/group-video-call/:roomId` routes.
- Modify `lib/presentation/pages/group_chat_page.dart`
  - Route the group header voice button to group call.
  - Add group video call entry through the existing chat action area if needed.
- Modify `lib/presentation/pages/home_page.dart`
  - Attach the existing call controller as before; add foreground incoming/available group-call routing only if the group-call state says user should be shown the group-call page.
- Add `test/group_call_controller_test.dart`
  - Pure helper/state tests for preflight, labels, type mapping, and timer behavior.
- Add `test/group_call_page_test.dart`
  - Widget tests for voice/video layouts and controls.

## Task 1: Group Call State And Pure Helpers

**Files:**
- Modify: `lib/presentation/call/voice_call_controller.dart`
- Test: `test/group_call_controller_test.dart`

- [ ] **Step 1: Write failing tests for group-call labels and preflight**

Expected behaviors:

- `groupCallStatusLabel` returns `群语音通话中` for connected voice.
- `groupCallStatusLabel` returns `群视频通话中` for connected video.
- `groupCallPreflightError` returns `通话服务还没有准备好`, `已有通话正在进行`, `群聊不存在`, or `该群暂不支持群通话` for the matching guard.
- `nextGroupCallConnectedAt` starts timer only when transitioning into connected.

- [ ] **Step 2: Run the failing tests**

Run:

```bash
flutter test test/group_call_controller_test.dart
```

Expected: fail because group-call helpers do not exist yet.

- [ ] **Step 3: Add group-call state and helpers**

Implementation requirements:

- Add `GroupCallStatus { idle, joining, connected, ended, failed }`.
- Add `GroupCallUiState` with room id, room name, call id, call type, participant count, mute/camera/speaker booleans, connectedAt, error.
- Add pure helpers named in Step 1.
- Do not modify private-call helper behavior.

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/group_call_controller_test.dart
```

Expected: pass.

## Task 2: Matrix GroupCallSession Integration

**Files:**
- Modify: `lib/presentation/call/voice_call_controller.dart`
- Test: `test/group_call_controller_test.dart`

- [ ] **Step 1: Add controller interface methods**

Add these methods to `VoiceCallController`:

- `GroupCallUiState get currentGroupState`
- `GroupCallSession? get activeGroupSession`
- `Stream<GroupCallUiState> get groupStateStream`
- `Future<void> startOrJoinGroupCall({required String roomId, required String roomName, ProductCallType callType})`
- `Future<void> leaveGroupCall()`
- `Future<void> setGroupMuted(bool muted)`
- `Future<void> setGroupCameraMuted(bool muted)`
- `Future<void> setGroupSpeakerOn(bool enabled)`

- [ ] **Step 2: Implement group call start/join**

Implementation requirements:

- Use the existing `_voip` instance.
- Resolve the room from `_client.getRoomById(roomId)`.
- For a new room-scoped call, use `groupCallId = room.id` to avoid parallel room calls.
- Call `voip.fetchOrCreateGroupCall(room.id, room, MeshBackend(), 'm.call', 'm.room')`.
- For voice calls, create an audio-only local `WrappedMediaStream` and pass it to `groupCall.enter(stream: ...)` so a missing simulator camera does not break voice calls.
- For video calls, allow default video local stream.
- On group-call errors, show a user-readable message.

- [ ] **Step 3: Wire group call events**

Implementation requirements:

- Subscribe to `groupCall.onGroupCallState`.
- Subscribe to `groupCall.onGroupCallEvent`.
- Subscribe to `MeshBackend.onGroupCallFeedsChanged` when backend is mesh.
- Update participant count, local mute/camera state, and connected timer from the SDK state.
- Implement `handleNewGroupCall` and `handleGroupCallEnded` in `_MatrixWebRtcDelegate`.

- [ ] **Step 4: Implement leave and controls**

Implementation requirements:

- `leaveGroupCall` calls `GroupCallSession.leave()`.
- `setGroupMuted` calls `groupCall.backend.setDeviceMuted(..., MediaInputKind.audioinput)`.
- `setGroupCameraMuted` calls `groupCall.backend.setDeviceMuted(..., MediaInputKind.videoinput)`.
- `setGroupSpeakerOn` reuses the existing audio route.

- [ ] **Step 5: Run focused controller tests and analyze**

Run:

```bash
flutter test test/group_call_controller_test.dart test/voice_call_controller_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart test/group_call_controller_test.dart
```

Expected: all pass.

## Task 3: Group Call Page And Routes

**Files:**
- Create: `lib/presentation/pages/group_call_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/group_call_page_test.dart`

- [ ] **Step 1: Write widget tests**

Expected behaviors:

- Voice route shows room name, `群语音通话`, mute/speaker/leave controls.
- Video route shows full-screen video-stage key `group-video-call-stage`.
- Failed state shows the controller error.

- [ ] **Step 2: Run failing widget tests**

Run:

```bash
flutter test test/group_call_page_test.dart
```

Expected: fail because page/routes do not exist.

- [ ] **Step 3: Implement `GroupCallPage`**

Implementation requirements:

- Attach the Matrix client through the existing controller.
- Start/join the group call after first frame if route is not incoming.
- Use dark fixed call surface like private call page.
- Show participants and timer.
- For video, show a full-screen remote area and local preview placeholder.
- Keep controls real: mute, camera, speaker, leave.

- [ ] **Step 4: Add routes**

Routes:

- `/group-call/:roomId`
- `/group-video-call/:roomId`

Query parameters:

- `name`: optional room display name.
- `incoming=1`: open existing active call without starting a new one.

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/group_call_page_test.dart test/group_call_controller_test.dart
flutter analyze lib/presentation/pages/group_call_page.dart lib/core/router/app_router.dart
```

Expected: pass.

## Task 4: Group Chat Entry Points

**Files:**
- Modify: `lib/presentation/pages/group_chat_page.dart`
- Test: `test/group_call_page_test.dart`

- [ ] **Step 1: Route voice call button**

Replace the temporary snackbar on the group header voice button with:

```dart
context.push('/group-call/${Uri.encodeComponent(widget.roomId)}?name=${Uri.encodeQueryComponent(name)}');
```

- [ ] **Step 2: Add video call entry**

If the current plus/action panel already has a suitable media/action area, add `视频通话` there. If no stable panel hook exists, add a second header action only for this MVP and document the UI tradeoff.

- [ ] **Step 3: Run focused tests and analyze**

Run:

```bash
flutter analyze lib/presentation/pages/group_chat_page.dart
flutter test test/group_call_page_test.dart
```

Expected: pass.

## Task 5: Documentation And Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-05-31-group-voice-video-call-mvp.md`

- [ ] **Step 1: Run focused automated verification**

Run:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart lib/presentation/pages/group_chat_page.dart lib/core/router/app_router.dart test/group_call_controller_test.dart test/group_call_page_test.dart
```

- [ ] **Step 2: Build iOS simulator app**

Run:

```bash
flutter build ios --simulator --debug
```

- [ ] **Step 3: Install on available simulators**

Run `xcrun simctl list devices booted`, then install `build/ios/iphonesimulator/Runner.app` to each booted test simulator.

- [ ] **Step 4: Manual simulator verification**

Minimum checks:

- Group owner starts group voice call.
- Second member joins voice call.
- Leave on one device updates participant count on the other.
- Group owner starts group video call.
- Simulator camera unavailable state is clear and does not block voice call.
- Generic backend/network failures show explicit error text.

- [ ] **Step 5: Update this document**

Record commands, results, simulator devices, failures, and remaining real-device limitations.

## 2026-05-31 Implementation Result

Implemented:

- Added `GroupCallUiState`, `GroupCallStatus`, group-call preflight helpers, status labels, and connected timer helpers in `lib/presentation/call/voice_call_controller.dart`.
- Extended the existing `MatrixVoiceCallController` instead of creating a second VoIP owner:
  - one Matrix `VoIP` instance still handles private and group calls
  - `GroupCallSession` state is exposed through `groupStateStream`
  - `startOrJoinGroupCall` uses `voip.fetchOrCreateGroupCall(room.id, room, MeshBackend(), 'm.call', 'm.room')`
  - room id is used as the group call id to avoid parallel calls inside one room
  - group voice creates an audio-only `WrappedMediaStream`, so simulator camera absence does not block voice calls
  - group video lets Matrix mesh backend initialize the local camera stream
  - group mute, camera mute, speaker, and leave controls call the real Matrix/WebRTC backend
- Added `GroupCallPage`:
  - `/group-call/:roomId`
  - `/group-video-call/:roomId`
  - voice layout with participant count and controls
  - video layout with full-screen stage placeholder and controls
  - clear error text for permission/capability/network failures
- Connected group chat header actions:
  - voice button opens `/group-call/:roomId`
  - video button opens `/group-video-call/:roomId`
  - detail button remains available because chat header action capsule now supports three actions
- Added tests:
  - `test/group_call_controller_test.dart`
  - `test/group_call_page_test.dart`

Automated verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart test/chat_capsule_chrome_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart lib/presentation/pages/group_chat_page.dart lib/presentation/chat/chat_capsule_chrome.dart lib/core/router/app_router.dart test/group_call_controller_test.dart test/group_call_page_test.dart test/widget_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused tests passed: 41 tests.
- Focused analyze passed with no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)
- Simulator screenshots confirm the app launches after install.
- Runner logs over the last three minutes showed no fatal/exception/group-call crash records.

Manual verification status:

- Computer Use timed out twice while trying to access the Simulator UI, so unattended click-through testing of live group voice/video join/leave is not completed in this run.
- The next manual checks should use the installed build:
  - open an existing group on one simulator
  - tap the group voice button
  - join from a second simulator by tapping the same group voice button
  - verify participant count updates
  - leave on one side and verify the other side remains in the call
  - repeat with group video and confirm simulator camera-unavailable state is understandable

Remaining product boundary:

- Foreground group calls are implemented. Background/lock-screen/killed-app incoming group call behavior is still out of scope until PushKit/APNs VoIP/CallKit is implemented and verified on real iPhones.

## 2026-05-31 Follow-up: Participant Identity And Last-Member Exit

Implemented after the initial invite MVP:

- `GroupCallUiState` now carries `participants: List<GroupCallParticipantInfo>` with `userId`, display name, optional HTTP avatar URL, and local-user marker.
- `GroupCallUiState` now also carries `initiator` and `invitedParticipants`, so the caller and every invited member are represented explicitly before they join.
- `GroupCallPage` renders participant avatars/names instead of numbered placeholders.
- The outgoing waiting page and incoming invitation page now use the same participant list: caller first, then selected invitees. The caller is treated as already in the call; other members who have not joined are greyed out, and joined members render normally.
- Incoming group-call pages keep the visible `加入/挂断` controls until the user taps `加入`; group owner/admin are not default-joined by product logic.
- `MatrixVoiceCallController` tracks the highest participant count observed for the active group call and automatically calls `leaveGroupCall()` when a previously multi-person call shrinks to only the local member.
- Regression tests cover expected invitation participants, pending-member grey state, participant-count precedence, last-member auto-leave policy, visible incoming join action, and focused group call page rendering.

## 2026-05-31 Follow-up: Start Order And Stale Session Cleanup

Root cause from three-simulator testing:

- The caller could create an AS call session and send `p2p.group_call.invite.v1` before the local Matrix `GroupCallSession` had actually entered.
- If Matrix later rejected the join with `canJoinGroupCall` or left a stale SDK group call, invitees could still receive the product invite and show different call states from the caller.
- Matrix SDK `GroupCallSession.leave()` is required to remove stale entries from `VoIP.groupCalls`; resetting only Flutter controller state is not enough.

Implemented rule:

- Outgoing group calls must complete Matrix `fetchOrCreateGroupCall` and `groupCall.enter()` first.
- Only after local Matrix enter succeeds may the client create the AS call session and send the product invite event.
- If AS creation, invite sending, or any later start phase fails after a Matrix session was fetched, the client must call `GroupCallSession.leave()` before emitting the failure state.
- Starting a new group call also cleans up any inactive stale group session still held by the controller.

Regression added:

- `group_call_controller_test.dart` now locks the order: `fetchOrCreateGroupCall` -> `groupCall.enter` -> `_createAsCall` -> `_sendProductGroupCallInvite`.
- This test intentionally failed against the previous order and passes after the fix.

Verification:

```bash
flutter test test/group_call_controller_test.dart
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/group_call_member_select_page_test.dart test/http_as_client_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
flutter build ios --simulator --debug
```

Observed result:

- `group_call_controller_test.dart`: 11 tests passed.
- Focused regression set: 56 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Repeat the three-node group voice call on the installed build:
  - caller must not send invite if it cannot locally enter the Matrix group call
  - all invited devices should show the same invited-member list
  - tapping `加入` must not close the page while other devices think the user joined
  - leaving/restarting a new group call should not reuse stale SDK group call state

## 2026-05-31 Follow-up: Product Joined State And Per-User Timer

Root cause from three-simulator testing:

- Matrix SDK `GroupCallSession.participants` can lag or disagree across devices during join/leave. Logs showed member updates skipped while the SDK state was still `localCallFeedUninitialized`, and stale ongoing-call entries could block participant-list refresh.
- The UI was using SDK participant snapshots as the only joined-state truth, so one device could show `准备加入`, another device could show a member as joined, and the caller could keep showing `等待群成员加入`.
- The previous timer started from local Matrix connected transition. Product requirement is different: an invited member's timer starts after that member joins; the caller's timer starts only after the first other member joins.

Implemented rule:

- Group calls now publish hidden product-level Matrix timeline events:
  - `p2p.group_call.join.v1`
  - `p2p.group_call.leave.v1`
- `GroupCallUiState.joinedUserIds` is the UI's preferred participant-count source. Matrix participants remain a fallback and provide display metadata/avatars.
- Incoming invite state marks the initiator as joined immediately. The local user is marked joined only after `groupCall.enter()` succeeds.
- Group-call timer uses `joinedUserIds`:
  - incoming user: timer starts when local MXID is in `joinedUserIds`
  - caller: timer starts when any remote MXID is in `joinedUserIds`
- If local join is already known by product event but the Matrix transport state still lags at `idle` or `joining`, the UI treats the page as connected so it does not stay stuck on `准备加入`.
- Last-member auto-exit now evaluates the product joined set as well as Matrix's local participant flag.

Regression added:

- Outgoing caller with only local user joined shows no elapsed timer.
- Outgoing caller starts timer when the first remote joined event is known.
- Incoming user starts timer after local join.
- Local product join can promote a lagging Matrix `idle/joining` snapshot to connected UI state.
- Participant count prefers de-duplicated `joinedUserIds`.
- Group call page marks product-joined invited members as normal opacity and shows elapsed time.

Verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
```

Observed result:

- Focused group-call tests: 24 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Repeat a three-member group voice call on the installed build:
  - caller waits without timer until another member joins
  - each joined member shows their own elapsed timer
  - invited member tiles change from grey to normal after join
  - when a previously multi-person call drops to one local member, the remaining page auto-closes

## 2026-05-31 Follow-up: Product Roster Identity And Stale Matrix Participant Guard

Root cause from three-simulator testing:

- Some devices still displayed `Owner`/`O` because the group-call page resolved names and avatars from Matrix room-member memory first. When Matrix member cache was cold, the SDK fell back to MXID localpart.
- The caller could occasionally show a remote member as joined before anyone tapped `加入` because Matrix `GroupCallSession.participants` may contain stale or transport-level participants from the room call. For an invited product group call, Matrix participants are media metadata only, not proof that the user accepted this invite.
- Last-member auto-exit called `leaveGroupCall()`, but the controller reset the active group session without first emitting a terminal group state. The page therefore did not receive an `ended` state to close itself.

Implemented rule:

- Group-call display identity now resolves in this order:
  - current local profile / personal display name
  - AS sync contact metadata
  - Matrix room-member fallback
- If a product roster exists (`createdByMxid`, `invitedUserIds`, or `invitedParticipants`), UI joined status is based only on `joinedUserIds` maintained by `p2p.group_call.join.v1` / `p2p.group_call.leave.v1`.
- Matrix participants are still rendered as fallback metadata for non-rostered/ad-hoc room calls, but they do not ungrey invited users or start the caller timer in product calls.
- Local leave and automatic last-member leave now emit an `ended` `GroupCallUiState` before resetting the session, so `GroupCallPage` can close.

Regression added:

- Local group leave emits a terminal state for the call page.
- Matrix participants do not mark invited users as joined.
- AS contact profile wins over Matrix `Owner` fallback.
- Local profile wins for the current user.

Verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused group-call tests: 28 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Repeat the three-node group-call flow and verify:
  - caller shows only the initiator as normal before anyone joins
  - invited users remain grey until they tap `加入`
  - no participant displays `Owner` if AS/local profile metadata is available
  - the final remaining participant exits automatically after others leave

## 2026-05-31 Follow-up: Incoming Join Must Not Reuse-Early-Return

Root cause from three-simulator testing:

- Logs on all devices showed Matrix group-call member updates while the local call feed was still `localCallFeedUninitialized`.
- The invited devices could already have an `_activeGroupSession` for the same room because Matrix announced the room group call before the user tapped `加入`.
- `startOrJoinGroupCall(joinExistingInvite: true)` returned early whenever an active same-room group session existed and `_groupState.isActive` was true. That path emitted the current session state but never called `groupCall.enter()` and never sent `p2p.group_call.join.v1`.
- Result: every device could show its own pending/local state, but no real product join propagated, so nobody's timer started.

Implemented rule:

- Existing same-room group session may short-circuit only when the local user is already joined.
- For incoming invites, if the active same-room session exists but local user has not joined, the controller must reuse that session and still execute the enter path.
- The preflight busy-call guard allows this exact incoming-join continuation, while still blocking unrelated active calls.

Regression added:

- `incoming invite with existing session must still enter when local not joined` verifies that active same-room session plus `joinExistingInvite=true` does not short-circuit until local product/Matrix join is known.

Verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused group-call tests: 29 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Repeat the three-node invite, wait until all invited pages are visible, then tap `加入` on each invited simulator:
  - each invitee should leave `准备加入`
  - caller should start timer after first remote join
  - all joined users should turn normal opacity
  - if this still fails, inspect AS `failed to register incoming call` 500s separately from the client early-return path

## 2026-05-31 Follow-up: Product Join Is Authoritative For Group Call UI

Root cause from follow-up three-simulator testing:

- Matrix group-call membership and media setup can lag behind product-level invite acceptance, especially for the second invited member joining an already active call.
- Logs showed repeated Matrix SDK updates while `GroupCallSession` was still `localCallFeedUninitialized`, plus mesh backend messages such as `Waiting for ... to send call invite`.
- Treating Matrix `participants` or Matrix `GroupCallState.ended` as direct UI truth caused inconsistent states: some clients showed `准备加入`, some showed connected, and stale Matrix ended/participant snapshots could close or grey the wrong participants.

Implemented rule:

- `p2p.group_call.join.v1` / `p2p.group_call.leave.v1` are the product-level participant truth for the group call UI.
- When an invited user taps `加入`, the client immediately records and publishes local product join before waiting for Matrix `groupCall.enter()` to finish. This prevents a 20-30 second timer delay caused by Matrix/WebRTC negotiation.
- If Matrix reports `ended` while product state still says the local user is joined, the client ignores that Matrix ended snapshot for UI purposes. Local explicit leave still clears product join first, so real user leave continues to close the page.
- Debug instrumentation now logs `p2p-group-call-media` and `p2p-group-call-stats` every few seconds. These logs expose local audio track presence, remote media feeds, peer connection states, and WebRTC RTP byte counters. Use them to distinguish:
  - no local audio track: mic capture/permission problem
  - outbound audio bytes but no peer inbound bytes: WebRTC/network/TURN path problem
  - inbound audio bytes increasing but no audible sound: simulator/device audio route/render problem

Regression added:

- Product joined state overrides stale Matrix ended state.
- Incoming group invite publishes local join before Matrix enter.
- Matrix ended is ignored while product state says local joined.

Verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart test/group_call_controller_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused call tests: 73 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Start a fresh three-node group voice call and verify all devices use the same product joined state.
- While speaking for 10 seconds, inspect `p2p-group-call-stats`; audio `bytes` should increase on the receiver side if the audio stream is arriving.

## 2026-06-01 Follow-up: Element-Style Media Truth Split

Reference checked:

- Element Call uses MatrixRTC membership plus a LiveKit media participant layer. It does not treat a Matrix/product membership event as proof that media is connected.
- Element's call UI distinguishes the room/member roster, MatrixRTC call membership, and real LiveKit participants/tracks. Audio rendering only plays tracks that are attached to validated media participants.
- Current P2P IM MVP still uses Matrix SDK `MeshBackend`, not LiveKit. Therefore the immediate fix is to copy Element's state separation, not to pretend the mesh backend is already reliable.

Corrected rule:

- `joinedUserIds` means the product layer has seen a user accept/join intent through `p2p.group_call.join.v1`.
- `mediaUserIds` means the Matrix/WebRTC media layer has an actual local or remote media stream for that user.
- Group-call UI may use the product roster to show who was invited and who intended to join, but it must not display `connected`, start the timer, count active participants, or auto-close the last member based on product join alone.
- `GroupCallStatus.connected` now requires:
  - local product join or local media identity
  - local audio/video media stream is initialized
  - at least one remote media stream is observed, unless the call was already connected and is now shrinking toward last-member auto-leave
- Last-member auto-leave now uses `mediaUserIds`, so a stale product joined set cannot keep a dead call page open.
- Invited participant tiles are grey until their media identity is observed. The ringing page still displays the initiator normally so recipients can identify who started the call.

Regression added:

- Product join keeps a call in `joining`; it cannot promote the page to `connected`.
- Observed media gate requires both local media and at least one remote media user before connected state.
- Product joined identities do not inflate media participant count.
- Media-connected users, not product-joined-only users, ungrey invited members.
- Product-joined-only users stay pending until media connects.

Verification:

```bash
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/voice_call_controller_test.dart test/call_page_layout_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
flutter build ios --simulator --debug
```

Observed result:

- Focused group-call tests: 35 tests passed.
- Focused call regression set: 76 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Next architecture step:

- For production-quality group calls, move from Matrix mesh group calls toward Element's MatrixRTC + LiveKit SFU shape:
  - ops publishes `org.matrix.msc4143.rtc_foci` in `/.well-known/matrix/client`
  - each node deploys a MatrixRTC auth service and LiveKit SFU or points to an allowed relay/SFU service
  - Flutter client selects LiveKit-backed group-call transport when configured
  - AS remains the product call/session truth; MatrixRTC/LiveKit remains the media transport truth

## 2026-06-01 Follow-up: Product Join Must Not Short-Circuit Media Enter

Observed issue:

- Three-node group-call testing could leave all devices on `准备加入` with no timer after every invited member tapped `加入`.
- Logs separated the layers clearly:
  - product `joinedUserIds` already contained accepted users
  - one device stayed at `matrix_state=localCallFeedUninitialized localAudio=0 remoteFeeds=0`
  - other devices reached `matrix_state=entered localAudio=1 remoteFeeds=0`
- Root cause for the no-local-audio device: `_localUserJoinedGroupSession()` treated product `joinedUserIds` as proof that the local Matrix media session had joined. A later incoming invite join attempt could short-circuit before calling `GroupCallSession.enter()`.

Corrected rule:

- Product join means the user accepted the invitation.
- Local media join means Matrix `GroupCallState.entered` plus a real local media stream.
- The controller may short-circuit a same-room incoming join only when local media join is true. Product join alone must continue through the `enter()` path.

Code changes:

- Added `shouldTreatLocalGroupCallMediaJoined(...)`.
- Changed `_localUserJoinedGroupSession()` to use Matrix transport status plus local media readiness, not `joinedUserIds`.

Regression added:

- `product join alone does not mean local group media joined`.

Verification:

```bash
flutter test test/group_call_controller_test.dart --plain-name 'product join alone does not mean local group media joined'
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart test/group_call_controller_test.dart
flutter build ios --simulator --debug
```

Observed result:

- New focused regression passed.
- Focused group-call tests: 36 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded.
- New build installed and launched on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Remaining manual verification:

- Start a fresh group call after this build and verify each accepting device logs local media enter:
  - expected: `matrix_state=entered localAudio=1`
  - connected/timer should start only after at least one remote media feed appears: `remoteFeeds>=1`
- If all devices have `localAudio=1` but still `remoteFeeds=0`, the remaining issue is Matrix mesh media negotiation, not UI state gating.

## 2026-06-01 Follow-up: Concise Call Records and Active Group Call Entry

Product rule:

- Private and group call records use the same compact form:
  - voice call: phone icon + `时长` or `未接通`
  - video call: video icon + `时长` or `未接通`
- Do not show redundant labels such as `语音通话`, `视频通话`, or `已接通`; duration itself means connected.
- Group chat should also display group call records in the timeline.
- If a group has an active call, any member who enters the group chat should see `正在群通话` in the middle title capsule and can tap it to enter the call, even if they were not originally invited.

Implementation notes:

- `call_timeline_events.dart` now treats `p2p.group_call.invite.v1`, `p2p.group_call.join.v1`, and `p2p.group_call.leave.v1` as product call timeline events and collapses them into one visible call record per call id.
- `ChatCallRecordBubble` is the shared private/group call-record card, using the existing phone/video icons and concise result text.
- `GroupChatPage` derives an active group-call entry from the controller state first, then timeline product events, and routes the title capsule through `groupCallJoinRoute`.
- `GroupCallPage` passes the existing product `callId` into `startOrJoinGroupCall`, so joining from the group header does not accidentally create a new product call state.

Verification:

```bash
flutter test test/call_timeline_events_test.dart test/chat_message_cards_test.dart test/chat_capsule_chrome_test.dart test/group_call_member_select_page_test.dart test/group_call_page_test.dart
flutter test test/widget_test.dart --plain-name 'group chat header opens active group call from title capsule'
flutter analyze lib/presentation/pages/group_chat_page.dart lib/presentation/pages/group_call_page.dart lib/presentation/pages/group_call_member_select_page.dart lib/presentation/call/voice_call_controller.dart lib/presentation/chat/call_timeline_events.dart lib/presentation/chat/chat_message_cards.dart lib/presentation/chat/chat_capsule_chrome.dart test/call_timeline_events_test.dart test/chat_message_cards_test.dart test/chat_capsule_chrome_test.dart test/group_call_member_select_page_test.dart test/group_call_page_test.dart test/widget_test.dart
```

Observed result:

- Focused call/timeline/header/group-call tests: 46 tests passed.
- Group-chat active-call header route regression passed.
- Focused analyze: no issues.

## 2026-06-01 Follow-up: Mesh Participant Setup Must Wait For Entered State

Observed issue:

- Three-node group voice-call testing could reach a split media graph:
  - caller had two remote media feeds
  - each receiver had only one remote media feed
  - one receiver could show `准备加入` or delayed timer even though the other devices saw it as joined
- Logs showed Matrix SDK member updates arriving while `GroupCallSession` was still `localCallFeedInitialized` or `localCallFeedUninitialized`.
- Those early remote participants were being added to `_participants` before the group call reached `entered`.
- Later, once the local device actually entered, the mesh setup path skipped those remote participants because `oldPcopy.contains(rp)` was already true.

Root cause:

- Matrix group-call membership is not the same as a locally entered media session.
- Remote participants must not be recorded as already handled before local media enter completes. If they are recorded too early, the SDK never creates the missing P2P call sessions for that peer pair.

Corrected rule:

- Local participant may be tracked before the call is fully entered.
- Remote participants are ignored until `GroupCallState.entered`.
- Only after `entered` can a remote participant be added to `_participants` and queued for mesh P2P setup.

Code changes:

- `vendor/matrix/lib/src/voip/group_call_session.dart`
  - Remote `newP.add(rp)` now happens after the `GroupCallState.entered` guard.
  - Existing remote participants are still skipped by `oldPcopy.contains(rp)` after they have been legitimately added.
- `test/matrix_group_call_transport_policy_test.dart`
  - Adds a static regression assertion that remote participants cannot enter `_participants` before the `entered` guard.

Verification:

```bash
flutter test test/matrix_group_call_transport_policy_test.dart
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/app_router_test.dart test/matrix_group_call_transport_policy_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/matrix_group_call_transport_policy_test.dart test/group_call_controller_test.dart
flutter build ios --simulator --debug --dart-define=P2P_CALL_AUTOTEST=true
```

Observed result:

- Focused SDK transport regression passed.
- Focused group-call/router regression set: 52 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded and was installed on:
  - `iPhone 17 Pro` (`15F5EAB9-9711-4F34-890F-1B2C3A5F038C`)
  - `iPhone 17 Pro Max` (`15548A95-2814-4724-9B52-359F9DB97576`)
  - `P2P IM Clean Test` (`1F4878F3-25B4-404A-BF9D-CE65027800D8`)

Three-node media verification:

- Verification log directory: `/tmp/p2p_group_call_verify_existing_call_d64e5d8843afdb0e5010220f85aaf571`
- Product call id: `call_d64e5d8843afdb0e5010220f85aaf571`
- Final media/stats logs showed all three devices with:
  - `matrix_state=entered`
  - `ui_state=connected`
  - `localAudio=1`
  - `remoteFeeds=2`
  - one inbound and one outbound RTP stream for each remote participant
  - increasing audio packet/byte counters plus non-empty audio `level` and `energy`

Important test-harness note:

- The outgoing `/group-call` route currently creates or reuses the product AS call id internally. Supplying a `call_id` query parameter for an outgoing autotest route does not force the caller to use that id.
- A false split test happened when receivers were launched with a stale route-file `call_id` while the caller used the AS-created active call id.
- For future automated three-node tests, first read the caller's active AS call id, then launch receivers with that exact id, or explicitly add an autotest-only outgoing route mode that accepts a fixed call id.

## 2026-06-01 Follow-up: One Member Leaving Must Not End A Three-Person Group Call

Observed issue:

- In a three-person group call, when one member tapped `离开`, all three clients could exit the call page.
- This violated the product rule: one member leaving a multi-person group call only removes that member. The remaining members continue. Automatic close is only valid when a previously real multi-person call drops to one remaining local member.

Root cause:

- `leaveGroupCall()` reported `group_leave` to AS as a terminal call-ended event for every local leave.
- Matrix `GroupCallState.ended` callbacks could also report the whole AS call ended after a local leave.
- Auto-leave participant counting preferred product `joinedUserIds` first. If product join/leave events undercounted the remaining users while media streams still showed two participants, the client could mistakenly think it was the last member.

Corrected rule:

- AS terminal `ended` is reported on local leave only when the participant count before leaving is `<= 2`.
- For three or more active participants, local leave only publishes the product participant leave event and exits the local page; it must not globally end the AS call.
- Matrix ended callbacks use the same global-end gate.
- Auto-leave participant count now uses the strongest current evidence across media participants, product joined ids, Matrix participants, and fallback participant count. This prevents a single undercounted source from forcing everyone out while media still shows remaining members.

Regression added:

- A state with local plus one remaining media participant and only local product joined id must not auto-leave.
- Local leave with three participants must not report the global call ended.
- Local leave or Matrix ended with two or fewer participants may still report the group call ended.

Verification:

```bash
flutter test test/group_call_controller_test.dart --plain-name 'group call auto leave count keeps remaining media members after leave'
flutter test test/group_call_controller_test.dart --plain-name 'group call local leave only reports global end near final member'
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/app_router_test.dart test/matrix_group_call_transport_policy_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
flutter build ios --simulator --debug --dart-define=P2P_CALL_AUTOTEST=true
```

Observed result:

- New focused regressions passed.
- Focused group-call/router regression set: 54 tests passed.
- Focused analyze: no issues.
- iOS Simulator debug build succeeded and was installed on the three active simulators.

## 2026-06-02 Product Boundary: P2P Mesh Versus MatrixRTC + LiveKit/SFU

Decision:

- Current P2P WebRTC Mesh group calls are the MVP/small-room transport, not the large-room transport.
- P2P Mesh should stay enabled for small groups because it is simple, decentralized, and already verified with three real nodes.
- Large group calls need a second media transport: `matrixrtc_livekit_sfu`.

Recommended product limits:

- P2P group voice:
  - default/recommended limit: 6 users
  - experimental hard product limit: 8 users
- P2P group video:
  - default/recommended limit: 3 users
  - hard product limit: 4 users
- Above those limits, or when weak network/cross-region/low-device-performance signals are detected, the product should prompt or automatically select SFU when available.

Architecture rule:

- Keep one product call system:
  - AS call session
  - invitation and participant state
  - call records
  - permissions
  - UI state
  - lifecycle and failure handling
- Add multiple media transports underneath:
  - `p2p_mesh`
  - `matrixrtc_livekit_sfu`
- Do not fork the whole app or build two separate call products.

SFU deployment rule:

- MatrixRTC + LiveKit/SFU requires a media relay node for that call.
- The relay can be:
  - user self-hosted on a stronger node
  - optional P2P IM public/regional SFU
  - hybrid: self-hosted first, public/regional fallback
- The ordinary recommended user node, currently 2 vCPU / 2 GB RAM, should not default to running LiveKit/SFU for large calls. It is for Matrix/Dendrite, AS, Portal, Agent integration, and P2P signaling.
- Deployment skill should keep the base node simple and add SFU as an explicit capability check/option, not as a default service on small VPS plans.

Privacy and product messaging:

- P2P Mesh means media flows directly between participants, except when TURN relay is required by NAT/weak network.
- SFU means media flows through a relay. This improves large-call reliability but changes the trust boundary.
- If using P2P IM public/regional SFU, the app must be clear that media is relayed through optional shared infrastructure, while identity, messages, relationships, and Agent data remain on the user's own node.

## 2026-06-02 Group Video Rendering Implementation

Scope:

- Group video now reuses the same AS call session, Matrix group call room-event signaling, invited-member roster, participant join/leave state, timeout, recovery, and auto-leave rules as group voice.
- The difference is limited to media acquisition and UI rendering:
  - video calls explicitly request microphone plus front camera before entering the Mesh group call.
  - if camera acquisition fails on simulator or a device without usable camera, the client joins with audio and marks video as muted/unavailable instead of failing the whole group call.
  - `GroupCallUiState` now carries `videoStreams`, derived from the Matrix `MeshBackend` local and remote user-media feeds.
  - the group video page renders a full-screen tile grid with real RTC video surfaces when streams are available, and per-user placeholders when a stream has no video.
  - the group video camera control is only enabled when the local stream has a real video track; on simulator/no-camera fallback it shows `摄像头不可用` instead of pretending the camera can be toggled.

Regression coverage:

- `group video call page renders available video feeds`
  - verifies that group video UI consumes `videoStreams` and renders video tiles instead of only showing the old waiting placeholder.
- `group video calls enter and recover with an explicit video stream`
  - verifies that both initial entry and stalled-media recovery create a group video local stream explicitly, rather than falling back to a null/default path.
- `group video camera control is disabled without local video track`
  - verifies that simulator/no-camera fallback cannot trigger a meaningless camera toggle.
- `group video camera control toggles when local video track exists`
  - verifies that real video-track calls still invoke the group camera mute/unmute controller path.

Verification:

```bash
flutter test test/group_call_page_test.dart --plain-name 'group video call page renders available video feeds'
flutter test test/group_call_controller_test.dart --plain-name 'group video calls enter and recover with an explicit video stream'
flutter test test/group_call_controller_test.dart test/group_call_page_test.dart test/group_call_member_select_page_test.dart test/matrix_group_call_transport_policy_test.dart
flutter analyze lib/presentation/call/voice_call_controller.dart lib/presentation/pages/group_call_page.dart test/group_call_controller_test.dart test/group_call_page_test.dart
```

Current limits:

- iOS Simulator may not provide a usable real camera source. Simulator verification can confirm route, media-state wiring, fallback behavior, and RTC tile rendering; real camera image verification still needs a real iPhone.

Manual verification, 2026-06-02:

- Rebuilt and installed one debug simulator package on:
  - `p2p-liyanan.com` / Yanan / iPhone 17 Pro Max
  - `p2p-im.com` / Lee / P2P IM Clean Test
  - `p2p-im-test.com` / Test Node / iPhone 17 Pro
- Started a group video call in `Group Test 2`; Lee and Test Node accepted the group video invitation.
- All three clients reached the group video call screen with elapsed timers and participant tiles.
- Simulator camera fallback rendered `摄像头不可用` for each tile, which is expected on simulator.
- Matrix/WebRTC debug logs showed `matrix_state=entered`, `ui_state=connected`, local audio live, and two remote audio feeds connected for the three-node call; video track count stayed `0` because the simulator did not provide a usable camera.

Last-member auto-leave fix, 2026-06-02:

- Bug: in a three-person group video call, after two members hung up, the remaining member sometimes stayed on the call screen.
- Root cause: Matrix group-call `participants` can remain stale after remote members leave. The old auto-leave count used stale Matrix participants, so it still thought there were multiple members.
- Rule: last-member auto-leave should prefer real media-connected users and AS/product joined users; Matrix participants are only a fallback when neither product nor media state is available.
- Regression: `group call auto leave ignores stale Matrix participants after leaves`.
