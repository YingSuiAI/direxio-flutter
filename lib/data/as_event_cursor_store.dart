import 'dart:convert';
import 'dart:io';

abstract class AsEventCursorStore {
  Future<int> readLastSeq();

  Future<void> writeLastSeq(int seq);

  Future<void> clear();
}

class DeferredAsEventCursorStore implements AsEventCursorStore {
  const DeferredAsEventCursorStore(this._load);

  final Future<AsEventCursorStore> Function() _load;

  @override
  Future<int> readLastSeq() async => (await _load()).readLastSeq();

  @override
  Future<void> writeLastSeq(int seq) async {
    await (await _load()).writeLastSeq(seq);
  }

  @override
  Future<void> clear() async => (await _load()).clear();
}

class FileAsEventCursorStore implements AsEventCursorStore {
  const FileAsEventCursorStore(this.file);

  final File file;

  @override
  Future<int> readLastSeq() async {
    if (!await file.exists()) return 0;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return 0;
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final raw = decoded['last_seq'];
        if (raw is int) return raw < 0 ? 0 : raw;
        if (raw is num) return raw < 0 ? 0 : raw.toInt();
        final parsed = int.tryParse(raw?.toString() ?? '');
        return parsed == null || parsed < 0 ? 0 : parsed;
      }
    } catch (_) {
      return 0;
    }
    return 0;
  }

  @override
  Future<void> writeLastSeq(int seq) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'last_seq': seq < 0 ? 0 : seq}),
      flush: true,
    );
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
