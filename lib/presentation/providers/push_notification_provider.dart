import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/matrix_push_registration.dart';
import 'auth_provider.dart';

final pushNotificationBootstrapProvider = Provider<void>((ref) {
  if (!androidFcmMatrixPushSupported || !matrixPushGatewayConfigured) return;
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  if (auth?.isLoggedIn != true) return;
  final client = ref.watch(matrixClientProvider);
  final messaging = FirebaseMessaging.instance;

  Future<void> registerToken(String token) {
    return registerAndroidFcmMatrixPusher(
      client: client,
      fcmToken: token,
    );
  }

  unawaited(_registerCurrentToken(messaging, registerToken));
  unawaited(_syncAfterNotificationOpen(messaging, client.oneShotSync));
  final tokenRefresh = messaging.onTokenRefresh.listen((token) {
    unawaited(registerToken(token).catchError((Object error) {
      debugPrint('FCM token refresh pusher registration failed: $error');
    }));
  });
  final opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
    unawaited(client.oneShotSync().catchError((Object error) {
      debugPrint('Matrix one-shot sync after notification open failed: $error');
    }));
  });
  ref.onDispose(() {
    unawaited(tokenRefresh.cancel());
    unawaited(opened.cancel());
  });
});

Future<void> _registerCurrentToken(
  FirebaseMessaging messaging,
  Future<void> Function(String token) registerToken,
) async {
  try {
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await registerToken(token);
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
