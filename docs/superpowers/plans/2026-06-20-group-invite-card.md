# Group Invite Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Existing group invitations send direct-chat cards while the owner node records invitees and rejects joins from users who were not invited.

**Architecture:** Reuse the existing `p2p_members` invite record (`membership = invite`) as the authorization source. Add a structured `group_invite` message payload to the same `rooms.send` product path used by channel shares, then make card-based `groups.join` require an invite record when `invite_event_id` or `direct_room_id` is present.

**Tech Stack:** Go service/tests in `dendrite-as/p2p`; Flutter/Dart client in `p2p-client/lib`; Flutter widget and HTTP tests in `p2p-client/test`.

---

## File Map

- Modify `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\service.go`
  - Preserve `group_invite` structured message payloads.
  - Add card-join invite validation before joining a group from invite-card context.
- Modify `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\transport_test.go`
  - Cover the Matrix payload emitted for group invite card messages.
- Modify `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\business_state_test.go`
  - Cover recorded invite authorization for `groups.join`.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\as_client.dart`
  - Add `sendGroupInviteMessage` to `AsClient`.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\http_as_client.dart`
  - Post `message_type: group_invite` through `rooms/{directRoomId}/send`.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\mock_as_client.dart`
  - Add mock implementation for demo/tests.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\lib\presentation\groups\group_member_invite_flow.dart`
  - Record invites with `inviteGroupMembers`, then send direct-chat invite cards.
  - Report sent, failed, and skipped counts.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\lib\presentation\pages\chat_page.dart`
  - Show a friendly invite-invalid message when card join returns `403`.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\test\http_as_client_test.dart`
  - Cover `sendGroupInviteMessage`.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\test\widget_test.dart`
  - Cover group detail/info invite flows sending card invites.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\docs\FEATURES.md`
  - Update group invite status.
- Modify `C:\Users\84960\Desktop\direxio\p2p-client\docs\AS_API_CHANGES.md`
  - Document the new group invite card send contract and stricter card join validation.

---

### Task 1: Backend Structured Group Invite Message

**Files:**
- Modify: `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\service.go`
- Test: `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\transport_test.go`

- [ ] **Step 1: Write the failing transport test**

Add this test next to `TestRoomSendPreservesChannelSharePayload`:

```go
func TestRoomSendPreservesGroupInvitePayload(t *testing.T) {
	transport := &recordingTransport{}
	service := NewServiceWithTransport(Config{ServerName: "example.com"}, transport)
	bootstrapService(t, service)

	mustHandle[map[string]any](t, service, "rooms.send", map[string]any{
		"room_id":      "!dm:example.com",
		"content":      "邀请加入群聊\n产品群",
		"message_type": "group_invite",
		"group_invite": map[string]any{
			"msgtype":              "p2p.group.invite.v1",
			"group_room_id":        "!group:example.com",
			"group_name":           "产品群",
			"inviter_mxid":         "@owner:example.com",
			"inviter_display_name": "Owner",
			"direct_room_id":       "!dm:example.com",
		},
	})

	if len(transport.messages) != 1 {
		t.Fatalf("expected Matrix message, got %#v", transport.messages)
	}
	content := transport.messages[0].Content
	if content["msgtype"] != "p2p.group.invite.v1" || content["client_type"] != "group_invite" || content["p2p.message_type"] != "group_invite" {
		t.Fatalf("expected group invite markers in Matrix content, got %#v", content)
	}
	if content["group_room_id"] != "!group:example.com" || content["group_name"] != "产品群" || content["direct_room_id"] != "!dm:example.com" {
		t.Fatalf("expected flattened group invite payload, got %#v", content)
	}
	invite, ok := content["group_invite"].(map[string]any)
	if !ok || invite["group_room_id"] != "!group:example.com" {
		t.Fatalf("expected nested group invite payload, got %#v", content["group_invite"])
	}
}
```

- [ ] **Step 2: Run the failing backend test**

Run:

```powershell
go test ./p2p -run TestRoomSendPreservesGroupInvitePayload
```

