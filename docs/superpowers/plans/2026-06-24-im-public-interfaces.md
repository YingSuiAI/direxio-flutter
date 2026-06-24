# IM Public Interfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Flutter client to the signed IM/BI public interfaces documented in `C:/Users/84960/Desktop/direxio/admin/docs/im-public-interfaces.md`.

**Architecture:** Keep the public IM/BI API as a separate signed client under `lib/data`, independent from the authenticated `AsClient` / `/_p2p` ProductCore boundary. Presentation pages call the public client only for public-directory registration/search, BI reporting, and report submissions; Matrix and ProductCore remain responsible for room state and chat.

**Tech Stack:** Flutter, Riverpod, `http`, `crypto`, `image_picker`, existing Matrix SDK and AS client contracts.

---

### Task 1: Public SDK Config And Signing

**Files:**
- Create: `lib/data/im_public_config.dart`
- Modify: `lib/data/bi_analytics_service.dart`
- Modify: `lib/data/im_public_client.dart`
- Modify: `lib/presentation/providers/bi_analytics_provider.dart`
- Modify: `lib/presentation/providers/im_public_client_provider.dart`
- Test: `test/im_public_client_test.dart`

- [x] **Step 1: Write failing tests**

Add tests that construct `ImPublicClient(secret: 'bi-secret')`, call JSON, GET, and multipart endpoints, and assert every request contains `X-BI-Nonce` and `X-BI-Signature`.

- [x] **Step 2: Run red test**

Run: `flutter test --no-pub test/im_public_client_test.dart --plain-name signed`

Expected: FAIL because `ImPublicClient` currently sends no signature headers.

- [x] **Step 3: Implement shared config and signing**

Add `defaultImPublicBaseUrl = 'http://localhost:8888'`, `defaultImPublicSecret = 'f88c10fe-4559-fa77-b8b9-beadf468ddba'`, `canonicalImPublicJson`, `buildImPublicSignature`, and `signedImPublicHeaders`. Use them from BI and IM public clients.

- [x] **Step 4: Run green test**

Run: `flutter test --no-pub test/im_public_client_test.dart`

Expected: PASS.

### Task 2: BI Launch/Login Event Names

**Files:**
- Modify: `lib/data/bi_analytics_service.dart`
- Modify: `lib/presentation/providers/bi_analytics_provider.dart`
- Test: `test/im_public_client_test.dart`

- [x] **Step 1: Write failing test**

Assert first install reports `launch`, every startup reports `login` through the configured reporter, and payload can be `{}`.

- [x] **Step 2: Run red test**

Run: `flutter test --no-pub test/im_public_client_test.dart --plain-name BI`

Expected: FAIL because existing event names are `install`, `launch`, and `login` with non-empty base payloads.

- [x] **Step 3: Implement minimal behavior**

Keep the stored unique `deviceNo`, but change first-install startup to report `launch`, each startup/login to report `login`, and default payload to empty unless a caller passes data.

- [x] **Step 4: Run green test**

Run: `flutter test --no-pub test/im_public_client_test.dart --plain-name BI`

Expected: PASS.

### Task 3: Public Channel Directory Register And Close

**Files:**
- Modify: `lib/data/im_public_client.dart`
- Modify: `lib/presentation/channel/create_channel_sheet.dart`
- Modify: `lib/presentation/channel/channel_leave_flow.dart`
- Test: `test/im_public_client_test.dart`
- Test: focused existing channel tests if available

- [x] **Step 1: Write failing tests**

Assert `joinChannelDirectory` posts only `channelDomain` and `room_id`; assert `closeChannelDirectory(roomId)` posts `/im/channel/close` with only `room_id`.

- [x] **Step 2: Run red test**

Run: `flutter test --no-pub test/im_public_client_test.dart --plain-name channel`

Expected: FAIL because `tagId` is still sent and close is missing.

- [x] **Step 3: Implement integration**

After `asClient.createChannel` succeeds, if the draft is public and `channel.roomId` is non-empty, call `imPublicClient.joinChannelDirectory(channelDomain: _channelDirectoryDomain(channel), roomId: channel.roomId)`. When dissolving a channel, resolve its room id from cache and call `imPublicClient.closeChannelDirectory(roomId)` after AS dissolve succeeds.

