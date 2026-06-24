import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/message_sound_provider.dart';

void main() {
  test('plays only for incoming room messages', () {
    expect(
      shouldPlayMessageSound(
        _messageUpdate(sender: '@alice:p2p-im.com'),
        currentUserId: '@owner:p2p-im.com',
      ),
      isTrue,
    );
    expect(
      shouldPlayMessageSound(
        _messageUpdate(sender: '@owner:p2p-im.com'),
        currentUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
    expect(
      shouldPlayMessageSound(
        _messageUpdate(
          sender: '@alice:p2p-im.com',
          updateType: EventUpdateType.history,
        ),
        currentUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
    expect(
      shouldPlayMessageSound(
        EventUpdate(
          roomID: '!room:p2p-im.com',
          type: EventUpdateType.timeline,
          content: {
            'type': EventTypes.Reaction,
            'sender': '@alice:p2p-im.com',
            'content': const {},
          },
        ),
        currentUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
  });

  test('does not play for muted conversations', () {
    expect(
      shouldPlayMessageSound(
        _messageUpdate(sender: '@alice:p2p-im.com'),
        currentUserId: '@owner:p2p-im.com',
        mutedConversationIds: {'!room:p2p-im.com'},
      ),
      isFalse,
    );
    expect(
      shouldPlayMessageSound(
        _messageUpdate(sender: '@alice:p2p-im.com'),
        currentUserId: '@owner:p2p-im.com',
        mutedConversationIds: {'!other:p2p-im.com'},
      ),
      isTrue,
    );
  });

  test('does not play for channel rooms by default', () {
    expect(
      shouldPlayMessageSound(
        _messageUpdate(
          roomId: '!channel:p2p-im.com',
          sender: '@alice:p2p-im.com',
        ),
        currentUserId: '@owner:p2p-im.com',
        mutedChannelRoomIds: {'!channel:p2p-im.com'},
      ),
      isFalse,
    );
    expect(
      shouldPlayMessageSound(
        _messageUpdate(
          roomId: '!direct:p2p-im.com',
          sender: '@alice:p2p-im.com',
        ),
        currentUserId: '@owner:p2p-im.com',
        mutedChannelRoomIds: {'!channel:p2p-im.com'},
      ),
      isTrue,
    );
  });

  test('reads default-muted channel rooms from bootstrap', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_updates',
          roomId: '!channel:p2p-im.com',
          name: '频道',
          avatarUrl: '',
          memberCount: 2,
          unreadCount: 3,
          lastActivityAt: null,
          memberStatus: 'join',
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    expect(channelRoomIdsFromBootstrap(bootstrap), {'!channel:p2p-im.com'});
  });

  test('reads default-muted channel rooms from Matrix room profile', () {
    final client = Client('MessageSoundChannelRoomProfileTest');
    final channelRoom = Room(
      id: '!channel:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    final directRoom = Room(
      id: '!direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.addAll([channelRoom, directRoom]);
    channelRoom.setState(
      StrippedStateEvent(
        type: 'io.direxio.room.profile',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'room_type': 'io.direxio.room.channel'},
      ),
    );

    expect(
        channelRoomIdsFromMatrixRooms(client.rooms), {'!channel:p2p-im.com'});
  });

  test('reads default-muted channel rooms from legacy Matrix kind', () {
    final client = Client('MessageSoundLegacyChannelKindTest');
    final channelRoom = Room(
      id: '!legacy-channel:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(channelRoom);
    channelRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'kind': 'channel'},
      ),
    );

    expect(
      channelRoomIdsFromMatrixRooms(client.rooms),
      {'!legacy-channel:p2p-im.com'},
    );
  });

  test('message vibration uses mobile-compatible pattern', () async {
    final patterns = <List<int>>[];
    final player = MessageVibrationPlayer(
      hasVibrator: () async => true,
      vibrateDevice: ({List<int> pattern = const []}) async {
        patterns.add(pattern);
      },
      hapticFallback: () async {},
      defaultTargetPlatformProvider: () => TargetPlatform.android,
    );

    await player.vibrate();

    expect(patterns, [
      [0, 200, 100, 200],
    ]);
  });

  test('message vibration uses haptics on iOS instead of vibration pattern',
      () async {
    var hapticCount = 0;
    final patterns = <List<int>>[];
    final player = MessageVibrationPlayer(
      hasVibrator: () async => true,
      vibrateDevice: ({List<int> pattern = const []}) async {
        patterns.add(pattern);
      },
      hapticFallback: () async {
        hapticCount++;
      },
      defaultTargetPlatformProvider: () => TargetPlatform.iOS,
    );

    await player.vibrate();

    expect(patterns, isEmpty);
    expect(hapticCount, 1);
  });

  test('message vibration falls back to haptics on vibration errors', () async {
    var hapticCount = 0;
    final player = MessageVibrationPlayer(
      hasVibrator: () async => true,
      vibrateDevice: ({List<int> pattern = const []}) async {
        throw StateError('no vibration');
      },
      hapticFallback: () async {
        hapticCount++;
      },
      defaultTargetPlatformProvider: () => TargetPlatform.android,
    );

    await player.vibrate();

    expect(hapticCount, 1);
  });
}

EventUpdate _messageUpdate({
  String roomId = '!room:p2p-im.com',
  required String sender,
  EventUpdateType updateType = EventUpdateType.timeline,
}) {
  return EventUpdate(
    roomID: roomId,
    type: updateType,
    content: {
      'type': EventTypes.Message,
      'sender': sender,
      'content': {
        'msgtype': MessageTypes.Text,
        'body': 'hello',
      },
    },
  );
}
