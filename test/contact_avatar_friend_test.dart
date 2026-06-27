import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/contact_detail_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

import 'support/mock_as_client.dart';

void main() {
  testWidgets(
      'contact-list avatar page keeps accepted friend state before room hydrates',
      (tester) async {
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('ContactAvatarFriendHydrationTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 27),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
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
          asClientProvider
              .overrideWithValue(_ImmediatePublicChannelsAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(
            userId: peerMxid,
            fromChatAvatar: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('把他推荐给朋友'), findsOneWidget);
    expect(find.text('添加好友'), findsNothing);
  });
}

class _ImmediatePublicChannelsAsClient extends MockAsClient {
  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    return const [];
  }
}
