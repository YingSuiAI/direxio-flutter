import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/home_conversation_snapshot_store.dart';

final homeConversationSnapshotStoreProvider =
    FutureProvider<HomeConversationSnapshotStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileHomeConversationSnapshotStore(
    File('${dir.path}/portal_im_home_conversations.json'),
  );
});

final homeConversationSnapshotProvider =
    FutureProvider<HomeConversationSnapshot?>((ref) async {
  final store = await ref.watch(homeConversationSnapshotStoreProvider.future);
  return store.read();
});

void persistHomeConversationSnapshot(
  WidgetRef ref,
  HomeConversationSnapshot snapshot,
) {
  unawaited(
    ref
        .read(homeConversationSnapshotStoreProvider.future)
        .then((store) => store.write(snapshot))
        .catchError((Object error) {
      debugPrint('persist home conversation snapshot failed: $error');
    }),
  );
}
