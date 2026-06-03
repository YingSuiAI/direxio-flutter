import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/as_call_session_store.dart';

final asCallSessionStoreProvider = FutureProvider<AsCallSessionStore>((
  ref,
) async {
  final dir = await getApplicationSupportDirectory();
  return FileAsCallSessionStore(
    File('${dir.path}/portal_im_call_sessions.json'),
  );
});
