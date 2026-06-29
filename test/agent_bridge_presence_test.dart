import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

ProviderContainer _containerFor(Client client) {
  return ProviderContainer(
    overrides: [
      matrixClientProvider.overrideWithValue(client),
      asSyncCacheProvider.overrideWith(
        (ref) => AsSyncCacheState(bootstrap: _bootstrap()),
      ),
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
