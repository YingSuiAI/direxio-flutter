# New Device Privacy Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make new-device login privacy-first by preventing automatic read-history downloads and defining the backend unread-only sync contract.

**Architecture:** The client owns local guardrails: chat-open must not request older history, startup warmup must not fetch message bodies, and only explicit triggers may request history. The AS backend owns strict unread-only recovery because Matrix `/sync` cannot express "only unread message bodies" by itself.

**Tech Stack:** Flutter, Riverpod, Matrix Dart SDK, Go AS Admin API, SQLite-backed AS message store.

---

### Task 1: Product Standard

**Files:**
- Create: `p2p-matrix-as/docs/NEW_DEVICE_PRIVACY_SYNC.md`

- [x] **Step 1: Define allowed and blocked data classes**

The standard says metadata, pending actions, and unread message bodies are allowed; read message bodies, recent read-message previews, and full media are blocked by default.

- [x] **Step 2: Define AS bootstrap and unread-only endpoint contracts**

The standard defines `GET /_as/sync/bootstrap` for metadata and `GET /_as/sync/unread?limit_per_room=200` for unread-only messages.

- [x] **Step 3: Define acceptance criteria**

The standard requires that new-device login and chat-open do not persist read message bodies before explicit user action.

### Task 2: Client History Guardrail

**Files:**
- Create: `p2p-matrix-client/lib/presentation/utils/message_history_policy.dart`
- Test: `p2p-matrix-client/test/message_history_policy_test.dart`
- Modify: `p2p-matrix-client/lib/presentation/pages/chat_page.dart`
- Modify: `p2p-matrix-client/lib/presentation/pages/group_chat_page.dart`

- [x] **Step 1: Write a failing policy test**

The test asserts `MessageHistoryLoadTrigger.chatOpen` is blocked, while `userLoadOlder` and `unreadRecovery` are allowed.

- [x] **Step 2: Implement the policy utility**

The utility centralizes the decision so later UI and backend sync code do not hard-code privacy behavior.

- [x] **Step 3: Gate automatic chat and group backfill**

Both chat surfaces now call the policy before running automatic `requestHistory` loops.

- [x] **Step 4: Verify**

Run `flutter test test/message_history_policy_test.dart`.

### Task 3: Backend Unread-Only Recovery

**Files:**
- Modify: `p2p-matrix-as/internal/admin/server.go`
- Modify: `p2p-matrix-as/internal/admin/*.go`
- Modify: `p2p-matrix-as/internal/store/messages.go`
- Test: `p2p-matrix-as/internal/admin/*_test.go`

- [x] **Step 1: Add tests for metadata-only bootstrap**

Test that bootstrap room rows may include `unread_count` and `last_activity_at` but do not include read `last_message` bodies.

- [x] **Step 2: Add tests for unread-only recovery**

Test that the unread endpoint returns only events after the user's read marker, capped by `limit_per_room`.

- [x] **Step 3: Implement AS endpoints**

Implement `GET /_as/sync/bootstrap` and `GET /_as/sync/unread` according to `NEW_DEVICE_PRIVACY_SYNC.md`.

Also implement `PUT /_as/sync/read-marker` so the active device can update the server-side unread boundary without requiring the AS to already have the marker event body.

- [x] **Step 4: Verify Go tests**

Run `go test ./...` from `p2p-matrix-as`.

### Task 4: Client AS Integration

**Files:**
- Modify: `p2p-matrix-client/lib/data/as_client.dart`
- Modify: `p2p-matrix-client/lib/data/http_as_client.dart`
- Modify: `p2p-matrix-client/lib/presentation/providers/app_warmup_provider.dart`
- Test: `p2p-matrix-client/test/http_as_client_test.dart`

- [x] **Step 1: Add client models for bootstrap and unread recovery**

Define typed Dart models matching the AS standard.

Read-marker reporting is already wired through `AsClient.updateReadMarker` and the chat page's Matrix read-marker flow.

- [x] **Step 2: Fetch metadata during warmup**

Warmup starts metadata sync in parallel with unread recovery. It caches metadata and preloads avatars but does not call the old Gateway history endpoint.

- [x] **Step 3: Fetch unread bodies only through unread recovery**

Unread recovery uses `MessageHistoryLoadTrigger.unreadRecovery`, starts before metadata sync, and is applied to the in-memory AS sync cache first so chat pages can render recovered unread messages while metadata continues loading.

- [x] **Step 4: Verify Flutter tests**

Run `flutter test` from `p2p-matrix-client`.

### Task 5: Matrix Initial Sync Privacy Baseline

**Files:**
- Create: `p2p-matrix-client/lib/data/matrix_privacy_sync.dart`
- Modify: `p2p-matrix-client/lib/presentation/providers/auth_provider.dart`
- Test: `p2p-matrix-client/test/matrix_privacy_sync_test.dart`

- [x] **Step 1: Add a failing baseline sync test**

The test asserts that the login-time Matrix baseline sync sends `timeline.limit = 0`, excludes message-like event types, omits `content` from `event_fields`, and uses the returned `next_batch`.

- [x] **Step 2: Implement baseline sync service**

`MatrixPrivacySyncService` performs one raw Matrix `/sync` with a privacy filter and parses only `next_batch`.

- [x] **Step 3: Seed Matrix SDK session before init**

`MatrixSdkSessionSeedStore` writes the baseline `next_batch` as the SDK `prevBatch` before `Client.init`, so the SDK's first normal sync starts after the privacy baseline.

- [x] **Step 4: Fail closed**

New portal login does not continue into Matrix SDK init if the privacy baseline cannot be established.

### Task 6: Persistent Recovered Unread Cache

**Files:**
- Create: `p2p-matrix-client/lib/data/recovered_unread_store.dart`
- Create: `p2p-matrix-client/lib/presentation/providers/recovered_unread_store_provider.dart`
- Modify: `p2p-matrix-client/lib/presentation/providers/app_warmup_provider.dart`
- Modify: `p2p-matrix-client/lib/presentation/pages/chat_page.dart`
- Modify: `p2p-matrix-client/lib/presentation/pages/group_chat_page.dart`
- Test: `p2p-matrix-client/test/recovered_unread_store_test.dart`
- Test: `p2p-matrix-client/test/app_warmup_service_test.dart`

- [x] **Step 1: Add failing cache tests**

The tests require recovered unread messages to persist, merge, dedupe by `event_id`, remove rooms opened by the user, and remove duplicates later delivered by Matrix timeline.

- [x] **Step 2: Implement app-owned unread cache**

Recovered unread messages are stored in `portal_im_recovered_unread.json`, separate from the Matrix SDK database.

- [x] **Step 3: Apply cached unread before network recovery**

Warmup reads cached recovered unread first, then merges fresh AS unread recovery and updates the in-memory provider.

- [x] **Step 4: Clear recovered unread after read marker sync**

Chat pages clear recovered unread for the room after syncing the AS read marker, and remove persisted duplicates when Matrix timeline later contains the same `event_id`.
