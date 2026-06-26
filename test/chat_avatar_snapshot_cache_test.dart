import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_avatar_snapshot_cache.dart';

void main() {
  test('keeps a resolved avatar when later candidates are temporarily missing',
      () {
    final cache = ChatAvatarSnapshotCache();

    final first = cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-alice.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );
    final second = cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [],
    );

    expect(first, 'https://matrix.example.com/member-alice.png');
    expect(second, first);
  });

  test('does not downgrade a member avatar to a lower priority fallback', () {
    final cache = ChatAvatarSnapshotCache();

    cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-alice.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );
    final resolved = cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://product.example.com/contact-alice.png',
          priority: ChatAvatarCandidatePriority.productContact,
        ),
      ],
    );

    expect(resolved, 'https://matrix.example.com/member-alice.png');
  });

  test('updates when the same priority source changes url', () {
    final cache = ChatAvatarSnapshotCache();

    cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-alice-v1.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );
    final resolved = cache.resolve(
      senderId: '@alice:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-alice-v2.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );

    expect(resolved, 'https://matrix.example.com/member-alice-v2.png');
  });

  test('updates when a higher priority profile avatar arrives', () {
    final cache = ChatAvatarSnapshotCache();

    cache.resolve(
      senderId: '@me:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-me.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );
    final resolved = cache.resolve(
      senderId: '@me:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/profile-me.png',
          priority: ChatAvatarCandidatePriority.currentUserProfile,
        ),
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/member-me.png',
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );

    expect(resolved, 'https://matrix.example.com/profile-me.png');
  });

  test('uses the current user profile for local outbox avatar resolution', () {
    final cache = ChatAvatarSnapshotCache();

    final resolved = cache.resolve(
      senderId: '@me:example.com',
      candidates: const [
        ChatAvatarCandidate(
          url: 'https://matrix.example.com/profile-me.png',
          priority: ChatAvatarCandidatePriority.currentUserProfile,
        ),
      ],
    );

    expect(resolved, 'https://matrix.example.com/profile-me.png');
  });
}