Expected: FAIL because `applyStructuredRoomMessageContent` does not preserve `group_invite` yet.

- [ ] **Step 3: Implement minimal structured message support**

In `applyStructuredRoomMessageContent`, add the `group_invite` case:

```go
	case "group_invite":
		invite, ok := params["group_invite"].(map[string]any)
		if !ok {
			return
		}
		content["p2p.message_type"] = "group_invite"
		content["group_invite"] = invite
		content["msgtype"] = fallbackString(trimString(invite["msgtype"]), "p2p.group.invite.v1")
		for _, key := range []string{"group_room_id", "group_name", "inviter_mxid", "inviter_display_name", "direct_room_id"} {
			if value := trimString(invite[key]); value != "" {
				content[key] = value
			}
		}
```

- [ ] **Step 4: Run backend transport tests**

Run:

```powershell
go test ./p2p -run "TestRoomSendPreserves(ChannelSharePayload|GroupInvitePayload)"
```

Expected: PASS.

- [ ] **Step 5: Commit backend message support**

Run:

```powershell
git -C C:\Users\84960\Desktop\direxio\dendrite-as add p2p\service.go p2p\transport_test.go
git -C C:\Users\84960\Desktop\direxio\dendrite-as commit -m "feat: preserve group invite card messages"
```

---

### Task 2: Backend Invite Authorization For Card Joins

**Files:**
- Modify: `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\service.go`
- Test: `C:\Users\84960\Desktop\direxio\dendrite-as\p2p\business_state_test.go`

- [ ] **Step 1: Write failing join authorization tests**

Add these tests near the pending group invite tests:

```go
func TestGroupCardJoinRequiresRecordedInvite(t *testing.T) {
	service := NewService(Config{ServerName: "example.com"})
	bootstrapService(t, service)
	group := mustHandle[groupRecord](t, service, "groups.create", map[string]any{
		"name": "产品群",
	})

	_, apiErr := service.Handle(context.Background(), "groups.join", map[string]any{
		"room_id":         group.RoomID,
		"user_id":         "@alice:remote.example",
		"group_name":      group.Name,
		"invite_event_id": "$invite",
		"direct_room_id":  "!dm:remote.example",
	})
	if apiErr == nil || apiErr.Status != 403 {
		t.Fatalf("expected forbidden card join without invite, got %#v", apiErr)
	}
}

func TestGroupCardJoinConsumesRecordedInvite(t *testing.T) {
	service := NewService(Config{ServerName: "example.com"})
	bootstrapService(t, service)
	group := mustHandle[groupRecord](t, service, "groups.create", map[string]any{
		"name": "产品群",
	})
	mustHandle[map[string]any](t, service, "groups.invite", map[string]any{
		"room_id": group.RoomID,
		"user_id": "@alice:remote.example",
	})

	result := mustHandle[map[string]any](t, service, "groups.join", map[string]any{
		"room_id":         group.RoomID,
		"user_id":         "@alice:remote.example",
		"group_name":      group.Name,
		"invite_event_id": "$invite",
		"direct_room_id":  "!dm:remote.example",
	})

	member := result["member"].(memberRecord)
	if member.UserID != "@alice:remote.example" || member.Membership != "join" {
		t.Fatalf("expected invited user to join, got %#v", member)
	}
	stored, ok, err := service.lookupMember(context.Background(), group.RoomID, "@alice:remote.example")
	if err != nil || !ok || stored.Membership != "join" {
		t.Fatalf("expected stored joined member, got member=%#v ok=%v err=%v", stored, ok, err)
	}
}
```

- [ ] **Step 2: Run the failing join tests**

Run:

```powershell
go test ./p2p -run "TestGroupCardJoin(RequiresRecordedInvite|ConsumesRecordedInvite)"
```

Expected: the first test FAILS because `groups.join` currently allows card-context joins without an invite record.

- [ ] **Step 3: Add the join validation helper**

In `service.go`, add this helper near `joinMember`:

