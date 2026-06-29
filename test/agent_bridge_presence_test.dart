import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/agent_bridge_presence_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

void main() {
  test('tracks Agent status state from the initial limited Matrix timeline',
      () async {
    const agentRoomId = '!agent-room:example.com';
    final container = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(bootstrap: _bootstrap()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      matrixClientProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(keepAlive.close);
    final client = container.read(matrixClientProvider)
      ..setUserId('@owner:example.com');

    await client.handleSync(
      SyncUpdate.fromJson({
        'next_batch': 's1',
        'rooms': {
          'join': {
            agentRoomId: {
              'state': {'events': <Object?>[]},
              'timeline': {
                'limited': true,
                'prev_batch': 't1',
                'events': [
                  {
                    'type': direxioAgentStatusEventType,
                    'state_key': '@agent:example.com',
                    'sender': '@agent:example.com',
                    'event_id': r'$agent-status',
                    'origin_server_ts': 1,
                    'content': {'online': true},
                  },
                ],
              },
            },
          },
        },
      }),
    );

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.bridgeConnected, isTrue);
  });

  test('uses Matrix agent room state as header status', () {
    final client = _matrixClientWithAgentRoom(online: true);
    final container = _containerFor(client);
    addTearDown(container.dispose);

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.label, '在线');
    expect(presence.bridgeConnected, isTrue);
    expect(presence.source, 'matrix.room_state.io.direxio.agent.status');
  });

  test('falls back to Matrix state API when local agent state is missing',
      () async {
    final requestedPaths = <String>[];
    final client = Client(
      'AgentBridgePresenceStateFallbackTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path ==
            '/_matrix/client/v3/rooms/!agent-room%3Aexample.com/state/io.direxio.agent.status/%40agent%3Aexample.com') {
          return http.Response('{"online":true}', 200);
        }
        return http.Response('{}', 404);
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'access-token'
      ..setUserId('@owner:example.com');
    client.rooms.add(Room(id: '!agent-room:example.com', client: client));
    final container = _containerFor(client);
    addTearDown(container.dispose);

    final seenStates = <String>[];
    final onlinePresence = Completer<AgentBridgePresence>();
    final subscription = container.listen<AgentBridgePresence>(
      agentBridgePresenceProvider,
      (_, next) {
        seenStates.add('${next.state}:${next.source}');
        if (next.state == AgentBridgePresenceState.online &&
            !onlinePresence.isCompleted) {
          onlinePresence.complete(next);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final presence = await onlinePresence.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => throw TestFailure(
        'Agent status fallback did not become online. '
        'seen=$seenStates paths=$requestedPaths',
      ),
    );

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.bridgeConnected, isTrue);
    expect(presence.source, 'matrix.room_state.io.direxio.agent.status.fetch');
    expect(requestedPaths, [
      '/_matrix/client/v3/rooms/!agent-room%3Aexample.com/state/io.direxio.agent.status/%40agent%3Aexample.com',
    ]);
  });

  test('retries Matrix state API after transient lookup failure', () async {
    var calls = 0;
    final client = Client(
      'AgentBridgePresenceStateRetryTest',
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) {
          throw http.ClientException('Failed host lookup', request.url);
        }
        if (request.url.path ==
            '/_matrix/client/v3/rooms/!agent-room%3Aexample.com/state/io.direxio.agent.status/%40agent%3Aexample.com') {
          return http.Response('{"online":true}', 200);
        }
        return http.Response('{}', 404);
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'access-token'
      ..setUserId('@owner:example.com');
    client.rooms.add(Room(id: '!agent-room:example.com', client: client));
    final container = _containerFor(
      client,
      overrides: [
        agentBridgePresenceStateRefreshIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    final seenStates = <String>[];
    final onlinePresence = Completer<AgentBridgePresence>();
    final subscription = container.listen<AgentBridgePresence>(
      agentBridgePresenceProvider,
      (_, next) {
        seenStates.add('${next.state}:${next.source}');
        if (next.state == AgentBridgePresenceState.online &&
            !onlinePresence.isCompleted) {
          onlinePresence.complete(next);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final presence = await onlinePresence.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => throw TestFailure(
        'Agent status fallback did not recover. '
        'seen=$seenStates calls=$calls',
      ),
    );

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.bridgeConnected, isTrue);
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('keeps fetched Matrix state stable during background retry ticks',
      () async {
    final client = Client(
      'AgentBridgePresenceNoFlickerTest',
      httpClient: MockClient((request) async {
        if (request.url.path ==
            '/_matrix/client/v3/rooms/!agent-room%3Aexample.com/state/io.direxio.agent.status/%40agent%3Aexample.com') {
          return http.Response('{"online":true}', 200);
        }
        return http.Response('{}', 404);
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'access-token'
      ..setUserId('@owner:example.com');
    client.rooms.add(Room(id: '!agent-room:example.com', client: client));
    final container = _containerFor(
      client,
      overrides: [
        agentBridgePresenceStateRefreshIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    var firstOnlineSeen = false;
    final statesAfterOnline = <AgentBridgePresenceState>[];
    final onlinePresence = Completer<void>();
    final subscription = container.listen<AgentBridgePresence>(
      agentBridgePresenceProvider,
      (_, next) {
        if (firstOnlineSeen) {
          statesAfterOnline.add(next.state);
        }
        if (next.state == AgentBridgePresenceState.online && !firstOnlineSeen) {
          firstOnlineSeen = true;
          onlinePresence.complete();
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await onlinePresence.future.timeout(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      statesAfterOnline,
      everyElement(AgentBridgePresenceState.online),
    );
  });

  test('uses online as the only UI state bit', () {
    final client = _matrixClientWithAgentRoom(online: false);
    final container = _containerFor(client);
    addTearDown(container.dispose);

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.offline);
    expect(presence.label, '离线');
    expect(presence.bridgeConnected, isFalse);
  });

  test('distinguishes bootstrap loading from missing Matrix state', () {
    final loadingContainer = ProviderContainer();
    addTearDown(loadingContainer.dispose);
    expect(
      loadingContainer.read(agentBridgePresenceProvider).state,
      AgentBridgePresenceState.connecting,
    );

    final client = _matrixClientWithAgentRoom();
    final missingContainer = _containerFor(client);
    addTearDown(missingContainer.dispose);

    final missingPresence = missingContainer.read(agentBridgePresenceProvider);
    expect(missingPresence.state, AgentBridgePresenceState.unknown);
    expect(missingPresence.label, '离线');
    expect(missingPresence.bridgeConnected, isFalse);
  });
}

ProviderContainer _containerFor(
  Client client, {
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      matrixClientProvider.overrideWithValue(client),
      asSyncCacheProvider.overrideWith(
        (ref) => AsSyncCacheState(bootstrap: _bootstrap()),
      ),
      ...overrides,
    ],
  );
}

Client _matrixClientWithAgentRoom({bool? online}) {
  final client = Client('AgentBridgePresenceTest')
    ..setUserId('@owner:example.com');
  final room = Room(id: '!agent-room:example.com', client: client);
  if (online != null) {
    room.setState(
      StrippedStateEvent(
        type: direxioAgentStatusEventType,
        senderId: '@owner:example.com',
        stateKey: '@agent:example.com',
        content: {'online': online},
      ),
    );
  }
  client.rooms.add(room);
  return client;
}

AsSyncBootstrap _bootstrap() {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 6, 26),
    user: const AsSyncUser(userId: '@owner:example.com'),
    agentRoomId: '!agent-room:example.com',
    rooms: const [],
    contacts: const [],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}
