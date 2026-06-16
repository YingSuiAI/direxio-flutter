import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/chat_clear_state_store.dart';

final chatClearStateStoreProvider = FutureProvider<ChatClearStateStore>((
  ref,
) async {
  final dir = await getApplicationSupportDirectory();
  return FileChatClearStateStore(
    File('${dir.path}/portal_im_chat_clear_state.json'),
  );
});