```go
func (s *Service) requireRecordedGroupInviteForCardJoin(ctx context.Context, roomID, userID string, params map[string]any) *apiError {
	if trimString(params["invite_event_id"]) == "" && trimString(params["direct_room_id"]) == "" {
		return nil
	}
	existing, ok, err := s.lookupMember(ctx, roomID, userID)
	if err != nil {
		return internalError(err)
	}
	if !ok || !strings.EqualFold(strings.TrimSpace(existing.Membership), "invite") {
		return statusError(403, "group invite is missing or expired")
	}
	return nil
}
```

In `joinMember`, after `userID` is resolved and before `lookupMember`, add:

```go
	if scope == "group" {
		if apiErr := s.requireRecordedGroupInviteForCardJoin(ctx, roomID, userID, params); apiErr != nil {
			return nil, apiErr
		}
	}
```

- [ ] **Step 4: Run backend join tests**

Run:

```powershell
go test ./p2p -run "TestGroupCardJoin(RequiresRecordedInvite|ConsumesRecordedInvite)"
```

Expected: PASS.

- [ ] **Step 5: Run broader backend p2p tests**

Run:

```powershell
go test ./p2p
```

Expected: PASS.

- [ ] **Step 6: Commit backend authorization**

Run:

```powershell
git -C C:\Users\84960\Desktop\direxio\dendrite-as add p2p\service.go p2p\business_state_test.go
git -C C:\Users\84960\Desktop\direxio\dendrite-as commit -m "feat: require recorded group card invites"
```

---

### Task 3: Flutter AS Client Group Invite Card API

**Files:**
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\as_client.dart`
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\http_as_client.dart`
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\lib\data\mock_as_client.dart`
- Test: `C:\Users\84960\Desktop\direxio\p2p-client\test\http_as_client_test.dart`

- [ ] **Step 1: Write the failing HTTP client test**

Add this test near `sendChannelShareMessage posts channel metadata through AS`:

```dart
test('sendGroupInviteMessage posts group invite card through AS', () async {
  final client = HttpAsClient(
    baseUri: Uri.parse('https://p2p-im.com/_as'),
    portalToken: 'portal-token',
    httpClient: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/_as/rooms/!dm%3Ap2p-im.com/send');
      expect(request.headers['Authorization'], 'Bearer portal-token');
      expect(jsonDecode(request.body), {
        'content': '邀请加入群聊\n产品群',
        'message_type': 'group_invite',
        'group_invite': {
          'msgtype': 'p2p.group.invite.v1',
          'group_room_id': '!group:p2p-im.com',
          'group_name': '产品群',
          'inviter_mxid': '@owner:p2p-im.com',
          'inviter_display_name': 'Owner',
          'direct_room_id': '!dm:p2p-im.com',
        },
      });
      return http.Response(jsonEncode({'event_id': r'$group-invite'}), 200);
    }),
  );

  final eventId = await client.sendGroupInviteMessage(
    directRoomId: '!dm:p2p-im.com',
    groupRoomId: '!group:p2p-im.com',
    groupName: '产品群',
    inviterMxid: '@owner:p2p-im.com',
    inviterDisplayName: 'Owner',
  );

  expect(eventId, r'$group-invite');
});
```

- [ ] **Step 2: Run the failing HTTP client test**

Run:

```powershell
flutter test --no-pub test/http_as_client_test.dart --plain-name "sendGroupInviteMessage posts group invite card through AS"
```

Expected: FAIL because `sendGroupInviteMessage` is not defined.

- [ ] **Step 3: Add the `AsClient` method signature**

In `as_client.dart`, add after `sendChannelShareMessage`:

```dart
  /// POST /_as/rooms/{directRoomId}/send with message_type=group_invite.
  Future<String> sendGroupInviteMessage({
    required String directRoomId,
    required String groupRoomId,
    required String groupName,
    required String inviterMxid,
    String inviterDisplayName = '',
  });
