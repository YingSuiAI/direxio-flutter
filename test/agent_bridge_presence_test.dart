import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/agent_bridge_presence_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('uses bootstrap agent_presence as initial header status', () {
    final container = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(
            bootstrap: _bootstrap(
              const AsAgentPresence(
                online: true,
                connected: true,
                configured: true,
                enabled: true,
                displayName: 'Agent',
                agentRoomId: '!agent:example.com',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.label, '在线');
    expect(presence.bridgeConnected, isTrue);
    expect(presence.presence?.agentRoomId, '!agent:example.com');
  });

  test('uses online for UI state and keeps connected as bridge fact', () {
    final container = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(
            bootstrap: _bootstrap(
              const AsAgentPresence(
                online: false,
                connected: true,
                configured: true,
                enabled: false,
                agentRoomId: '!agent:example.com',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.offline);
    expect(presence.label, '离线');
    expect(presence.bridgeConnected, isTrue);
  });

  test('distinguishes bootstrap loading from missing presence contract', () {
    final loadingContainer = ProviderContainer();
    addTearDown(loadingContainer.dispose);
    expect(
      loadingContainer.read(agentBridgePresenceProvider).state,
      AgentBridgePresenceState.connecting,
    );

    final missingContainer = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(bootstrap: _bootstrap(null)),
        ),
      ],
    );
    addTearDown(missingContainer.dispose);
    expect(
      missingContainer.read(agentBridgePresenceProvider).state,
      AgentBridgePresenceState.unknown,
    );
    expect(missingContainer.read(agentBridgePresenceProvider).label, '状态未知');
  });
}

AsSyncBootstrap _bootstrap(AsAgentPresence? presence) {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 6, 26),
    user: const AsSyncUser(userId: '@owner:example.com'),
    agentRoomId: presence?.agentRoomId ?? '',
    agentPresence: presence,
    rooms: const [],
    contacts: const [],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}
