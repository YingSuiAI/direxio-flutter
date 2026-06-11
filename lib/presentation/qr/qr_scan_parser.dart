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

QrScanTarget? _parseP2pQr(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'p2pim') return null;

  if (uri.host == 'add-contact' || uri.host == 'user') {
    final mxid = uri.queryParameters['mxid']?.trim();
    if (mxid == null || mxid.isEmpty) return null;
    return QrScanTarget.user(
      userId: mxid,
      displayName: uri.queryParameters['name']?.trim(),
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

String? _parseUserId(String value) {
  if (value.contains(_openImFriendScheme)) {
    final index = value.indexOf(_openImFriendScheme);
    return value.substring(index + _openImFriendScheme.length).trim();
  }

  final openImUri = Uri.tryParse(value);
  if (openImUri != null &&
      openImUri.scheme == 'openim' &&
      openImUri.path.startsWith('/addFriend/')) {
    return openImUri.path.substring('/addFriend/'.length).trim();
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
      openImUri.path.startsWith('/joinGroup/')) {
    return openImUri.path.substring('/joinGroup/'.length).trim();
  }

  final joinGroupMatch = RegExp(r'/joinGroup/([^/?#]+)').firstMatch(value);
  return joinGroupMatch?.group(1)?.trim();
}