```

- [ ] **Step 4: Implement `HttpAsClient.sendGroupInviteMessage`**

In `http_as_client.dart`, add after `sendChannelShareMessage`:

```dart
  @override
  Future<String> sendGroupInviteMessage({
    required String directRoomId,
    required String groupRoomId,
    required String groupName,
    required String inviterMxid,
    String inviterDisplayName = '',
  }) async {
    final trimmedDirectRoomId = directRoomId.trim();
    final trimmedGroupRoomId = groupRoomId.trim();
    final trimmedGroupName =
        groupName.trim().isEmpty ? '群聊' : groupName.trim();
    final response = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(trimmedDirectRoomId)}/send',
      body: {
        'content': '邀请加入群聊\n$trimmedGroupName',
        'message_type': 'group_invite',
        'group_invite': {
          'msgtype': 'p2p.group.invite.v1',
          'group_room_id': trimmedGroupRoomId,
          'group_name': trimmedGroupName,
          if (inviterMxid.trim().isNotEmpty)
            'inviter_mxid': inviterMxid.trim(),
          if (inviterDisplayName.trim().isNotEmpty)
            'inviter_display_name': inviterDisplayName.trim(),
          'direct_room_id': trimmedDirectRoomId,
        },
      },
      allowedStatusCodes: const {200},
    );
    return response['event_id'] as String? ?? '';
  }
```

- [ ] **Step 5: Implement `MockAsClient.sendGroupInviteMessage`**

In `mock_as_client.dart`, add after `sendChannelShareMessage`:

```dart
  @override
  Future<String> sendGroupInviteMessage({
    required String directRoomId,
    required String groupRoomId,
    required String groupName,
    required String inviterMxid,
    String inviterDisplayName = '',
  }) async {
    await Future.delayed(_latency);
    return 'mock-group-invite-event';
  }
```

- [ ] **Step 6: Run the HTTP client test**

Run:

```powershell
flutter test --no-pub test/http_as_client_test.dart --plain-name "sendGroupInviteMessage posts group invite card through AS"
```

Expected: PASS.

- [ ] **Step 7: Commit Flutter client API**

Run:

```powershell
git add lib\data\as_client.dart lib\data\http_as_client.dart lib\data\mock_as_client.dart test\http_as_client_test.dart
git commit -m "feat: add group invite card send API"
```

---

### Task 4: Flutter Invite Flow Sends Recorded Card Invites

**Files:**
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\lib\presentation\groups\group_member_invite_flow.dart`
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\test\widget_test.dart`

- [ ] **Step 1: Extend `_TrackingAsClient` in widget tests**

In `_TrackingAsClient`, add fields:

```dart
  int sendGroupInviteMessageCalls = 0;
  List<String> sentGroupInviteDirectRoomIds = const [];
  List<String> sentGroupInviteGroupRoomIds = const [];
  List<String> sentGroupInviteGroupNames = const [];
```

Add an override near `sendChannelShareMessage`:

```dart
  @override
  Future<String> sendGroupInviteMessage({
    required String directRoomId,
    required String groupRoomId,
    required String groupName,
    required String inviterMxid,
    String inviterDisplayName = '',
  }) async {
    sendGroupInviteMessageCalls++;
    sentGroupInviteDirectRoomIds = [
      ...sentGroupInviteDirectRoomIds,
      directRoomId,
    ];
    sentGroupInviteGroupRoomIds = [
      ...sentGroupInviteGroupRoomIds,
      groupRoomId,
    ];
    sentGroupInviteGroupNames = [
      ...sentGroupInviteGroupNames,
      groupName,
    ];
    return 'group-invite-card-event-$sendGroupInviteMessageCalls';
  }
```

- [ ] **Step 2: Change the existing group detail invite test expectation first**

In the test named `group detail invite button filters existing members before AS invite`, replace the final expectations with:

```dart
    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.invitedGroupMembers, ['@carol:p2p-carol.com']);
    expect(asClient.sendGroupInviteMessageCalls, 1);
    expect(asClient.sentGroupInviteDirectRoomIds, ['!carol:p2p-im.com']);
    expect(asClient.sentGroupInviteGroupRoomIds, ['!group:p2p-im.com']);
    expect(asClient.sentGroupInviteGroupNames, ['真实群']);
    expect(find.text('已发送 1 个群邀请卡片'), findsOneWidget);
