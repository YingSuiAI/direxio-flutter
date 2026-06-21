import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/app_locale_provider.dart';
import 'presentation/providers/app_theme_provider.dart';
import 'presentation/providers/as_event_stream_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/bi_analytics_provider.dart';
import 'presentation/providers/message_sound_provider.dart';
import 'presentation/providers/push_notification_provider.dart';
import 'presentation/widgets/app_glass_background.dart';
import 'presentation/widgets/user_action_debounce.dart';

const _appFontAsset = 'assets/fonts/NotoSansSC-Variable.ttf';

bool _sessionExpiredDialogShowing = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_androidFcmSupported) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await _warmAppFonts();
  // Web 上禁用浏览器原生右键菜单（翻译/检查等），让我们自己的
  // chat-ctx / msg-ctx 菜单不被遮挡。
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  final container = ProviderContainer();
  unawaited(
    container
        .read(biAnalyticsServiceProvider)
        .reportInstallAndLaunch()
        .catchError((Object _) {}),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PortalApp(),
    ),
  );
}

bool get _androidFcmSupported {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_androidFcmSupported) {
    await Firebase.initializeApp();
  }
}

Future<void> _warmAppFonts() async {
  final loader = FontLoader(AppTheme.fontFamily)
    ..addFont(rootBundle.load(_appFontAsset));
  await loader.load();
}

class PortalApp extends ConsumerWidget {
  const PortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeState = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    ref.watch(asEventStreamRefreshProvider);
    ref.watch(messageSoundControllerProvider);
    ref.watch(pushNotificationBootstrapProvider);
    ref.listen<int>(sessionExpiredNoticeProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || _sessionExpiredDialogShowing) return;
        _sessionExpiredDialogShowing = true;
        router.go('/login');
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: const Text('账号在其他设备登录'),
              content: const Text('请重新登录'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        ).whenComplete(
          () => _sessionExpiredDialogShowing = false,
        );
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      });
    });
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode.materialThemeMode,
      locale: localeState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: _resolveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        return UserActionDebounce(
          child: AppGlassBackground(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

Locale _resolveLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final supported in supportedLocales) {
      if (preferred.languageCode == supported.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('en');
}
