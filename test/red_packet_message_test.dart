import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_message_cards.dart';
import 'package:portal_app/presentation/chat/red_packet_message.dart';

void main() {
  test('parses mine red packet custom payload from nested data string', () {
    final payload = redPacketPayloadFromContent({
      'msgtype': 'custom',
      'body': '扫雷红包',
      'customType': 932,
      'data':
          '{"packetNo":"mine-001","packetType":1,"blessing":"恭喜发财","totalAmount":"10","currencyName":"USDT"}',
    });

    expect(payload, isNotNull);
    expect(payload!.packetNo, 'mine-001');
    expect(payload.isMine, isTrue);
    expect(payload.isGroup, isTrue);
    expect(payload.blessing, '恭喜发财');
    expect(payload.amount, '10');
  });

  test('parses red packet id aliases from message body json', () {
    final payload = redPacketPayloadFromContent(
      const {},
      body: '{"customType":923,"data":{"redPacketId":"rp-1","remark":"好运连连"}}',
    );

    expect(payload, isNotNull);
    expect(payload!.packetNo, 'rp-1');
    expect(payload.isMine, isFalse);
    expect(payload.blessing, '好运连连');
  });

  testWidgets('mine red packet detail renders parsed content', (tester) async {
    const payload = RedPacketPayload(
      packetNo: 'mine-001',
      isMine: true,
      isGroup: true,
      title: '扫雷红包',
      blessing: '恭喜发财',
      amount: '10',
      currency: 'USDT',
      raw: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const RedPacketDetailPage(payload: payload),
      ),
    );

    expect(find.text('扫雷红包详情'), findsOneWidget);
    expect(find.text('mine-001'), findsOneWidget);
    expect(find.text('10 USDT'), findsOneWidget);
  });

  testWidgets('red packet message card uses shared message corner radius',
      (tester) async {
    const payload = RedPacketPayload(
      packetNo: 'mine-001',
      isMine: true,
      isGroup: true,
      title: '扫雷红包',
      blessing: '恭喜发财',
      amount: '10',
      currency: 'USDT',
      raw: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: RedPacketMessageCard(payload: payload, isMe: true),
        ),
      ),
    );

    final outerCard = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) => decoration.borderRadius == chatMessageBubbleRadius,
        );
    expect(outerCard.borderRadius, chatMessageBubbleRadius);
  });
}