```

- [ ] **Step 3: Change the existing group info invite test expectation first**

In the test named `group info invite button posts member invites through AS`, replace the final expectations with:

```dart
    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.invitedGroupMembers, ['@carol:p2p-carol.com']);
    expect(asClient.sendGroupInviteMessageCalls, 1);
    expect(asClient.sentGroupInviteDirectRoomIds, ['!carol:p2p-carol.com']);
```

- [ ] **Step 4: Run the failing widget tests**

Run:

```powershell
flutter test --no-pub test/widget_test.dart --plain-name "group detail invite button filters existing members before AS invite"
flutter test --no-pub test/widget_test.dart --plain-name "group info invite button posts member invites through AS"
```

Expected: FAIL because `showInviteGroupMembersFlow` records invites but does not send cards yet.

- [ ] **Step 5: Implement card sending in `showInviteGroupMembersFlow`**

In `group_member_invite_flow.dart`, replace the post-selection `try` body with this logic:

```dart
    final selectedContacts = [
      for (final contact in candidates)
        if (selected.contains(contact.userId.trim())) contact,
    ];
    final sendableContacts = selectedContacts
        .where((contact) => contact.roomId.trim().isNotEmpty)
        .toList(growable: false);
    final skippedCount = selectedContacts.length - sendableContacts.length;
    final asClient = ref.read(asClientProvider);
    final result = await asClient.inviteGroupMembers(
      roomId: trimmedRoomId,
      invite: [
        for (final contact in sendableContacts) contact.userId.trim(),
      ],
    );
    var sentCount = 0;
    var failedCount = 0;
    final groupName = _groupInviteRoomName(ref, trimmedRoomId);
    final inviterMxid = ref.read(asSyncCacheProvider).bootstrap?.user.userId ?? '';
    for (final contact in sendableContacts) {
      try {
        await asClient.sendGroupInviteMessage(
          directRoomId: contact.roomId.trim(),
          groupRoomId: trimmedRoomId,
          groupName: groupName,
          inviterMxid: inviterMxid,
        );
        sentCount++;
      } on Object {
        failedCount++;
      }
    }
    unawaited(_refreshBootstrapAfterInvite(ref));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_groupInviteResultMessage(
          sentCount: sentCount,
          skippedCount: skippedCount,
          failedCount: failedCount,
          recordedCount: result.invitedCount,
        )),
      ),
    );
```

Add these helpers below `groupMemberInviteCandidates`:

```dart
String _groupInviteRoomName(WidgetRef ref, String roomId) {
  final syncCache = ref.read(asSyncCacheProvider);
  for (final group in syncCache.bootstrap?.groups ?? const []) {
    if (group.roomId.trim() == roomId.trim() && group.name.trim().isNotEmpty) {
      return group.name.trim();
    }
  }
  return '群聊';
}

String _groupInviteResultMessage({
  required int sentCount,
  required int skippedCount,
  required int failedCount,
  required int recordedCount,
}) {
  if (sentCount == 0 && recordedCount == 0) {
    return '所选联系人已在群聊中';
  }
  final parts = <String>['已发送 $sentCount 个群邀请卡片'];
  if (skippedCount > 0) parts.add('$skippedCount 个联系人缺少私聊，已跳过');
  if (failedCount > 0) parts.add('$failedCount 个发送失败');
  return parts.join('，');
}
```

- [ ] **Step 6: Run widget invite tests**

Run:

```powershell
flutter test --no-pub test/widget_test.dart --plain-name "group detail invite button filters existing members before AS invite"
flutter test --no-pub test/widget_test.dart --plain-name "group info invite button posts member invites through AS"
```

Expected: PASS.

- [ ] **Step 7: Commit invite flow**

Run:

```powershell
git add lib\presentation\groups\group_member_invite_flow.dart test\widget_test.dart
git commit -m "feat: send group invite cards from invite flow"
```

---

### Task 5: Receiver-Side Forbidden Message And Docs

**Files:**
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\lib\presentation\pages\chat_page.dart`
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\docs\FEATURES.md`
- Modify: `C:\Users\84960\Desktop\direxio\p2p-client\docs\AS_API_CHANGES.md`

- [ ] **Step 1: Add the forbidden message helper**

In `chat_page.dart`, near `_joinGroupInvite`, add:

```dart
String _joinGroupInviteFailureMessage(Object error) {
  if (error is AsClientException && error.statusCode == 403) {
    return '你未被邀请或邀请已失效';
  }
  return '加入群聊失败: $error';
}
```

Then in `_joinGroupInvite`, replace the snackbar error text with:

```dart
        SnackBar(content: Text(_joinGroupInviteFailureMessage(e))),
