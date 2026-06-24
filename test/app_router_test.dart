import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/router/app_router.dart';

void main() {
  test('chat routes do not use whole-page slide transitions', () {
    expect(
      routeTransitionForLocation('/chat/abc'),
      PortalRouteTransition.chatEntranceOnly,
    );
    expect(
      routeTransitionForLocation('/group/abc'),
      PortalRouteTransition.chatEntranceOnly,
    );
    expect(routeTransitionForLocation('/chat-info/abc'),
        PortalRouteTransition.slide);
    expect(
      routeTransitionForLocation('/group-detail/abc'),
      PortalRouteTransition.slide,
    );
  });

  test('initial route can be injected only for call autotest builds', () {
    expect(
      initialAppLocation(
        callAutotestEnabled: true,
        environment: const {
          'P2P_INITIAL_ROUTE': '/group-call/!room%3Ap2p.test',
        },
        arguments: const [],
      ),
      '/restore?next=%2Fgroup-call%2F!room%253Ap2p.test',
    );
    expect(
      initialAppLocation(
        callAutotestEnabled: false,
        environment: const {
          'P2P_INITIAL_ROUTE': '/group-call/!room%3Ap2p.test',
        },
        arguments: const [],
      ),
      '/restore',
    );
    expect(
      initialAppLocation(
        callAutotestEnabled: true,
        environment: const {'P2P_INITIAL_ROUTE': 'portalapp:///bad'},
        arguments: const [],
      ),
      '/restore',
    );
  });

  test('initial call autotest route can be injected by launch argument', () {
    expect(
      initialAppLocation(
        callAutotestEnabled: true,
        environment: const {},
        arguments: const ['--p2p-initial-route=/group-call/!room%3Ap2p.test'],
        routeFileContent: null,
      ),
      '/restore?next=%2Fgroup-call%2F!room%253Ap2p.test',
    );
  });

  test('initial call autotest route can be injected by consumed route file',
      () {
    expect(
      initialAppLocation(
        callAutotestEnabled: true,
        environment: const {},
        arguments: const [],
        routeFileContent: '/group-call/!room%3Ap2p.test\n',
      ),
      '/restore?next=%2Fgroup-call%2F!room%253Ap2p.test',
    );
  });

  test('consumed call autotest route survives router rebuilds', () {
    final remembered = rememberCallAutotestInitialRoute(
      previousRoute: null,
      consumedRoute: ' /group-call/!room%3Ap2p.test ',
    );
    expect(remembered, '/group-call/!room%3Ap2p.test');
    expect(
      rememberCallAutotestInitialRoute(
        previousRoute: remembered,
        consumedRoute: null,
      ),
      '/group-call/!room%3Ap2p.test',
    );
  });

  test('call autotest restore redirects to injected route after auth loads',
      () {
    expect(
      authRedirectLocation(
        callAutotestEnabled: true,
        isAuthLoading: false,
        isLoggedIn: true,
        requiresInitialization: false,
        matchedLocation: '/restore',
        uri: Uri.parse(
          '/restore?next=%2Fgroup-call%2F%21room%253Ap2p.test',
        ),
      ),
      '/group-call/!room%3Ap2p.test',
    );
    expect(
      authRedirectLocation(
        callAutotestEnabled: true,
        isAuthLoading: false,
        isLoggedIn: true,
        requiresInitialization: false,
        matchedLocation: '/restore',
        uri: Uri.parse('/restore?next=%2Fhome'),
      ),
      '/home',
    );
  });

  test('auth redirect uses restore page while stored session is loading', () {
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: true,
        isLoggedIn: false,
        requiresInitialization: false,
        matchedLocation: '/login',
        uri: Uri.parse('/login'),
      ),
      '/restore',
    );
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: true,
        isLoggedIn: false,
        requiresInitialization: false,
        matchedLocation: '/restore',
        uri: Uri.parse('/restore'),
      ),
      isNull,
    );
  });

  test('auth redirect sends restore page to final destination after loading',
      () {
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: false,
        isLoggedIn: true,
        requiresInitialization: false,
        matchedLocation: '/restore',
        uri: Uri.parse('/restore'),
      ),
      '/home',
    );
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: false,
        isLoggedIn: false,
        requiresInitialization: false,
        matchedLocation: '/restore',
        uri: Uri.parse('/restore'),
      ),
      '/login',
    );
  });

  test('auth redirect sends logged-in uninitialized account to init', () {
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: false,
        isLoggedIn: true,
        requiresInitialization: true,
        matchedLocation: '/login',
        uri: Uri.parse('/login'),
      ),
      '/init',
    );
    expect(
      authRedirectLocation(
        callAutotestEnabled: false,
        isAuthLoading: false,
        isLoggedIn: true,
        requiresInitialization: true,
        matchedLocation: '/init',
        uri: Uri.parse('/init'),
      ),
      isNull,
    );
  });
}
