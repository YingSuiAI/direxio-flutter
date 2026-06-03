import '../utils/contact_identity_label.dart';

String voiceCallPeerDisplayName({
  String? peerMxid,
  String contactDisplayName = '',
  String contactDomain = '',
  String? routeDisplayName,
  String? statePeerName,
  String? roomDisplayName,
}) {
  final mxid = peerMxid?.trim() ?? '';
  final fromContact = contactDisplayNameFromIdentity(
    mxid: mxid,
    displayName: contactDisplayName,
    domain: contactDomain,
  );
  if (_isStrongCallName(fromContact)) return fromContact;

  for (final value in [routeDisplayName, statePeerName, roomDisplayName]) {
    final trimmed = value?.trim() ?? '';
    if (_isStrongCallName(trimmed)) return trimmed;
  }

  final domain = contactDomain.trim().isNotEmpty
      ? contactDomain.trim()
      : domainFromMxid(mxid);
  if (domain.isNotEmpty) return domain;

  final localpart = localpartFromMxid(mxid);
  if (localpart.isNotEmpty) return localpart;

  return '对方';
}

bool _isStrongCallName(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized == 'owner') return false;
  if (normalized.startsWith('group with ')) return false;
  return true;
}
