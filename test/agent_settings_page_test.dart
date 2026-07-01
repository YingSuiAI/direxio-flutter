import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/agent_settings_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/product_conversations_provider.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

import 'support/mock_as_client.dart';

void main() {
  testWidgets('agent settings edits blocked rooms from current conversations',
      (tester) async {
    final asClient = _AgentSettingsAsClient(
      const AgentConfig(
        displayName: 'Ops Agent',
        avatarUrl: 'mxc://example.com/agent',
        contextWindow: 64,
        mcpBlockedRoomIds: ['!blocked:p2p-im.com'],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          productConversationsProvider.overrideWith(
            (_) async => const [
              AsConversation(
                conversationId: 'conv_visible',
                roomId: '!visible:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: 'Visible Group',
                avatarUrl: '',
              ),
              AsConversation(
                conversationId: 'conv_blocked',
                roomId: '!blocked:p2p-im.com',
                kind: asConversationKindDirect,
                lifecycle: 'active',
                title: 'Blocked Alice',
                avatarUrl: '',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AgentSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent 设置'), findsOneWidget);
    expect(find.text('Ops Agent'), findsOneWidget);
    expect(find.text('已屏蔽 1 个房间'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent_blocked_rooms_row')));
    await tester.pumpAndSettle();

    expect(find.text('选择需要屏蔽的房间'), findsOneWidget);
    expect(find.text('Visible Group'), findsOneWidget);
    expect(find.text('Blocked Alice'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('agent_room_picker_!blocked:p2p-im.com')),
          )
          .value,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent_room_picker_!visible:p2p-im.com')),
    );
    await tester.tap(find.byKey(const ValueKey('agent_room_picker_save')));
    await tester.pumpAndSettle();

    expect(asClient.config.mcpBlockedRoomIds, [
      '!blocked:p2p-im.com',
      '!visible:p2p-im.com',
    ]);
    expect(find.text('已屏蔽 2 个房间'), findsOneWidget);
  });

  testWidgets('agent settings uploads avatar through picker result',
      (tester) async {
    final asClient = _AgentSettingsAsClient(
      const AgentConfig(displayName: 'Ops Agent', contextWindow: 64),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          productConversationsProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AgentSettingsPage(
            pickAvatarUrl: (_, __) async => 'mxc://example.com/uploaded-agent',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('agent_profile_avatar')));
    await tester.pumpAndSettle();

    expect(asClient.config.avatarUrl, 'mxc://example.com/uploaded-agent');
    expect(find.text('头像 URL'), findsNothing);
  });

  testWidgets('agent settings renders current mxc avatar as media URL',
      (tester) async {
    final client = Client('AgentSettingsAvatarTest')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final asClient = _AgentSettingsAsClient(
      const AgentConfig(
        displayName: 'Ops Agent',
        avatarUrl: 'mxc://p2p-im.com/agent-avatar',
        contextWindow: 64,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          productConversationsProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AgentSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar).first);
    expect(avatar.imageUrl, isNot('mxc://p2p-im.com/agent-avatar'));
    expect(avatar.imageUrl, startsWith('https://p2p-im.com'));
  });
}

class _AgentSettingsAsClient extends MockAsClient {
  _AgentSettingsAsClient(this.config);

  AgentConfig config;

  @override
  Future<AgentConfig> getAgentConfig() async => config;

  @override
  Future<AgentConfig> updateAgentConfig(AgentConfig next) async {
    config = next;
    return config;
  }
}
