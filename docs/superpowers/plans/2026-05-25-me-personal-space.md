# Me Personal Space Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Me tab from a settings list into a personal space while moving account, notification, general, and logout controls into the gear settings page.

**Architecture:** Keep the redesign frontend-only for this phase. Matrix profile data continues to provide avatar, display name, user id, and domain; a small personal-space model/provider supplies signature, channels, and works with mock/empty data that can later be replaced by AS endpoints.

**Tech Stack:** Flutter, Riverpod, GoRouter, Matrix Dart SDK, existing M3 widgets and design tokens.

---

### Task 1: Widget Tests For Information Architecture

**Files:**
- Modify: `test/widget_test.dart`

- [x] **Step 1: Replace old Me page expectations**

Update the Me page tests so the Me tab must show personal-space content (`个性签名`, `我的频道`, `作品墙`) and must not show `账号与安全`, `通知设置`, `通用`, or `退出登录` in the main tab body.

- [x] **Step 2: Add settings gear test**

Add a test that taps the Me tab gear and verifies the settings page contains `账号与安全`, `通知设置`, `通用`, and `退出登录`.

- [x] **Step 3: Add icon color regression**

Add a test that verifies the gear settings page section icons keep the neutral `PortalTokens.light.textMute` style.

### Task 2: Personal Space Data Model

**Files:**
- Create: `lib/presentation/providers/personal_space_provider.dart`

- [x] **Step 1: Define personal-space models**

Create immutable models for `PersonalSpaceData`, `MyChannel`, and `WorkItem`.

- [x] **Step 2: Add provider**

Expose a `FutureProvider<PersonalSpaceData>` with mock defaults for signature, channels, and works.

### Task 3: Me Tab Redesign

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`

- [x] **Step 1: Add gear action back to Me header**

Make the existing HomePage header show a settings gear only on the Me tab and route it to `/settings`.

- [x] **Step 2: Replace settings list with personal-space sections**

Keep avatar upload, display name, domain/Node ID, then add signature, my channels, and works wall sections.

- [x] **Step 3: Preserve empty states**

If no channels or works exist, show polished empty states instead of hidden sections.

### Task 4: Unified Settings Page

**Files:**
- Modify: `lib/presentation/pages/settings_page.dart`

- [x] **Step 1: Expand settings page**

Merge account/security, notification, general, and logout controls into one settings page.

- [x] **Step 2: Preserve existing style**

Use the same neutral icon foreground/background style as the current Me page rows and existing subpages.

- [x] **Step 3: Keep existing routes valid**

Do not remove `/me/account`, `/me/notifications`, or `/me/account/password`; the unified page links to existing deeper pages where useful.

### Task 5: Verification

**Files:**
- Test: `test/widget_test.dart`

- [x] **Step 1: Run targeted widget tests**

Run `flutter test test/widget_test.dart`.

- [x] **Step 2: Run targeted analyze**

Run `flutter analyze lib/presentation/pages/home_page.dart lib/presentation/pages/settings_page.dart lib/presentation/providers/personal_space_provider.dart test/widget_test.dart`.

- [x] **Step 3: Run full Flutter test suite**

Run `flutter test`.
