import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_history_backfill_policy.dart';
import 'package:portal_app/presentation/utils/message_history_policy.dart';

void main() {
  test('requests local backfill when call signaling crowds out messages', () {
    final client = Client('ChatHistoryBackfillPolicyTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final events = [
      _event(room, r'$invite', EventTypes.CallInvite),
      _event(room, r'$answer', EventTypes.CallAnswer),
      _event(room, r'$candidate', EventTypes.CallCandidates),
      _event(room, r'$hangup', EventTypes.CallHangup),
      Event(
        room: room,
        eventId: r'$text',
        senderId: '@me:p2p-im.com',
        type: EventTypes.Message,
        originServerTs: DateTime.utc(2026, 5, 30, 1, 0, 5),
        content: {
          'msgtype': MessageTypes.Text,
          'body': 'hello',
        },
      ),
    ];

    expect(visibleMessageCountForChatOpenHistory(events), 1);
    expect(
      shouldBackfillLocalChatOpenHistory(
        timelineEvents: events,
        hasStoredOlderEvents: true,
      ),
      isTrue,
    );
  });

  test('requests a concrete chat-open history page when local store is empty',
      () {
    final client = Client('ChatHistoryNoStoredBackfillTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final events = [
      _event(room, r'$hangup', EventTypes.CallHangup),
    ];

    expect(
      shouldBackfillLocalChatOpenHistory(
        timelineEvents: events,
        hasStoredOlderEvents: false,
      ),
      isFalse,
    );
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen),
      isTrue,
    );
  });

  test('counts visible messages for initial chat-open page threshold', () {
    final client = Client('ChatInitialPageCountTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final events = List<Event>.generate(
      chatOpenLocalHistoryPageSize,
      (index) => Event(
        room: room,
        eventId: '\$text_$index',
        senderId: '@me:p2p-im.com',
        type: EventTypes.Message,
        originServerTs: DateTime.utc(2026, 5, 30, 1, 0, index),
        content: {
          'msgtype': MessageTypes.Text,
          'body': 'hello $index',
        },
      ),
    );

    expect(
      visibleMessageCountForChatOpenHistory(events),
      chatOpenLocalHistoryPageSize,
    );
  });

  test('syncs empty room history only before local pagination exists', () {
    final client = Client('ChatEmptyRoomHistorySyncPolicyTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final events = [
      Event(
        room: room,
        eventId: r'$text',
        senderId: '@me:p2p-im.com',
        type: EventTypes.Message,
        originServerTs: DateTime.utc(2026, 5, 30, 1),
        content: {
          'msgtype': MessageTypes.Text,
          'body': 'hello',
        },
      ),
    ];

    expect(
      shouldSyncEmptyRoomHistoryOnOpen(
        timelineEvents: const <Event>[],
        prevBatch: null,
      ),
      isTrue,
    );
    expect(
      shouldSyncEmptyRoomHistoryOnOpen(
        timelineEvents: events,
        prevBatch: null,
      ),
      isFalse,
    );
    expect(
      shouldSyncEmptyRoomHistoryOnOpen(
        timelineEvents: const <Event>[],
        prevBatch: 'batch-token',
      ),
      isFalse,
    );
  });
}

Event _event(Room room, String eventId, String type) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: '@me:p2p-im.com',
    type: type,
    originServerTs: DateTime.utc(2026, 5, 30, 1),
    content: {
      'call_id': 'call-1',
      'version': 1,
    },
  );
}
