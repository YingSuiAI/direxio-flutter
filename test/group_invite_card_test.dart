import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/chat/chat_message_cards.dart';
import 'package:portal_app/presentation/groups/group_invite_card.dart';
import 'package:portal_app/presentation/groups/group_invite_content.dart';

void main() {
  testWidgets('renders group invite and invokes join action', (tester) async {
    var joins = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
              inviterDisplayName: 'Yanan',
            ),
            joining: false,
            onJoin: () => joins++,
          ),
        ),
      ),
    );

    expect(find.text('邀请加入群聊'), findsOneWidget);
    expect(find.text('Yanan 邀请你加入“产品测试群”'), findsOneWidget);
    expect(find.textContaining('拒绝'), findsNothing);

    await tester.tap(find.text('加入群聊'));
    expect(joins, 1);
  });

  testWidgets('uses product display name instead of Matrix owner fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            inviterDisplayName: 'Yanan',
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
              inviterDisplayName: 'owner',
            ),
            joining: false,
            onJoin: () {},
          ),
        ),
      ),
    );

    expect(find.text('Yanan 邀请你加入“产品测试群”'), findsOneWidget);
    expect(find.textContaining('owner'), findsNothing);
  });

  testWidgets('localizes sender self label in English invite body',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: GroupInviteCard(
            inviterDisplayName: '我',
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: 'jenfnd',
            ),
            joining: false,
            onJoin: () {},
          ),
        ),
      ),
    );

    expect(find.text('Me invited you to join "jenfnd"'), findsOneWidget);
    expect(find.textContaining('我 invited'), findsNothing);
  });

  testWidgets('renders group avatar inside invite card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            inviterDisplayName: 'Yanan',
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
              inviterDisplayName: 'owner',
            ),
            joining: false,
            onJoin: () {},
          ),
        ),
      ),
    );

    final avatar =
        tester.widget<ChatGroupAvatarTile>(find.byType(ChatGroupAvatarTile));
    expect(avatar.seed, '产品测试群');
  });

  testWidgets('disables join action while joining', (tester) async {
    var joins = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
            ),
            joining: true,
            onJoin: () => joins++,
          ),
        ),
      ),
    );

    expect(find.text('正在加入“产品测试群”'), findsOneWidget);
    await tester.tap(find.text('加入中…'));
    expect(joins, 0);
  });

  testWidgets('greys already joined button without joining again',
      (tester) async {
    var joins = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
            ),
            joining: false,
            alreadyJoined: true,
            onJoin: () => joins++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('已在群聊中'));
    await tester.pump();

    expect(joins, 0);
    expect(find.text('已在群聊中'), findsOneWidget);
    expect(find.text('加入群聊'), findsNothing);
  });

  testWidgets('uses compact chat-bubble dimensions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 390 * groupInviteCardMaxWidthFactor,
                ),
                child: GroupInviteCard(
                  invite: const GroupInviteContent(
                    groupRoomId: '!group:p2p-im.com',
                    groupName: '产品测试群',
                    inviterDisplayName: 'Yanan',
                  ),
                  joining: false,
                  onJoin: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(GroupInviteCard));
    expect(size.width, chatMessageCardTotalWidth);
    expect(size.height, chatMessageCardHeight);
  });

  testWidgets('uses unified message corner radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupInviteCard(
            invite: const GroupInviteContent(
              groupRoomId: '!group:p2p-im.com',
              groupName: '产品测试群',
              inviterDisplayName: 'Yanan',
            ),
            joining: false,
            onJoin: () {},
          ),
        ),
      ),
    );

    final card =
        tester.widgetList<Container>(find.byType(Container)).firstWhere(
              (container) =>
                  container.padding == const EdgeInsets.fromLTRB(13, 10, 13, 9),
            );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.borderRadius, chatMessageBubbleRadius);
  });
}
