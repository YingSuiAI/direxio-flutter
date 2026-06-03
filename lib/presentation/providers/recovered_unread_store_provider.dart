import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/recovered_unread_store.dart';

final recoveredUnreadStoreProvider = FutureProvider<RecoveredUnreadStore>((
  ref,
) async {
  final dir = await getApplicationSupportDirectory();
  return FileRecoveredUnreadStore(
    File('${dir.path}/portal_im_recovered_unread.json'),
  );
});
