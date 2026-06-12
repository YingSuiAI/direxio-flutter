import 'dart:convert';

enum QrScanKind { user, group }

class QrScanTarget {
  const QrScanTarget.user({
    required this.userId,
    this.displayName,
  })  : kind = QrScanKind.user,
        groupId = null;

  const QrScanTarget.group({required this.groupId})
      : kind = QrScanKind.group,
        userId = null,
        displayName = null;

  final QrScanKind kind;
  final String? userId;
  final String? displayName;
  final String? groupId;
}

const _openImFriendScheme = 'https://io.openim.app/addFriend/';
const _openImGroupScheme = 'https://io.openim.app/joinGroup/';

QrScanTarget? parseQrScanTarget(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  final jsonTarget = _parseJsonQr(value);
  if (jsonTarget != null) return jsonTarget;

  final p2pTarget = _parseP2pQr(value);
  if (p2pTarget != null) return p2pTarget;

  final userId = _parseUserId(value);
  if (userId != null && userId.isNotEmpty) {
    return QrScanTarget.user(userId: userId);
  }

  final groupId = _parseGroupId(value);
  if (groupId != null && groupId.isNotEmpty) {
    return QrScanTarget.group(groupId: groupId);
  }

  return null;
}

QrScanTarget? _parseJsonQr(String value) {
  if (!value.startsWith('{')) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final kind = _firstString(decoded, const ['kind', 'type', 'action']);
  final mxid = _firstString(decoded, const [
    'mxid',
    'user_id',
    'userId',
    'matrix_user_id',
    'matrixUserId',
  ]);
  if (mxid != null &&
      (kind == null || kind.contains('user') || kind.contains('contact'))) {
    return QrScanTarget.user(
      userId: mxid,
      displayName: _firstString(
        decoded,
        const ['display_name', 'displayName', 'name'],
      ),
    );
  }
  final groupId = _firstString(decoded, const [
    'room_id',
    'roomId',
    'group_id',
    'groupId',
  ]);
  if (groupId != null &&
      (kind == null || kind.contains('group') || kind.contains('room'))) {
    return QrScanTarget.group(groupId: groupId);
  }
  return null;
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

QrScanTarget? _parseP2pQr(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'p2pim') return _parseUniversalUri(uri, value);

  if (uri.host == 'add-contact' || uri.host == 'user') {
    final mxid = _queryParam(uri, const ['mxid', 'user_id', 'userId']);
    if (mxid == null || mxid.isEmpty) return null;
    return QrScanTarget.user(
      userId: mxid,
      displayName:
          _queryParam(uri, const ['name', 'display_name', 'displayName']),
    );
  }

  if (uri.host == 'group') {
    final groupId = uri.queryParameters['room_id']?.trim() ??
        uri.queryParameters['group_id']?.trim();
    if (groupId == null || groupId.isEmpty) return null;
    return QrScanTarget.group(groupId: groupId);
  }

  return null;
}

QrScanTarget? _parseUniversalUri(Uri uri, String rawValue) {
  final mxid = _queryParam(uri, const [
    'mxid',
    'user_id',
    'userId',
    'matrix_user_id',
    'matrixUserId',
  ]);
  if (mxid != null) {
    return QrScanTarget.user(
      userId: mxid,
      displayName:
          _queryParam(uri, const ['name', 'display_name', 'displayName']),
    );
  }

  final groupId = _queryParam(uri, const [
    'room_id',
    'roomId',
    'group_id',
    'groupId',
  ]);
  if (groupId != null) return QrScanTarget.group(groupId: groupId);

  if (uri.host == 'matrix.to' && uri.fragment.isNotEmpty) {
    final fragment = Uri.decodeComponent(
      uri.fragment.startsWith('/') ? uri.fragment.substring(1) : uri.fragment,
    );
    if (fragment.startsWith('@')) return QrScanTarget.user(userId: fragment);
    if (fragment.startsWith('!') || fragment.startsWith('#')) {
      return QrScanTarget.group(groupId: fragment);
    }
  }

  final mxidMatch = RegExp(r'@[^/?#\s]+:[^/?#\s]+').firstMatch(rawValue);
  if (mxidMatch != null) return QrScanTarget.user(userId: mxidMatch.group(0)!);

  final roomMatch = RegExp(r'![^/?#\s]+:[^/?#\s]+').firstMatch(rawValue);
  if (roomMatch != null) {
    return QrScanTarget.group(groupId: roomMatch.group(0)!);
  }

  return null;
}

String? _queryParam(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _parseUserId(String value) {
  if (value.contains(_openImFriendScheme)) {
    final index = value.indexOf(_openImFriendScheme);
    return value.substring(index + _openImFriendScheme.length).trim();
  }

  final openImUri = Uri.tryParse(value);
  if (openImUri != null &&
      openImUri.scheme == 'openim' &&
      openImUri.host == 'addFriend') {
    return openImUri.pathSegments.isEmpty
        ? null
        : openImUri.pathSegments.first.trim();
  }

  final addFriendMatch = RegExp(r'/addFriend/([^/?#]+)').firstMatch(value);
  if (addFriendMatch != null) return addFriendMatch.group(1)?.trim();

  if (RegExp(r'^@[^:\s]+:[^:\s]+$').hasMatch(value)) return value;

  if (RegExp(r'^\d+$').hasMatch(value)) return value;

  return null;
}

String? _parseGroupId(String value) {
  if (value.contains(_openImGroupScheme)) {
    final index = value.indexOf(_openImGroupScheme);
    return value.substring(index + _openImGroupScheme.length).trim();
  }

  final openImUri = Uri.tryParse(value);
  if (openImUri != null &&
      openImUri.scheme == 'openim' &&
      openImUri.host == 'joinGroup') {
    return openImUri.pathSegments.isEmpty
        ? null
        : openImUri.pathSegments.first.trim();
  }

  final joinGroupMatch = RegExp(r'/joinGroup/([^/?#]+)').firstMatch(value);
  return joinGroupMatch?.group(1)?.trim();
}
