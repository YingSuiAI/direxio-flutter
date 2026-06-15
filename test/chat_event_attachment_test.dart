import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/utils/chat_event_attachment.dart';

void main() {
  test('downloads attachment when AS puts media url in info map', () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventAttachmentCompatTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$voice-info-url',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'voice',
        'info': {
          'url': 'mxc://p2p-im.com/voice',
          'mime_type': 'audio/mp4',
          'duration_ms': 1500,
          'size': 4,
        },
      },
    );

    final file = await downloadChatEventAttachment(event);

    expect(file.bytes, [1, 2, 3, 4]);
    expect(requests.single.path, contains('/download/p2p-im.com/voice'));
  });
}
