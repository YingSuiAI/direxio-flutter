import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_media_warmup.dart';

void main() {
  test('selects recent image event ids for thumbnail warmup', () {
    final client = Client('ChatMediaWarmupTest')..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final events = [
      _event(room, r'$image-1', MessageTypes.Image),
      _event(room, r'$text', MessageTypes.Text),
      _event(room, r'$image-2', MessageTypes.Image),
      _event(room, r'$image-1', MessageTypes.Image),
    ];

    expect(thumbnailEventIdsForEvents(events), [r'$image-1', r'$image-2']);
  });

  test('limits thumbnail warmup ids', () {
    final client = Client('ChatMediaWarmupLimitTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    expect(
      thumbnailEventIdsForEvents([
        _event(room, r'$image-1', MessageTypes.Image),
        _event(room, r'$image-2', MessageTypes.Image),
      ], limit: 1),
      [r'$image-1'],
    );
  });
}

Event _event(Room room, String eventId, String msgType) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: '@peer:p2p-im.com',
    type: EventTypes.Message,
    originServerTs: DateTime.utc(2026, 5, 28),
    content: {
      'msgtype': msgType,
      'body': 'message',
    },
  );
}
