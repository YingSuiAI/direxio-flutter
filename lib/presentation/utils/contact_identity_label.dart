String contactDisplayNameFromIdentity({
  required String mxid,
  String displayName = '',
  String domain = '',
  String fallback = '',
}) {
  final trimmedName = displayName.trim();
  if (trimmedName.isNotEmpty) return trimmedName;

  final localpart = localpartFromMxid(mxid);
  if (localpart.isNotEmpty) return localpart;

  final trimmedFallback = fallback.trim();
  if (trimmedFallback.isNotEmpty) return trimmedFallback;

  final trimmedDomain = domain.trim();
  if (trimmedDomain.isNotEmpty) return trimmedDomain;

  return trimmedName;
}

String localpartFromMxid(String mxid) {
  final trimmed = mxid.trim();
  final separator = trimmed.indexOf(':');
  if (trimmed.startsWith('@') && separator > 1) {
    return trimmed.substring(1, separator);
  }
  return trimmed;
}

String domainFromMxid(String mxid) {
  final trimmed = mxid.trim();
  final separator = trimmed.indexOf(':');
  if (trimmed.startsWith('@') &&
      separator > 1 &&
      separator < trimmed.length - 1) {
    return trimmed.substring(separator + 1);
  }
  return '';
}
