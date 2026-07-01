import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_event_cursor_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FileAsEventCursorStore', () {
    late Directory tempDir;
    late FileAsEventCursorStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('portal_event_cursor');
      store = FileAsEventCursorStore(File('${tempDir.path}/cursor.json'));
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('write read and clear cursor', () async {
      expect(await store.readLastSeq(), 0);

      await store.writeLastSeq(42);

      expect(await store.readLastSeq(), 42);

      await store.clear();

      expect(await store.readLastSeq(), 0);
    });

    test('normalizes corrupt or negative cursor', () async {
      await File('${tempDir.path}/cursor.json').writeAsString('{bad json');
      expect(await store.readLastSeq(), 0);

      await store.writeLastSeq(-1);
      expect(await store.readLastSeq(), 0);
    });
  });

  group('SharedPreferencesAsEventCursorStore', () {
    test('write read and clear web cursor', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesAsEventCursorStore(preferences);

      expect(await store.readLastSeq(), 0);

      await store.writeLastSeq(88);

      expect(await store.readLastSeq(), 88);

      await store.clear();

      expect(await store.readLastSeq(), 0);
    });

    test('normalizes missing malformed and negative web cursor', () async {
      SharedPreferences.setMockInitialValues({
        'direxio_p2p_event_cursor.last_seq': 'not a number',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesAsEventCursorStore(preferences);

      expect(await store.readLastSeq(), 0);

      await store.writeLastSeq(-5);

      expect(await store.readLastSeq(), 0);
    });
  });
}
