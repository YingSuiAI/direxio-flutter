import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/matrix_push_registration.dart';
import 'auth_provider.dart';

const _fcmTokenAttemptTimeout = Duration(seconds: 15);
const _fcmTokenRetryDelays = [
  Duration(seconds: 5),
  Duration(seconds: 20),
];

final pushNotificationBootstrapProvider = Provider<void>((ref) {
  if (!androidFcmMatrixPushSupported) {
    debugPrint('[push-registration] bootstrap skip: not Android runtime');
    return;
  }
  if (!matrixPushGatewayConfigured) {
    debugPrint('[push-registration] bootstrap skip: invalid gateway URL');
    return;
  }
  final client = ref.watch(matrixClientProvider);
  final messaging = FirebaseMessaging.instance;
  var registrationInFlight = false;

  bool isLoggedInNow() {
    return ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn == true;
  }

  Future<void> registerToken(String token) {
    if (!isLoggedInNow()) {
      debugPrint(
        '[push-registration] skip: auth is not logged in before pusher '
        'registration',
      );
      return Future<void>.value();
    }
    return registerAndroidFcmMatrixPusher(
      client: client,
      fcmToken: token,
    );
  }

  Future<void> registerCurrentForAuth(AuthState? auth, String reason) async {
    if (auth?.isLoggedIn != true) {
      debugPrint(
        '[push-registration] bootstrap waiting: user is not logged in '
        'reason=$reason',
      );
      return;
    }
    if (registrationInFlight) {
      debugPrint(
        '[push-registration] bootstrap skip: registration already in flight '
        'reason=$reason',
      );
      return;
    }
    registrationInFlight = true;
    try {
      debugPrint('[push-registration] bootstrap start reason=$reason');
      await _registerCurrentToken(messaging, registerToken);
    } finally {
      registrationInFlight = false;
    }
  }

  ref.listen<AsyncValue<AuthState>>(authStateNotifierProvider,
      (previous, next) {
    final wasLoggedIn = previous?.valueOrNull?.isLoggedIn == true;
    final isLoggedIn = next.valueOrNull?.isLoggedIn == true;
    if (!wasLoggedIn && isLoggedIn) {
      unawaited(
        registerCurrentForAuth(next.valueOrNull, 'auth-logged-in'),
      );
    }
  });

  unawaited(
    registerCurrentForAuth(
      ref.read(authStateNotifierProvider).valueOrNull,
      'initial',
    ),
  );
  unawaited(_syncAfterNotificationOpen(messaging, client.oneShotSync));
  final tokenRefresh = messaging.onTokenRefresh.listen((token) {
    unawaited(registerToken(token).catchError((Object error) {
      debugPrint(
        '[push-registration] FCM token refresh pusher registration failed: '
        '$error',
      );
    }));
  });
  final foreground = FirebaseMessaging.onMessage.listen((message) {
    debugPrint(
      '[push-notification] foreground FCM data=${message.data} '
      'has_notification=${message.notification != null}',
    );
  });
  final opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
    unawaited(client.oneShotSync().catchError((Object error) {
      debugPrint('Matrix one-shot sync after notification open failed: $error');
    }));
  });
  ref.onDispose(() {
    unawaited(tokenRefresh.cancel());
    unawaited(foreground.cancel());
    unawaited(opened.cancel());
  });
});

Future<void> _registerCurrentToken(
  FirebaseMessaging messaging,
  Future<void> Function(String token) registerToken,
) async {
  try {
    final settings = await messaging.requestPermission();
    debugPrint(
      '[push-registration] notification permission '
      'status=${settings.authorizationStatus.name}',
    );
    for (var attempt = 0; attempt <= _fcmTokenRetryDelays.length; attempt++) {
      try {
        final token = await messaging.getToken().timeout(
              _fcmTokenAttemptTimeout,
            );
        if (token == null || token.trim().isEmpty) {
          debugPrint(
            '[push-registration] Firebase returned an empty FCM token '
            'attempt=${attempt + 1}',
          );
        } else {
          await registerToken(token);
          return;
        }
      } catch (error) {
        debugPrint(
          '[push-registration] Firebase token fetch failed '
          'attempt=${attempt + 1}: $error',
        );
      }
      if (attempt < _fcmTokenRetryDelays.length) {
        await Future<void>.delayed(_fcmTokenRetryDelays[attempt]);
      }
    }
  } catch (error) {
    debugPrint('FCM pusher registration failed: $error');
  }
}

Future<void> _syncAfterNotificationOpen(
  FirebaseMessaging messaging,
  Future<void> Function() sync,
) async {
  try {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage == null) return;
    await sync();
  } catch (error) {
    debugPrint(
        'Matrix one-shot sync after initial notification failed: $error');
  }
}
