import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
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

  test('message vibration uses mobile-compatible pattern', () async {
    final patterns = <List<int>>[];
    final player = MessageVibrationPlayer(
      hasVibrator: () async => true,
      vibrateDevice: ({List<int> pattern = const []}) async {
        patterns.add(pattern);
      },
      hapticFallback: () async {},
    );

    await player.vibrate();

    expect(patterns, [
      [0, 200, 100, 200],
    ]);
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
    );

    await player.vibrate();

    expect(hapticCount, 1);
  });
}

EventUpdate _messageUpdate({
  required String sender,
  EventUpdateType updateType = EventUpdateType.timeline,
}) {
  return EventUpdate(
    roomID: '!room:p2p-im.com',
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
