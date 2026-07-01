import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../data/ios_apns_token.dart';
import '../../data/matrix_push_registration.dart';
import '../notifications/local_push_notification_service.dart';
import '../utils/direct_contact_status.dart';
import '../utils/push_notification_navigation.dart';
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';

const _pushTokenAttemptTimeout = Duration(seconds: 15);
const _pushTokenRetryDelays = [
  Duration(seconds: 5),
  Duration(seconds: 20),
];

final pushNotificationBootstrapProvider = Provider<void>((ref) {
  final profile = currentMatrixPusherProfile;
  if (profile == null) {
    debugPrint('[push-registration] bootstrap skip: unsupported runtime');
    return;
  }
  if (!matrixPushGatewayConfigured) {
    debugPrint('[push-registration] bootstrap skip: invalid gateway URL');
    return;
  }
  final usesFirebaseMessaging = profile == direxioAndroidFcmPusherProfile;
  if (usesFirebaseMessaging && Firebase.apps.isEmpty) {
    debugPrint('[push-registration] bootstrap skip: Firebase not initialized');
    return;
  }
  final client = ref.watch(matrixClientProvider);
  final router = ref.watch(appRouterProvider);
  final messaging = Firebase.apps.isEmpty ? null : FirebaseMessaging.instance;
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
    return registerMatrixPusher(
      client: client,
      profile: profile,
      pushToken: token,
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
      await _registerCurrentToken(
        messaging: messaging,
        profile: profile,
        registerToken: registerToken,
      );
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
  unawaited(
    () async {
      await LocalPushNotificationService.instance.initialize(
        onOpen: (data) async {
          await client.oneShotSync();
          await _openPushNotificationDataRoute(
            ref: ref,
            data: data,
            routerGo: router.go,
          );
        },
      );
      final launchData = await LocalPushNotificationService.instance
          .takeLaunchNotificationData();
      if (launchData != null) {
        await client.oneShotSync();
        await _openPushNotificationDataRoute(
          ref: ref,
          data: launchData,
          routerGo: router.go,
        );
      }
    }()
        .catchError((Object error) {
      debugPrint('[push-notification] local notification init failed: $error');
    }),
  );
  if (messaging == null) {
    return;
  }
  unawaited(
    _syncAfterInitialNotificationOpen(
      messaging: messaging,
      sync: client.oneShotSync,
      openNotification: (message) => _openPushNotificationRoute(
        ref: ref,
        message: message,
        routerGo: router.go,
      ),
    ),
  );
  final tokenRefresh = messaging.onTokenRefresh.listen((token) {
    final registration = profile == direxioAndroidFcmPusherProfile
        ? registerToken(token)
        : _registerCurrentToken(
            messaging: messaging,
            profile: profile,
            registerToken: registerToken,
          );
    unawaited(registration.catchError((Object error) {
      debugPrint(
        '[push-registration] token refresh pusher registration failed: '
        '$error',
      );
    }));
  });
  final foreground = FirebaseMessaging.onMessage.listen((message) {
    debugPrint(
      '[push-notification] foreground data=${message.data} '
      'has_notification=${message.notification != null}',
    );
    unawaited(
      LocalPushNotificationService.instance
          .showRemoteData(message.data)
          .catchError((Object error) {
        debugPrint('[push-notification] local foreground show failed: $error');
      }),
    );
  });
  final opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
    unawaited(() async {
      await client.oneShotSync();
      await _openPushNotificationRoute(
        ref: ref,
        message: message,
        routerGo: router.go,
      );
    }()
        .catchError((Object error) {
      debugPrint('Matrix notification open handling failed: $error');
    }));
  });
  ref.onDispose(() {
    unawaited(tokenRefresh.cancel());
    unawaited(foreground.cancel());
    unawaited(opened.cancel());
  });
});

