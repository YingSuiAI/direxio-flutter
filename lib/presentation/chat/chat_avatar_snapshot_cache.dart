import 'package:flutter/foundation.dart';

@immutable
class ChatAvatarCandidate {
  const ChatAvatarCandidate({
    required this.url,
    required this.priority,
  });

  final String? url;
  final int priority;
}

abstract final class ChatAvatarCandidatePriority {
  static const int productContact = 10;
  static const int matrixMember = 20;
  static const int currentUserProfile = 30;
}

class ChatAvatarSnapshotCache {
  final _snapshots = <String, _ChatAvatarSnapshot>{};

  String? resolve({
    required String senderId,
    required List<ChatAvatarCandidate> candidates,
  }) {
    final key = senderId.trim();
    final next = _bestCandidate(candidates);
    if (key.isEmpty) return next?.url;

    final current = _snapshots[key];
    if (current == null) {
      if (next != null) _snapshots[key] = next;
      return next?.url;
    }

    if (next == null) return current.url;
    if (next.priority >= current.priority && next.url != current.url) {
      _snapshots[key] = next;
      return next.url;
    }
    return current.url;
  }

  void clear() => _snapshots.clear();

  _ChatAvatarSnapshot? _bestCandidate(List<ChatAvatarCandidate> candidates) {
    _ChatAvatarSnapshot? best;
    for (final candidate in candidates) {
      final url = candidate.url?.trim();
      if (url == null || url.isEmpty) continue;
      final snapshot = _ChatAvatarSnapshot(
        url: url,
        priority: candidate.priority,
      );
      if (best == null || snapshot.priority > best.priority) {
        best = snapshot;
      }
    }
    return best;
  }
}

@immutable
class _ChatAvatarSnapshot {
  const _ChatAvatarSnapshot({
    required this.url,
    required this.priority,
  });

  final String url;
  final int priority;
}
