import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/app_locale_provider.dart';
import 'presentation/providers/app_theme_provider.dart';
import 'presentation/providers/as_event_stream_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/bi_analytics_provider.dart';
import 'presentation/providers/message_sound_provider.dart';
import 'presentation/providers/push_notification_provider.dart';
import 'presentation/call/active_call_mini_window.dart';
import 'presentation/widgets/app_glass_background.dart';

bool _sessionExpiredDialogShowing = false;
bool _startupSplashFirstFrameDeferred = false;
bool _startupSplashFirstFrameAllowed = false;

const _startupSplashAssetPath = 'assets/images/splash_launch.png';
const _startupSplashHoldDuration = Duration(milliseconds: 1300);
const _startupSplashFadeDuration = Duration(milliseconds: 220);

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  _deferStartupSplashFirstFrame(binding);
  _configureAndroidPhotoPicker();
  await _initializeFirebaseMessaging();
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

void _deferStartupSplashFirstFrame(WidgetsBinding binding) {
  binding.deferFirstFrame();
  _startupSplashFirstFrameDeferred = true;
  _startupSplashFirstFrameAllowed = false;
}

void _allowStartupSplashFirstFrame() {
  if (!_startupSplashFirstFrameDeferred || _startupSplashFirstFrameAllowed) {
    return;
  }
  WidgetsBinding.instance.allowFirstFrame();
  _startupSplashFirstFrameAllowed = true;
}

void _configureAndroidPhotoPicker() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }
}

bool get _firebaseMessagingSupported {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

Future<void> _initializeFirebaseMessaging() async {
  if (!_firebaseMessagingSupported) return;
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 4));
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'p2p-client startup',
        context: ErrorDescription('initializing Firebase Messaging'),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_firebaseMessagingSupported) {
    await Firebase.initializeApp();
  }
  debugPrint(
    '[push-notification] background data=${message.data} '
    'has_notification=${message.notification != null}',
  );
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
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final l10n = AppLocalizations.of(dialogContext);
            return CupertinoAlertDialog(
              title: Text(l10n.sessionExpiredTitle),
              content: Text(l10n.sessionExpiredMessage),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    router.go('/login');
                  },
                  child: Text(l10n.commonOk),
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
        return StartupSplashOverlay(
          child: ActiveCallMiniWindowOverlay(
            onRestoreRoute: router.push,
            child: AppGlassBackground(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

class StartupSplashOverlay extends StatefulWidget {
  const StartupSplashOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<StartupSplashOverlay> createState() => _StartupSplashOverlayState();
}

class _StartupSplashOverlayState extends State<StartupSplashOverlay> {
  bool _visible = true;
  bool _precacheStarted = false;
  Timer? _hideTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted) return;
    _precacheStarted = true;
    _prepareSplashImage();
  }

  Future<void> _prepareSplashImage() async {
    try {
      await precacheImage(
        const AssetImage(_startupSplashAssetPath),
        context,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'p2p-client startup',
          context: ErrorDescription('precaching startup splash image'),
        ),
      );
    } finally {
      _allowStartupSplashFirstFrame();
      if (mounted) _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer ??= Timer(_startupSplashHoldDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _allowStartupSplashFirstFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashBackground = Theme.of(context).extension<PortalTokens>()?.bg ??
        PortalTokens.light.bg;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _startupSplashFadeDuration,
            curve: Curves.easeOut,
            child: ColoredBox(
              color: splashBackground,
              child: Image.asset(
                _startupSplashAssetPath,
                fit: BoxFit.cover,
              ),
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
