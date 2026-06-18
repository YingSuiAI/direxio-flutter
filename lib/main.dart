import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/app_locale_provider.dart';
import 'presentation/providers/app_theme_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/message_sound_provider.dart';
import 'presentation/providers/p2p_api_provider.dart';
import 'presentation/widgets/app_glass_background.dart';

bool _sessionExpiredDialogShowing = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class PortalApp extends ConsumerWidget {
  const PortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeState = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    ref.watch(messageSoundControllerProvider);
    ref.listen<int>(sessionExpiredNoticeProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || _sessionExpiredDialogShowing) return;
        _sessionExpiredDialogShowing = true;
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: const Text('登录已过期'),
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
        return _StartupSplashOverlay(
          child: AppGlassBackground(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

class _StartupSplashOverlay extends StatefulWidget {
  const _StartupSplashOverlay({required this.child});

  final Widget child;

  @override
  State<_StartupSplashOverlay> createState() => _StartupSplashOverlayState();
}

class _StartupSplashOverlayState extends State<_StartupSplashOverlay> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Image.asset(
              'assets/images/splash_launch.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
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
