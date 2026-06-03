import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum LocalOutboxConversationType {
  direct,
  group,
  channel,
  agent,
}

enum LocalOutboxMessageKind {
  text,
  image,
  video,
  file,
}

enum LocalOutboxItemStatus {
  sending,
  failed,
}

class LocalOutboxItem {
  LocalOutboxItem({
    required this.id,
    required this.conversationId,
    required this.conversationType,
    required this.messageKind,
    required this.text,
    required this.filename,
    required this.mimeType,
    Uint8List? bytes,
    this.thumbnailBytes,
    String encodedBytes = '',
    int? byteLength,
    required this.createdAt,
    required this.status,
    required this.runtimeId,
    required this.batchId,
    required this.batchIndex,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
  })  : _bytes = bytes,
        _encodedBytes = encodedBytes,
        byteLength = byteLength ?? bytes?.length ?? 0;

  factory LocalOutboxItem.fromJson(Map<String, dynamic> json) {
    final legacyRoomId = _string(json['room_id']);
    final conversationId = _string(json['conversation_id']);
    final encodedBytes = _string(json['bytes']);
    return LocalOutboxItem(
      id: _string(json['id']),
      conversationId: conversationId.isNotEmpty ? conversationId : legacyRoomId,
      conversationType: LocalOutboxConversationType.values.firstWhere(
        (type) => type.name == _string(json['conversation_type']),
        orElse: () => LocalOutboxConversationType.direct,
      ),
      messageKind: LocalOutboxMessageKind.values.firstWhere(
        (kind) => kind.name == _string(json['message_kind']),
        orElse: () => LocalOutboxMessageKind.image,
      ),
      text: _string(json['text']).isNotEmpty
          ? _string(json['text'])
          : _string(json['body']),
      filename: _string(json['filename']),
      mimeType: _string(json['mime_type']),
      encodedBytes: encodedBytes,
      thumbnailBytes: _bytesOrNull(json['thumbnail_bytes']),
      byteLength: _int(json['byte_length']),
      createdAt: DateTime.tryParse(_string(json['created_at'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: LocalOutboxItemStatus.values.firstWhere(
        (status) => status.name == _string(json['status']),
        orElse: () => LocalOutboxItemStatus.failed,
      ),
      runtimeId: _string(json['runtime_id']),
      batchId: _string(json['batch_id']).isNotEmpty
          ? _string(json['batch_id'])
          : _string(json['id']),
      batchIndex: _int(json['batch_index']),
      width: _int(json['width']),
      height: _int(json['height']),
      durationMs: _int(json['duration_ms']),
    );
  }

  final String id;
  final String conversationId;
  final LocalOutboxConversationType conversationType;
  final LocalOutboxMessageKind messageKind;
  final String text;
  final String filename;
  final String mimeType;
  Uint8List? _bytes;
  final String _encodedBytes;
  final Uint8List? thumbnailBytes;
  final int byteLength;
  final DateTime createdAt;
  final LocalOutboxItemStatus status;
  final String runtimeId;
  final String batchId;
  final int batchIndex;
  final int width;
  final int height;
  final int durationMs;

  bool get hasOriginalBytes => _bytes != null || _encodedBytes.isNotEmpty;

  Uint8List? get bytes {
    final current = _bytes;
    if (current != null) return current;
    if (_encodedBytes.isEmpty) return null;
    try {
      _bytes = base64Decode(_encodedBytes);
      return _bytes;
    } catch (_) {
      return null;
    }
  }

  LocalOutboxItem copyWith({
    String? id,
    String? conversationId,
    LocalOutboxConversationType? conversationType,
    LocalOutboxMessageKind? messageKind,
    String? text,
    String? filename,
    String? mimeType,
    Uint8List? bytes,
    Uint8List? thumbnailBytes,
    String? encodedBytes,
    int? byteLength,
    DateTime? createdAt,
    LocalOutboxItemStatus? status,
    String? runtimeId,
    String? batchId,
    int? batchIndex,
    int? width,
    int? height,
    int? durationMs,
  }) {
    return LocalOutboxItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      conversationType: conversationType ?? this.conversationType,
      messageKind: messageKind ?? this.messageKind,
      text: text ?? this.text,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? _bytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      encodedBytes: encodedBytes ?? _encodedBytes,
      byteLength: byteLength ?? this.byteLength,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      runtimeId: runtimeId ?? this.runtimeId,
      batchId: batchId ?? this.batchId,
      batchIndex: batchIndex ?? this.batchIndex,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() {
    final bytes = _bytes;
    return {
      'id': id,
      'conversation_id': conversationId,
      'conversation_type': conversationType.name,
      'message_kind': messageKind.name,
      'text': text,
      'filename': filename,
      'mime_type': mimeType,
      'bytes': _encodedBytes.isNotEmpty
          ? _encodedBytes
          : bytes == null
              ? ''
              : base64Encode(bytes),
      'thumbnail_bytes':
          thumbnailBytes == null ? '' : base64Encode(thumbnailBytes!),
      'byte_length': byteLength,
      'created_at': createdAt.toUtc().toIso8601String(),
      'status': status.name,
      'runtime_id': runtimeId,
      'batch_id': batchId,
      'batch_index': batchIndex,
      'width': width,
      'height': height,
      'duration_ms': durationMs,
    };
  }

  static String _string(Object? value) => value is String ? value : '';

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Uint8List? _bytesOrNull(Object? value) {
    final encoded = _string(value);
    if (encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}

abstract class LocalOutboxStore {
  Future<List<LocalOutboxItem>> readAll();

  Future<void> upsert(LocalOutboxItem item);

  Future<void> remove(String id);
}

class DeferredLocalOutboxStore implements LocalOutboxStore {
  const DeferredLocalOutboxStore(this._load);

  final Future<LocalOutboxStore> Function() _load;

  @override
  Future<List<LocalOutboxItem>> readAll() async {
    return (await _load()).readAll();
  }

  @override
  Future<void> upsert(LocalOutboxItem item) async {
    await (await _load()).upsert(item);
  }

  @override
  Future<void> remove(String id) async {
    await (await _load()).remove(id);
  }
}

class FileLocalOutboxStore implements LocalOutboxStore {
  const FileLocalOutboxStore(
    this.file, {
    this.maxBytesPerItem = 12 * 1024 * 1024,
  });

  final File file;
  final int maxBytesPerItem;

  @override
  Future<List<LocalOutboxItem>> readAll() async {
    if (!await file.exists()) return const [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const [];
      final json = jsonDecode(content);
      if (json is! List) return const [];
      return [
        for (final item in json)
          if (item is Map<String, dynamic>)
            _validOrNull(LocalOutboxItem.fromJson(item)),
      ].whereType<LocalOutboxItem>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> upsert(LocalOutboxItem item) async {
    final normalized = _validOrNull(item);
    if (normalized == null) return;
    final current = await readAll();
    final next = [
      for (final existing in current)
        if (existing.id != normalized.id) existing,
      normalized,
    ];
    await _write(next);
  }

  @override
  Future<void> remove(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    final current = await readAll();
    final next = [
      for (final item in current)
        if (item.id != trimmed) item,
    ];
    await _write(next);
  }

  LocalOutboxItem? _validOrNull(LocalOutboxItem item) {
    if (item.id.trim().isEmpty || item.conversationId.trim().isEmpty) {
      return null;
    }
    switch (item.messageKind) {
      case LocalOutboxMessageKind.text:
        if (item.text.trim().isEmpty) return null;
      case LocalOutboxMessageKind.image:
      case LocalOutboxMessageKind.video:
      case LocalOutboxMessageKind.file:
        if (!item.hasOriginalBytes ||
            item.byteLength > maxBytesPerItem ||
            item.filename.trim().isEmpty) {
          return null;
        }
    }
    return item;
  }

  Future<void> _write(List<LocalOutboxItem> items) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final item in items) item.toJson()]),
      flush: true,
    );
  }
}

List<LocalOutboxItem> markStaleLocalOutboxItemsFailed(
  List<LocalOutboxItem> items, {
  required String currentRuntimeId,
}) {
  return [
    for (final item in items)
      if (item.status == LocalOutboxItemStatus.sending &&
          item.runtimeId != currentRuntimeId)
        item.copyWith(status: LocalOutboxItemStatus.failed)
      else
        item,
  ];
}