Future<void> _registerCurrentToken({
  required FirebaseMessaging? messaging,
  required MatrixPusherProfile profile,
  required Future<void> Function(String token) registerToken,
}) async {
  try {
    if (messaging != null) {
      final settings = await messaging.requestPermission();
      debugPrint(
        '[push-registration] notification permission '
        'status=${settings.authorizationStatus.name}',
      );
    }
    for (var attempt = 0; attempt <= _pushTokenRetryDelays.length; attempt++) {
      try {
        final token = await resolveMatrixPushTokenForProfile(
          profile: profile,
          androidFcmToken: () => messaging?.getToken() ?? Future.value(),
          iosApnsToken: fetchDirexioIosApnsToken,
        ).timeout(_pushTokenAttemptTimeout);
        if (token == null || token.trim().isEmpty) {
          debugPrint(
            '[push-registration] push provider returned an empty '
            '${profile.provider} token '
            'attempt=${attempt + 1}',
          );
        } else {
          await registerToken(token);
          return;
        }
      } catch (error) {
        debugPrint(
          '[push-registration] Firebase token fetch failed '
          'provider=${profile.provider} '
          'attempt=${attempt + 1}: $error',
        );
      }
      if (attempt < _pushTokenRetryDelays.length) {
        await Future<void>.delayed(_pushTokenRetryDelays[attempt]);
      }
    }
  } catch (error) {
    debugPrint('Matrix pusher registration failed: $error');
  }
}

Future<String?> resolveMatrixPushTokenForProfile({
  required MatrixPusherProfile profile,
  required Future<String?> Function() androidFcmToken,
  required Future<String?> Function() iosApnsToken,
}) {
  if (profile == direxioIosApnsPusherProfile) {
    return iosApnsToken();
  }
  return androidFcmToken();
}

Future<void> _syncAfterInitialNotificationOpen({
  required FirebaseMessaging messaging,
  required Future<void> Function() sync,
  required Future<void> Function(RemoteMessage message) openNotification,
}) async {
  try {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage == null) return;
    await sync();
    await openNotification(initialMessage);
  } catch (error) {
    debugPrint(
      'Matrix notification open handling after initial notification failed: '
      '$error',
    );
  }
}

Future<void> _openPushNotificationRoute({
  required Ref ref,
  required RemoteMessage message,
  required void Function(String location) routerGo,
}) async {
  await _openPushNotificationDataRoute(
    ref: ref,
    data: message.data,
    routerGo: routerGo,
  );
}

Future<void> _openPushNotificationDataRoute({
  required Ref ref,
  required Map<String, dynamic> data,
  required void Function(String location) routerGo,
}) async {
  if (ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn != true) {
    debugPrint('[push-notification] open skip: user is not logged in');
    return;
  }
  final roomId = pushNotificationRoomIdFromData(data);
  if (roomId == null) {
    debugPrint('[push-notification] open skip: missing room_id data=$data');
    return;
  }

  final bootstrapContext = pushNotificationRouteContextFromBootstrap(
    ref.read(asSyncCacheProvider).bootstrap,
    roomId,
  );
  final nativeRoomType = pushNotificationRouteRoomTypeFromNativeProfile(
    ref
        .read(matrixClientProvider)
        .getRoomById(roomId)
        ?.getState(nativeRoomProfileEventType)
        ?.content,
  );
  final route = pushNotificationRouteForData(
    data,
    context: PushNotificationRouteContext(
      roomType: bootstrapContext.roomType ?? nativeRoomType,
      channelId: bootstrapContext.channelId,
      roomName: bootstrapContext.roomName,
    ),
  );
  if (route == null) {
    debugPrint('[push-notification] open skip: unsupported data=$data');
    return;
  }
  debugPrint('[push-notification] open route=$route room_id=$roomId');
  try {
    await LocalPushNotificationService.instance.clearRoom(roomId);
  } catch (error) {
    debugPrint('[push-notification] local room clear failed: $error');
  }
  routerGo(route);
}
