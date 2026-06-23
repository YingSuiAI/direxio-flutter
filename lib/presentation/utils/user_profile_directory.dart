import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../providers/as_sync_cache_provider.dart';
import 'avatar_url.dart';
import 'contact_identity_label.dart';
import 'direct_contact_status.dart';

class UserProfileIdentity {
  const UserProfileIdentity({
    required this.userId,
    this.displayName = '',
    this.avatarUrl = '',
    this.domain = '',
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final String domain;

  String get resolvedName => contactDisplayNameFromIdentity(
        mxid: userId,
        displayName: displayName,
        domain: domain,
      );
}

class UserProfileDirectory {
  UserProfileDirectory._(this._entries);

  factory UserProfileDirectory.fromSources({
    required Client client,
    AsSyncCacheState syncCache = const AsSyncCacheState(),
    Iterable<AsConversation> productConversations = const [],
    Iterable<AsSyncContact> extraContacts = const [],
    Iterable<AsChannelMember> extraChannelMembers = const [],
    Profile? currentUserProfile,
  }) {
    final builder = _UserProfileDirectoryBuilder(client);
    for (final contact in syncCache.contacts) {
      builder.addContact(contact);
    }
    for (final contact in extraContacts) {
      builder.addContact(contact);
    }
    builder.addConversations(productConversations);
    for (final member in extraChannelMembers) {
      builder.addChannelMember(member);
    }
    builder.addMatrixRooms(client.rooms);
    builder.addCurrentUserProfile(currentUserProfile);
    return UserProfileDirectory._(builder.build());
  }

  final Map<String, UserProfileIdentity> _entries;

  Map<String, UserProfileIdentity> get byUserId => Map.unmodifiable(_entries);

  UserProfileIdentity resolve({
    required String userId,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
  }) {
    final normalizedUserId = userId.trim();
    final existing = _entries[normalizedUserId];
    return UserProfileIdentity(
      userId: normalizedUserId,
      displayName: _firstNonEmpty([existing?.displayName, displayName]),
      avatarUrl: _firstNonEmpty([existing?.avatarUrl, avatarUrl]),
      domain: _firstNonEmpty([existing?.domain, domain]),
    );
  }

  String displayNameFor(
    String userId, {
    String fallbackDisplayName = '',
    String fallbackDomain = '',
  }) {
    return resolve(
      userId: userId,
      displayName: fallbackDisplayName,
      domain: fallbackDomain,
    ).resolvedName;
  }

  String? avatarUrlFor(
    String userId, {
    String fallbackAvatarUrl = '',
  }) {
    final avatar = resolve(
      userId: userId,
      avatarUrl: fallbackAvatarUrl,
    ).avatarUrl.trim();
    return avatar.isEmpty ? null : avatar;
  }
}

class _UserProfileDirectoryBuilder {
  _UserProfileDirectoryBuilder(this.client);

  final Client client;
  final Map<String, _MutableUserProfileIdentity> _entries = {};

  Map<String, UserProfileIdentity> build() {
    return {
      for (final entry in _entries.entries)
        entry.key: UserProfileIdentity(
          userId: entry.key,
          displayName: entry.value.displayName,
          avatarUrl: entry.value.avatarUrl,
          domain: entry.value.domain,
        ),
    };
  }

  void addContact(AsSyncContact contact) {
    add(
      userId: contact.userId,
      displayName: _firstNonEmpty([contact.remark, contact.displayName]),
      avatarUrl: avatarHttpUrl(client, contact.avatarUrl),
      domain: contact.domain,
      displayNamePriority: 70,
      avatarPriority: 70,
      domainPriority: 70,
    );
  }

  void addConversations(Iterable<AsConversation> conversations) {
    for (final conversation in conversations) {
      if (!conversation.isDirect) continue;
      add(
        userId: conversation.peerMxid,
        displayName: conversation.title,
        avatarUrl: avatarHttpUrl(client, conversation.avatarUrl),
        displayNamePriority: 60,
        avatarPriority: 60,
      );
    }
  }

  void addChannelMember(AsChannelMember member) {
    add(
      userId: member.userMxid,
      displayName: member.displayName,
      avatarUrl: avatarHttpUrl(client, member.avatarUrl),
      domain: member.domain,
      displayNamePriority: 75,
      avatarPriority: 75,
      domainPriority: 75,
    );
  }

  void addCurrentUserProfile(Profile? profile) {
    final userId = profile?.userId.trim() ?? '';
    if (userId.isEmpty) return;
    add(
      userId: userId,
      displayName: profile?.displayName ?? '',
      avatarUrl: profileAvatarHttpUrl(profile, client),
      displayNamePriority: 100,
      avatarPriority: 100,
    );
  }

  void addMatrixRooms(Iterable<Room> rooms) {
    for (final room in rooms) {
      final nativePeer = productDirectPeerMxid(room);
      if (nativePeer != null && nativePeer.trim().isNotEmpty) {
        add(
          userId: nativePeer,
          displayName: productDirectPeerDisplayName(room) ?? '',
          avatarUrl: avatarHttpUrl(client, productDirectPeerAvatarUrl(room)),
          domain: productDirectPeerDomain(room) ?? '',
          displayNamePriority: 82,
          avatarPriority: 82,
          domainPriority: 82,
        );
      }
      final states = room.states[EventTypes.RoomMember]?.values ??
          const <StrippedStateEvent>[];
      for (final state in states) {
        final mxid = state.stateKey?.trim() ?? '';
        if (mxid.isEmpty) continue;
        final user = state.asUser(room);
        add(
          userId: mxid,
          displayName: user.displayName ?? '',
          avatarUrl: matrixContentHttpUrl(client, user.avatarUrl),
          displayNamePriority: 90,
          avatarPriority: 90,
        );
      }
    }
  }

  void add({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? domain,
    int displayNamePriority = 0,
    int avatarPriority = 0,
    int domainPriority = 0,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final entry = _entries.putIfAbsent(
      normalizedUserId,
      () => _MutableUserProfileIdentity(),
    );
    entry.merge(
      displayName: displayName,
      avatarUrl: avatarUrl,
      domain: domain,
      displayNamePriority: displayNamePriority,
      avatarPriority: avatarPriority,
      domainPriority: domainPriority,
    );
  }
}

class _MutableUserProfileIdentity {
  String displayName = '';
  String avatarUrl = '';
  String domain = '';
  int displayNamePriority = -1;
  int avatarPriority = -1;
  int domainPriority = -1;

  void merge({
    String? displayName,
    String? avatarUrl,
    String? domain,
    required int displayNamePriority,
    required int avatarPriority,
    required int domainPriority,
  }) {
    final nextDisplayName = displayName?.trim() ?? '';
    if (nextDisplayName.isNotEmpty &&
        displayNamePriority >= this.displayNamePriority) {
      this.displayName = nextDisplayName;
      this.displayNamePriority = displayNamePriority;
    }
    final nextAvatarUrl = avatarUrl?.trim() ?? '';
    if (nextAvatarUrl.isNotEmpty && avatarPriority >= this.avatarPriority) {
      this.avatarUrl = nextAvatarUrl;
      this.avatarPriority = avatarPriority;
    }
    final nextDomain = domain?.trim() ?? '';
    if (nextDomain.isNotEmpty && domainPriority >= this.domainPriority) {
      this.domain = nextDomain;
      this.domainPriority = domainPriority;
    }
  }
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
