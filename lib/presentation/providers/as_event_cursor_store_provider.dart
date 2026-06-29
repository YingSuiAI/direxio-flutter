import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/as_event_cursor_store.dart';

final asEventCursorStoreProvider =
    FutureProvider<AsEventCursorStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileAsEventCursorStore(
    File('${dir.path}/direxio_p2p_event_cursor.json'),
  );
});
