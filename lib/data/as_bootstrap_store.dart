import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'as_client.dart';

typedef AsBootstrapLoader = Future<AsSyncBootstrap> Function();

abstract class AsBootstrapStore {
  Future<AsSyncBootstrap?> read();

  Future<void> write(AsSyncBootstrap bootstrap);

  Future<void> clear();
}

class DeferredAsBootstrapStore implements AsBootstrapStore {
  const DeferredAsBootstrapStore(this._load);

  final Future<AsBootstrapStore> Function() _load;

  @override
  Future<AsSyncBootstrap?> read() async => (await _load()).read();

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    await (await _load()).write(bootstrap);
  }

  @override
  Future<void> clear() async => (await _load()).clear();
}

class FileAsBootstrapStore implements AsBootstrapStore {
  const FileAsBootstrapStore(this.file);

  final File file;

  @override
  Future<AsSyncBootstrap?> read() async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return AsSyncBootstrap.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(bootstrap.toJson()), flush: true);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class AsBootstrapRepository {
  AsBootstrapRepository({
    required AsBootstrapLoader loadBootstrap,
    required AsBootstrapStore store,
  })  : _loadBootstrap = loadBootstrap,
        _store = store;

  final AsBootstrapLoader _loadBootstrap;
  final AsBootstrapStore _store;
  Future<AsSyncBootstrap>? _inFlight;

  Future<AsSyncBootstrap?> readCached() => _store.read();

  Future<AsSyncBootstrap> refresh() {
    final current = _inFlight;
    if (current != null) return current;
    late final Future<AsSyncBootstrap> next;
    next = _loadAndPersist().whenComplete(() {
      if (identical(_inFlight, next)) {
        _inFlight = null;
      }
    });
    _inFlight = next;
    return next;
  }

  Future<AsSyncBootstrap> _loadAndPersist() async {
    final bootstrap = await _loadBootstrap();
    unawaited(_persist(bootstrap));
    return bootstrap;
  }

  Future<void> _persist(AsSyncBootstrap bootstrap) async {
    try {
      await _store.write(bootstrap);
    } catch (_) {
      // Cache persistence is an optimization. A failed local write must not
      // make fresh P2P metadata unavailable to the UI.
    }
  }
}
