---
name: p2p-client-release-build
description: Release build and artifact packaging workflow for the Flutter P2P client. Use when the user asks to rebuild APKs, package Android/iOS/web artifacts, verify platform builds, copy outputs to dist, or handle build-generated drift without source changes.
---

# P2P Client Release Build

## Scope First

Treat requests like "rebuild APK" as narrow artifact rebuild requests unless the user also asks for code changes.

Check the branch, HEAD, and worktree before building:

```powershell
git status --short --branch
git rev-parse --short HEAD
```

Do not stage unrelated code changes or generated drift caused by the build.

## Android Release APK

Build:

```powershell
flutter build apk --release --no-tree-shake-icons
```

Expected output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Copy the artifact to `dist/` with a name that includes the current short commit SHA, for example:

```powershell
$sha = git rev-parse --short HEAD
New-Item -ItemType Directory -Force dist | Out-Null
Copy-Item build/app/outputs/flutter-apk/app-release.apk "dist/p2p-client-$sha-release.apk" -Force
Get-FileHash "dist/p2p-client-$sha-release.apk" -Algorithm SHA256
```

Record size and SHA256 in the final answer.

## Generated Drift

Flutter builds may surface spurious generated localization drift such as `lib/l10n/app_localizations.dart`. If a generated file changed only because of build drift and the user requested a rebuild-only task, restore that file before finishing.

Never restore source changes that pre-existed the task or belong to the user.

## Other Platform Builds

For iOS simulator build verification:

```powershell
flutter build ios --simulator
```

For web release verification:

```powershell
flutter build web --release
```

Use the platform build that matches the requested artifact or touched platform files.

## Verification

For rebuild-only tasks, the successful platform build is the primary verification.

For platform/build configuration changes, also run:

```powershell
flutter analyze --no-pub
flutter test --no-pub <relevant tests>
```