```

- [ ] **Step 2: Update feature docs**

In `docs/FEATURES.md`, change the group section notes for group list/invites to state:

```markdown
| Group list | `/groups`, `groups_list_page.dart` | Real | Uses AS bootstrap groups and excludes stale direct metadata. Existing group invitations are sent as direct-chat cards after the owner node records the invited MXID; card joins are accepted only for recorded invitees. |
```

- [ ] **Step 3: Update AS API change docs**

Add this section near the 2026-06-20 client follow-up entries in `docs/AS_API_CHANGES.md`:

```markdown
### Group Invite Cards

Frontend alignment:

- Existing group member invitations now record invitees on the owner node and send `message_type: "group_invite"` through `POST /_as/rooms/{directRoomId}/send`.
- The Matrix message payload carries `msgtype: "p2p.group.invite.v1"`, `group_room_id`, `group_name`, `inviter_mxid`, optional `inviter_display_name`, and `direct_room_id`.
- `POST /_as/groups/{roomId}/join` rejects invite-card joins with `403` when the joining MXID does not have a recorded group invite.
```

- [ ] **Step 4: Run focused Flutter checks**

Run:

```powershell
flutter test --no-pub test/http_as_client_test.dart --plain-name "sendGroupInviteMessage posts group invite card through AS"
flutter test --no-pub test/group_invite_join_flow_test.dart
flutter test --no-pub test/widget_test.dart --plain-name "group detail invite button filters existing members before AS invite"
flutter test --no-pub test/widget_test.dart --plain-name "group info invite button posts member invites through AS"
```

Expected: PASS.

- [ ] **Step 5: Run analysis**

Run:

```powershell
flutter analyze --no-pub
```

Expected: PASS.

- [ ] **Step 6: Commit receiver message and docs**

Run:

```powershell
git add lib\presentation\pages\chat_page.dart docs\FEATURES.md docs\AS_API_CHANGES.md
git commit -m "docs: document group invite card contract"
```

---

## Final Verification

- [ ] Run backend verification:

```powershell
go test ./p2p
```

Expected: PASS from `C:\Users\84960\Desktop\direxio\dendrite-as`.

- [ ] Run Flutter verification:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/http_as_client_test.dart --plain-name "sendGroupInviteMessage posts group invite card through AS"
flutter test --no-pub test/group_invite_join_flow_test.dart
flutter test --no-pub test/widget_test.dart --plain-name "group detail invite button filters existing members before AS invite"
flutter test --no-pub test/widget_test.dart --plain-name "group info invite button posts member invites through AS"
```

Expected: PASS from `C:\Users\84960\Desktop\direxio\p2p-client`.

---

## Self-Review

- Spec coverage: backend card payload preservation is covered in Task 1; invite recording and join authorization are covered in Task 2; Flutter API and sender flow are covered in Tasks 3 and 4; receiver forbidden message and docs are covered in Task 5.
- Placeholder scan: no placeholder markers remain.
- Type consistency: `sendGroupInviteMessage`, `group_invite`, `group_room_id`, `group_name`, `inviter_mxid`, `inviter_display_name`, and `direct_room_id` are named consistently across backend tests, client API, and docs.
