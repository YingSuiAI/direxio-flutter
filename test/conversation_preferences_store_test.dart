import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/conversation_preferences_store.dart';

void main() {
  late Directory tempDir;
  late FileConversationPreferencesStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'portal_conversation_preferences_test',
    );
    store = FileConversationPreferencesStore(
      File('${tempDir.path}/portal_im_conversation_preferences.json'),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists local conversation preference ids', () async {
    await store.write(
      const ConversationPreferencesData(
        pinnedConversationIds: {'!pinned:example.com'},
        groupRemarkNames: {'!group:example.com': '项目群'},
        groupAvatarMemberOrders: {
          '!group:example.com': [
            '@bob:example.com',
            '@owner:example.com',
            '@alice:example.com',
          ],
        },
        mutedConversationIds: {'!muted:example.com'},
        hiddenConversationIds: {'!hidden:example.com'},
      ),
    );

    final data = await store.read();

    expect(data.pinnedConversationIds, {'!pinned:example.com'});
    expect(data.groupRemarkNames, {'!group:example.com': '项目群'});
    expect(data.groupAvatarMemberOrders, {
      '!group:example.com': [
        '@bob:example.com',
        '@owner:example.com',
        '@alice:example.com',
      ],
    });
    expect(data.mutedConversationIds, {'!muted:example.com'});
    expect(data.hiddenConversationIds, {'!hidden:example.com'});
  });
}