- [x] **Step 4: Run green test**

Run: `flutter test --no-pub test/im_public_client_test.dart`

Expected: PASS.

### Task 4: Channel Search Uses Public List For Non-Room Queries

**Files:**
- Modify: `lib/presentation/pages/channel_search_page.dart`
- Test: `test/channel_search_page_test.dart`

- [x] **Step 1: Write failing widget test**

Override `imPublicClientProvider`, enter a non-room search term, and assert the UI calls `/im/channel/list` via the public client with `name=<query>` instead of `asClient.searchPublicChannels`.

- [x] **Step 2: Run red test**

Run: `flutter test --no-pub test/channel_search_page_test.dart --plain-name public`

Expected: FAIL because current non-room queries call `searchPublicChannels`.

- [x] **Step 3: Implement adapter**

For Matrix room IDs keep `getPublicChannelByRoomId`. For other input call `imPublicClient.listChannels(name: query)` and map `ImPublicChannelListing.channel` into the existing `_results`.

- [x] **Step 4: Run green test**

Run: `flutter test --no-pub test/channel_search_page_test.dart`

Expected: PASS.

### Task 5: Report Dialog Image Uploads And Target Types

**Files:**
- Modify: `lib/data/im_public_client.dart`
- Modify: `lib/presentation/widgets/report_reason_dialog.dart`
- Modify: `lib/presentation/pages/contact_detail_page.dart`
- Modify: `lib/presentation/pages/chat_info_page.dart`
- Modify: `lib/presentation/pages/channel_info_page.dart`
- Modify: `lib/presentation/pages/group_info_page.dart`
- Test: `test/im_public_client_test.dart`
- Test: `test/contact_detail_report_test.dart`
- Test: `test/channel_info_report_test.dart`

- [x] **Step 1: Write failing tests**

Assert `submitReport(files: [...])` sends multipart `/im/report` with text fields plus repeated `files`; assert contact uses `targetType = 1`, group uses `targetType = 2`, channel uses `targetType = 3`.

- [x] **Step 2: Run red tests**

Run: `flutter test --no-pub test/im_public_client_test.dart test/contact_detail_report_test.dart test/channel_info_report_test.dart`

Expected: FAIL because report UI still calls `AsClient.submitReport`, uses no image picker, and channel target type is wrong.

- [x] **Step 3: Implement upload flow**

Return `ReportReasonResult(reason, images)` from `ReportReasonDialog`; let the dialog use `ImagePicker.pickMultiImage`; submit through `imPublicClient.submitReport(..., files: images)`. Do not send `images` when files are present.

- [x] **Step 4: Run green tests**

Run: `flutter test --no-pub test/im_public_client_test.dart test/contact_detail_report_test.dart test/channel_info_report_test.dart`

Expected: PASS.

### Task 6: Docs, Skills, Smoke Checks, Commit

**Files:**
- Modify: `docs/P2P_API_BOUNDARY.md`
- Modify: `docs/FEATURES.md`
- Modify: `.codex/skills/p2p-client-as-contract/SKILL.md`
- Modify: `.codex/skills/p2p-client-channel-work/SKILL.md`

- [x] **Step 1: Document boundary**

Record that IM/BI public signed endpoints are not ProductCore `/_p2p` actions and are only used for public directory, BI, and report ingestion.

- [x] **Step 2: Run focused verification**

Run:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/im_public_client_test.dart test/channel_search_page_test.dart test/contact_detail_report_test.dart test/channel_info_report_test.dart
```

- [x] **Step 3: Host smoke check**

Call `GET http://localhost:8888/im/channel/list?page=1&pageSize=1&desc=false` with generated signed headers. Expected: either a valid envelope from the current host or a connection failure that is reported explicitly.

- [x] **Step 4: Self-review and commit**

Run `git diff --check`, inspect `git diff`, stage only related files, and commit with a message such as `feat: wire signed im public interfaces`.
