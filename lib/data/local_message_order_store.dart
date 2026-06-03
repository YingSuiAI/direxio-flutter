import 'dart:convert';
import 'dart:io';

import 'local_outbox_store.dart';

class LocalMessageOrderEntry {
  const LocalMessageOrderEntry({
    required this.eventId,
    required this.conversationId,
    required this.conversationType,
    required this.createdAt,
    required this.batchId,
    required this.batchIndex,
  });

  factory LocalMessageOrderEntry.fromJson(Map<String, dynamic> json) {
    return LocalMessageOrderEntry(
      eventId: _string(json['event_id']),
      conversationId: _string(json['conversation_id']),
      conversationType: LocalOutboxConversationType.values.firstWhere(
        (type) => type.name == _string(json['conversation_type']),
        orElse: () => LocalOutboxConversationType.direct,
      ),
      createdAt: DateTime.tryParse(_string(json['created_at'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      batchId: _string(json['batch_id']),
      batchIndex: _int(json['batch_index']),
    );
  }

  final String eventId;
  final String conversationId;
  final LocalOutboxConversationType conversationType;
  final DateTime createdAt;
  final String batchId;
  final int batchIndex;

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'conversation_id': conversationId,
      'conversation_type': conversationType.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'batch_id': batchId,
      'batch_index': batchIndex,
    };
  }

  static String _string(Object? value) => value is String ? value : '';

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

abstract class LocalMessageOrderStore {
  Future<List<LocalMessageOrderEntry>> readAll();

  Future<void> upsert(LocalMessageOrderEntry entry);
}

class FileLocalMessageOrderStore implements LocalMessageOrderStore {
  const FileLocalMessageOrderStore(
    this.file, {
    this.maxEntries = 5000,
  });

  final File file;
  final int maxEntries;

  @override
  Future<List<LocalMessageOrderEntry>> readAll() async {
    if (!await file.exists()) return const [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const [];
      final json = jsonDecode(content);
      if (json is! List) return const [];
      return [
        for (final item in json)
          if (item is Map<String, dynamic>)
            _validOrNull(LocalMessageOrderEntry.fromJson(item)),
      ].whereType<LocalMessageOrderEntry>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> upsert(LocalMessageOrderEntry entry) async {
    final normalized = _validOrNull(entry);
    if (normalized == null) return;
    final current = await readAll();
    final next = [
      for (final existing in current)
        if (existing.eventId != normalized.eventId) existing,
      normalized,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final capped = next.length <= maxEntries
        ? next
        : next.sublist(next.length - maxEntries);
    await _write(capped);
  }

  LocalMessageOrderEntry? _validOrNull(LocalMessageOrderEntry entry) {
    if (entry.eventId.trim().isEmpty || entry.conversationId.trim().isEmpty) {
      return null;
    }
    return entry;
  }

  Future<void> _write(List<LocalMessageOrderEntry> entries) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final entry in entries) entry.toJson()]),
      flush: true,
    );
  }
}
