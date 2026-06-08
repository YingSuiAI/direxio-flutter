import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';

void main() {
  test('channel share payload parses structured Matrix content', () {
    final payload = channelSharePayloadFromContent({
      chatRecordMatrixMarkerKey: channelShareMessageType,
      channelShareMatrixPayloadKey: {
        'channel_id': 'ch_product',
        'room_id': '!channel:p2p-im.com',
        'home_domain': 'p2p-im.com',
        'name': '产品公告',
        'description': '只发布重要产品更新',
        'visibility': 'public',
        'join_policy': 'open',
        'comments_enabled': true,
        'tags': ['产品'],
      },
    });

    expect(payload, isNotNull);
    expect(payload!.channelId, 'ch_product');
    expect(payload.roomId, '!channel:p2p-im.com');
    expect(payload.displayName, '产品公告');
    expect(payload.asDraft.toJson()['channel_id'], 'ch_product');
  });

  testWidgets('channel share preview card renders channel summary',
      (tester) async {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
      tags: ['产品'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ChannelSharePreviewCard(payload: payload),
          ),
        ),
      ),
    );

    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('只发布重要产品更新'), findsOneWidget);
    expect(find.text('频道'), findsOneWidget);
  });
}
