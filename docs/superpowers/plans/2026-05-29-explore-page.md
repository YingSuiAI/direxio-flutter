# Explore Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current bottom-nav channel tab with a Xiaohongshu-style Explore page containing swipeable Follow and Channel subpages.

**Architecture:** Keep the change client-only. The existing channel list remains backed by `ChannelInboxData` and `MockChannels`; a small mock follow-feed model feeds the new Follow subpage. `HomePage` owns the top-level tab switch, while the Explore page owns its internal `PageController`, avatar filter state, and channel category state.

**Tech Stack:** Flutter, Riverpod, GoRouter, Material Symbols, existing `AppTheme.sans` and `context.tk` design tokens.

---

### Task 1: Rename Bottom Tab and Header Behavior

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add or update widget expectations so the bottom nav contains `探索`, does not contain a top-level channel header for tab 2, and still exposes search/add on the Explore tab.

```dart
testWidgets('third home tab is explore with xhs style top actions',
    (tester) async {
  final client = Client('PortalIMExploreTest');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
    ),
  );
  await tester.pump();

  expect(find.text('探索'), findsOneWidget);
  expect(find.text('频道'), findsNothing);

  await tester.tap(find.text('探索'));
  await tester.pump();

  expect(find.text('关注'), findsOneWidget);
  expect(find.text('频道'), findsOneWidget);
  expect(find.byIcon(Symbols.search), findsOneWidget);
  expect(find.byIcon(Symbols.add), findsOneWidget);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'third home tab is explore'
```

Expected: FAIL because the tab is still `频道` and the Explore top layout does not exist.

- [ ] **Step 3: Minimal implementation**

Change `_tabTitles[2]` and the third `M3NavItem.label` to `探索`. Skip the outer `GlassHeader.primary` for tab 2 because Explore uses its own Xiaohongshu-style top bar. Route tab 2 to a new `_ExplorePage`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'third home tab is explore'
```

Expected: PASS.

### Task 2: Add Explore Page Shell and Swipeable Subpages

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test that taps `探索`, verifies the default `关注` subpage, taps `频道`, then drags back to `关注`.

```dart
testWidgets('explore page switches between follow and channel subpages',
    (tester) async {
  final client = Client('PortalIMExploreSwitchTest');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('探索'));
  await tester.pump();

  expect(find.text('全部'), findsOneWidget);
  expect(find.text('Yanan'), findsOneWidget);
  expect(find.text('P2P IM 官方'), findsNothing);

  await tester.tap(find.text('频道'));
  await tester.pumpAndSettle();

  expect(find.text('我的频道'), findsOneWidget);
  expect(find.text('P2P IM 官方'), findsOneWidget);

  await tester.drag(find.byType(PageView), const Offset(500, 0));
  await tester.pumpAndSettle();

  expect(find.text('Yanan'), findsOneWidget);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'explore page switches'
```

Expected: FAIL because no `_ExplorePage` exists yet.

- [ ] **Step 3: Minimal implementation**

Create `_ExplorePage` as a `ConsumerStatefulWidget` in `home_page.dart` with:

- A `PageController`.
- `_pageIndex`, `_followFilter`, and `_channelCategory` state.
- A custom top row: left `_HomePlusMenuButton`, center two text tab buttons, right search `GlassHeaderButton`.
- A `PageView` containing `_FollowExplorePage` and `_ChannelExplorePage`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'explore page switches'
```

Expected: PASS.

### Task 3: Add Follow Feed Mock Model and Avatar Filter

**Files:**
- Create: `lib/presentation/mock/mock_follow_feed.dart`
- Modify: `lib/presentation/pages/home_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test that the Follow subpage uses avatars as filters, not text channel tags.

```dart
testWidgets('follow explore subpage filters by followed avatar',
    (tester) async {
  final client = Client('PortalIMFollowFilterTest');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        currentUserProfileProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('探索'));
  await tester.pump();

  expect(find.text('全部'), findsOneWidget);
  expect(find.text('Alice'), findsOneWidget);
  expect(find.text('我的频道'), findsNothing);

  await tester.tap(find.text('Alice'));
  await tester.pump();

  expect(find.textContaining('图片消息'), findsOneWidget);
  expect(find.textContaining('私聊关系'), findsNothing);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'follow explore subpage filters'
```

Expected: FAIL because the mock follow feed and avatar filter do not exist yet.

- [ ] **Step 3: Minimal implementation**

Create `MockFollowFeedItem` and `MockFollowFeed` with stable author ids, names, initials, timestamps, titles, image style identifiers, and like counts. Render a horizontal avatar strip and a two-column feed using theme tokens, not hardcoded colors in production Dart.

- [ ] **Step 4: Run test to verify it passes**

Run:

```sh
flutter test test/widget_test.dart --plain-name 'follow explore subpage filters'
```

Expected: PASS.

### Task 4: Preserve Channel Filtering, Overflow, and Navigation

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Update existing channel tests first**

Update existing tests that tap `频道` from bottom nav so they tap `探索` first, then tap the inner `频道` subpage. Keep the channel assertions unchanged.

Affected tests:

- `mock auth build shows mock channels despite cached login`
- `channel tab presents personal channel inbox categories`
- `channel tab filters owned channels separately`
- `channel categories overflow horizontally and reveal more tags`
- `channel list opens the selected channel detail page`
- `empty real channel inbox exposes explicit design sample`

- [ ] **Step 2: Run tests to verify failures**

Run:

```sh
flutter test test/widget_test.dart --plain-name channel
```

Expected: FAIL until the channel subpage is wired through `_ExplorePage`.

- [ ] **Step 3: Minimal implementation**

Move the current `_ChannelPage` body into `_ChannelExplorePage`, keep `ChannelInboxData.categories`, `ChannelInboxData.filtered`, `_ChannelInboxList`, `_ChannelInboxTile`, and the route to `/channel/:channelId` unchanged.

- [ ] **Step 4: Run tests to verify pass**

Run:

```sh
flutter test test/widget_test.dart --plain-name channel
```

Expected: PASS.

### Task 5: Final Verification

**Files:**
- Verify: all changed Dart files and tests.

- [ ] **Step 1: Format**

Run:

```sh
dart format lib/presentation/pages/home_page.dart lib/presentation/mock/mock_follow_feed.dart test/widget_test.dart
```

Expected: files formatted.

- [ ] **Step 2: Static analysis**

Run:

```sh
flutter analyze lib/presentation/pages/home_page.dart lib/presentation/mock/mock_follow_feed.dart test/widget_test.dart
```

Expected: no new errors.

- [ ] **Step 3: Focused tests**

Run:

```sh
flutter test test/channel_inbox_data_test.dart
flutter test test/widget_test.dart --plain-name 'explore'
flutter test test/widget_test.dart --plain-name channel
```

Expected: all pass.

- [ ] **Step 4: Simulator build**

Run:

```sh
flutter build ios --simulator --debug
```

Expected: build succeeds.

## Self-Review

- Spec coverage: bottom tab rename, Xiaohongshu-style top tabs, follow avatar filter, channel text tag filter, swipe switching, and preserved channel navigation are covered.
- Placeholder scan: no `TBD` or undefined task.
- Type consistency: all new production types are scoped to `MockFollowFeed` and `_ExplorePage`; existing channel types remain unchanged.
