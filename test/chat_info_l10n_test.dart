import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/chat_info_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

import 'support/mock_as_client.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('chat info localizes labels in English', (tester) async {
    const roomId = '!owner:p2p-im.com';
    const peerMxid = '@owner:p2p-liyanan.com';
    final client = Client('DirexioChatInfoEnglishL10nTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 25, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'owner',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_ChatInfoL10nAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ChatInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat Info'), findsOneWidget);
    expect(find.text('Search Chat'), findsOneWidget);
    expect(find.text('His Channels'), findsOneWidget);
    expect(find.text('Set Remark'), findsOneWidget);
    expect(find.text('Mute Messages'), findsOneWidget);
    expect(find.text('Clear Chat History'), findsOneWidget);
    expect(find.text('Block User'), findsOneWidget);
    expect(find.text('Report User'), findsOneWidget);
    expect(find.text('Delete Friend'), findsOneWidget);
    expect(find.text('聊天信息'), findsNothing);
    expect(find.text('搜索聊天记录'), findsNothing);
  });
}

class _ChatInfoL10nAsClient extends MockAsClient {
  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    return const [];
  }
}

Room _addUndirectedJoinedRoom(
  Client client, {
  required String roomId,
  required String peerMxid,
  required String peerName,
}) {
  final room = Room(
    id: roomId,
    client: client,
    membership: Membership.join,
  );
  client.rooms.add(room);
  final selfMxid = client.userID ?? '@owner:p2p-im.com';
  room.setState(
    StrippedStateEvent(
      type: 'io.direxio.room.profile',
      senderId: selfMxid,
      stateKey: '',
      content: {
        'room_type': 'io.direxio.room.direct',
        'room_id': roomId,
        'requester_mxid': selfMxid,
        'target_mxid': peerMxid,
        'display_name': peerName,
      },
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: selfMxid,
      stateKey: selfMxid,
      content: {'membership': Membership.join.name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: peerMxid,
      stateKey: peerMxid,
      content: {
        'membership': Membership.join.name,
        'displayname': peerName,
      },
    ),
  );
  return room;
}
