# Conversation Navigation Thinning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace scattered chat/group route guessing with the existing ProductCore navigation utility, and delete duplicated page-level decision logic.

**Architecture:** Keep navigation as a thin presentation utility in `product_conversation_navigation.dart`. ProductCore `AsConversation.kind` is the primary source of truth; Matrix `Room.isDirectChat` is only a fallback when no ProductCore conversation exists.

**Tech Stack:** Flutter, Dart, GoRouter route strings, Matrix SDK `Room`, ProductCore `AsConversation`.

---

### Task 1: Centralize Route Resolution

**Files:**
- Modify: `lib/presentation/utils/product_conversation_navigation.dart`
- Test: `test/product_conversation_navigation_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('ProductCore kind decides route before Matrix direct fallback', () {
  const roomId = '!room:p2p-im.com';
  final client = Client('ConversationNavigationProductKindTest')
    ..setUserId('@owner:p2p-im.com');
  final room = Room(id: roomId, client: client, membership: Membership.join);
  client.rooms.add(room);

  final route = productConversationRouteForRoom(
    room: room,
    conversations: const [
      AsConversation(
        conversationId: 'conv_group',
        roomId: roomId,
        kind: asConversationKindGroup,
        lifecycle: 'joined',
        title: '群聊',
        avatarUrl: '',
      ),
    ],
  );

  expect(route, '/group/%21room%3Ap2p-im.com?conversation=conv_group');
});

test('Matrix room direct flag is fallback only without ProductCore data', () {
  const roomId = '!direct:p2p-im.com';
  final client = Client('ConversationNavigationFallbackTest')
    ..setUserId('@owner:p2p-im.com');
  final room = Room(id: roomId, client: client, membership: Membership.join);
  room.setState(StrippedStateEvent(
    type: EventTypes.Direct,
    stateKey: '',
    senderId: '@owner:p2p-im.com',
    content: {'@alice:p2p-im.com': [roomId]},
  ));
  client.rooms.add(room);

  expect(
    productConversationRouteForRoom(room: room, conversations: const []),
    '/chat/%21direct%3Ap2p-im.com',
  );
});
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `flutter test test/product_conversation_navigation_test.dart`

Expected: failure because `productConversationRouteForRoom` does not exist.

- [ ] **Step 3: Implement thin helper**

Add `productConversationRouteForRoom()` to `product_conversation_navigation.dart`. It should find a ProductCore conversation by `room.id`; if found, reuse `productConversationRoute()`. If not found, fall back to `room.isDirectChat ? /chat : /group`.

- [ ] **Step 4: Verify utility tests pass**

Run: `flutter test test/product_conversation_navigation_test.dart`

Expected: all tests pass.

### Task 2: Remove Page-Level Guessing

**Files:**
- Modify: `lib/presentation/pages/search_page.dart`
- Modify: `lib/presentation/pages/contact_detail_page.dart`
- Test: existing widget tests plus new route-unit coverage.

- [ ] **Step 1: Replace search route guess**

In `search_page.dart`, replace local `room == null || room.isDirectChat ? /chat : /group` branching with the shared helper when a Matrix `room` is present.

- [ ] **Step 2: Simplify contact detail open path**

In `contact_detail_page.dart`, keep product conversation lookup, but move route generation through the shared helper and remove duplicated route string construction for real rooms.

- [ ] **Step 3: Run focused tests**

Run:

```bash
flutter test test/product_conversation_navigation_test.dart
flutter test test/widget_test.dart --plain-name 'groups list opens ProductCore group conversation route'
```

Expected: all tests pass.

### Task 3: Verify Scope Stayed Thin

**Files:**
- Inspect: `git diff --stat`
- Analyze: touched Dart files

- [ ] **Step 1: Verify no thick resolver was added**

Run: `git diff --stat`

Expected: one small utility extension, page logic reduced or replaced, no new service/provider layer.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/presentation/utils/product_conversation_navigation.dart lib/presentation/pages/search_page.dart lib/presentation/pages/contact_detail_page.dart test/product_conversation_navigation_test.dart`

Expected: no issues.

- [ ] **Step 3: Commit locally**

```bash
git add lib/presentation/utils/product_conversation_navigation.dart lib/presentation/pages/search_page.dart lib/presentation/pages/contact_detail_page.dart test/product_conversation_navigation_test.dart docs/superpowers/plans/2026-06-21-conversation-navigation-thinning.md
git commit -m "refactor: centralize conversation navigation"
```
