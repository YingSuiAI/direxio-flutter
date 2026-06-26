import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/group_info_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('group info localizes visible labels in English', (tester) async {
    const roomId = '!group:p2p-im.com';
    final client = Client('DirexioGroupInfoEnglishL10nTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: 'Project Group',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          groupMembersProvider.overrideWith((ref, key) => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const GroupInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat Info (2)'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Group Management'), findsOneWidget);
    expect(find.text('Set Remark'), findsOneWidget);
    expect(find.text('Search Chat'), findsOneWidget);
    expect(find.text('Mute Messages'), findsOneWidget);
    expect(find.text('聊天信息(2)'), findsNothing);
    expect(find.text('群管理'), findsNothing);
    expect(find.text('查找聊天记录'), findsNothing);
  });
}

Room _addNamedGroupRoom(
  Client client, {
  required String roomId,
  required String name,
  String? creatorMxid,
  Membership membership = Membership.join,
  Map<String, String> members = const {},
}) {
  final selfMxid = client.userID ?? '@owner:p2p-im.com';
  final creator = creatorMxid ?? selfMxid;
  final room = Room(
    id: roomId,
    client: client,
    membership: membership,
  );
  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: selfMxid,
      stateKey: selfMxid,
      content: {'membership': membership.name},
    ),
  );
  for (final entry in members.entries) {
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: entry.key,
        stateKey: entry.key,
        content: {
          'membership': Membership.join.name,
          'displayname': entry.value,
        },
      ),
    );
  }
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomName,
      senderId: selfMxid,
      stateKey: '',
      content: {'name': name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomCreate,
      senderId: creator,
      stateKey: '',
      content: {'creator': creator},
    ),
  );
  return room;
}
