import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/as_event_cursor_store.dart';

final asEventCursorStoreProvider =
    FutureProvider<AsEventCursorStore>((ref) async {
  if (kIsWeb) {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAsEventCursorStore(preferences);
  }
  final dir = await getApplicationSupportDirectory();
  return FileAsEventCursorStore(
    File('${dir.path}/direxio_p2p_event_cursor.json'),
  );
});
