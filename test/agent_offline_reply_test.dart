import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/chat_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/agent_bridge_presence_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';

void main() {
  testWidgets('offline Agent replies once for each sent message',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const roomId = '!agent-room:p2p-im.com';
    const ownerMxid = '@owner:p2p-im.com';
    const agentMxid = '@agent:p2p-im.com';
    var sendCalls = 0;
    final client = Client(
      'DirexioAgentOfflineReplyPerSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          sendCalls++;
          return http.Response(
            '{"event_id":"\\\$agent-question-$sendCalls"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId(ownerMxid);
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    final room = Room(
      id: roomId,
      client: client,
      membership: Membership.join,
      summary: RoomSummary.fromJson({
        'm.joined_member_count': 2,
        'm.invited_member_count': 0,
      }),
    );
    client.rooms.add(room);
    room.prev_batch = 't0';
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: ownerMxid,
        stateKey: ownerMxid,
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: agentMxid,
        stateKey: agentMxid,
        content: const {'membership': 'join', 'displayname': 'Agent'},
      ),
    );
    room.lastEvent = Event(
      room: room,
      eventId: r'$agent-ready',
      senderId: agentMxid,
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 26, 8),
      content: const {
        'msgtype': MessageTypes.Text,
        'body': 'Ready',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 26),
      user: const AsSyncUser(userId: ownerMxid),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
      agentRoomId: roomId,
    );
    var showChatPage = true;
    late StateSetter setShellState;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_NoopAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          agentBridgePresenceProvider.overrideWithValue(
            const AgentBridgePresence(
              state: AgentBridgePresenceState.offline,
              online: false,
            ),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: StatefulBuilder(
            builder: (context, setState) {
              setShellState = setState;
              return showChatPage
                  ? const ChatPage(roomId: roomId)
                  : const SizedBox(
                      key: ValueKey('agent_offline_reply_other_page'),
                    );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat_input_send_button')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat_input_send_button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('private_message_enter_agent_offline_reply_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('private_message_enter_agent_offline_reply_1')),
      findsOneWidget,
    );

    setShellState(() => showChatPage = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('agent_offline_reply_other_page')),
      findsOneWidget,
    );

    setShellState(() => showChatPage = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('private_message_enter_agent_offline_reply_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('private_message_enter_agent_offline_reply_1')),
      findsOneWidget,
    );

    await client.dispose(closeDatabase: false);
  });
}

class _MemoryLocalOutboxStore implements LocalOutboxStore {
  final List<LocalOutboxItem> items = [];

  @override
  Future<List<LocalOutboxItem>> readAll() async => [...items];

  @override
  Future<void> upsert(LocalOutboxItem item) async {
    items.removeWhere((existing) => existing.id == item.id);
    items.add(item);
  }

  @override
  Future<void> remove(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}

class _NoopAsClient implements AsClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
