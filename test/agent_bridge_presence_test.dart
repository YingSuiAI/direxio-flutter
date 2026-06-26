import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/agent_bridge_presence_provider.dart';

void main() {
  test('parses server online separately from connected event-stream presence',
      () {
    final status = AgentStatus.fromJson(const {
      'connected': true,
      'online': false,
      'enabled': false,
      'configured': true,
      'display_name': 'Agent',
      'agent_room_id': '!agent:example.com',
    });

    expect(status.connected, isTrue);
    expect(status.online, isFalse);
    expect(status.enabled, isFalse);
  });

  test('maps active agent-token stream to online bridge presence', () {
    const status = AgentStatus(
      connected: true,
      online: true,
      configured: true,
      displayName: 'Agent',
      agentRoomId: '!agent:example.com',
      lastSeen: null,
      roomsJoined: 0,
      messagesToday: 0,
    );

    final presence = agentBridgePresenceFromStatus(status);

    expect(presence.state, AgentBridgePresenceState.online);
    expect(presence.bridgeConnected, isTrue);
    expect(presence.label, '在线');
  });

  test('maps missing active agent-token stream to offline bridge presence', () {
    const status = AgentStatus(
      connected: false,
      online: false,
      configured: true,
      displayName: 'Agent',
      agentRoomId: '!agent:example.com',
      lastSeen: null,
      roomsJoined: 0,
      messagesToday: 0,
    );

    final presence = agentBridgePresenceFromStatus(status);

    expect(presence.state, AgentBridgePresenceState.offline);
    expect(presence.bridgeConnected, isFalse);
    expect(presence.label, '离线');
  });

  test('keeps disabled connected bridge offline in the UI', () {
    const status = AgentStatus(
      connected: true,
      online: false,
      configured: true,
      displayName: 'Agent',
      agentRoomId: '!agent:example.com',
      lastSeen: null,
      roomsJoined: 0,
      messagesToday: 0,
    );

    final presence = agentBridgePresenceFromStatus(status);

    expect(presence.state, AgentBridgePresenceState.offline);
    expect(presence.bridgeConnected, isTrue);
    expect(presence.label, '离线');
  });

  test('keeps unconfigured agent status distinct from offline', () {
    const status = AgentStatus(
      connected: false,
      online: false,
      configured: false,
      displayName: '',
      agentRoomId: '',
      lastSeen: null,
      roomsJoined: 0,
      messagesToday: 0,
    );

    final presence = agentBridgePresenceFromStatus(status);

    expect(presence.state, AgentBridgePresenceState.unknown);
    expect(presence.label, '未知');
  });

  test('maps polling errors to explicit error state', () {
    final presence = agentBridgePresenceFromError(StateError('boom'));

    expect(presence.state, AgentBridgePresenceState.error);
    expect(presence.label, '状态异常');
  });
}
