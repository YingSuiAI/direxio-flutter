import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/agent_bridge_presence_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('uses bootstrap agent_online as initial header status', () {
    final container = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(
            bootstrap: _bootstrap(
              true,
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
  });

  test('uses online as the only UI state bit', () {
    final container = ProviderContainer(
      overrides: [
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(
            bootstrap: _bootstrap(
              false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final presence = container.read(agentBridgePresenceProvider);

    expect(presence.state, AgentBridgePresenceState.offline);
    expect(presence.label, '离线');
    expect(presence.bridgeConnected, isFalse);
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

AsSyncBootstrap _bootstrap(bool? agentOnline) {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 6, 26),
    user: const AsSyncUser(userId: '@owner:example.com'),
    agentRoomId: '!agent:example.com',
    agentOnline: agentOnline,
    rooms: const [],
    contacts: const [],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}
