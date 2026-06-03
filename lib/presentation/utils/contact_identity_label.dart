String contactDisplayNameFromIdentity({
  required String mxid,
  String displayName = '',
  String domain = '',
  String fallback = '',
}) {
  final trimmedName = displayName.trim();
  if (trimmedName.isNotEmpty &&
      !_isPortalDomainLabel(trimmedName, mxid: mxid, domain: domain)) {
    return trimmedName;
  }

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

bool _isPortalDomainLabel(
  String value, {
  required String mxid,
  required String domain,
}) {
  final normalizedValue = _normalizeIdentityToken(value);
  if (normalizedValue.isEmpty) return false;

  final normalizedDomain = _normalizeIdentityToken(domain);
  if (normalizedDomain.isNotEmpty && normalizedValue == normalizedDomain) {
    return true;
  }

  final mxidDomain = _normalizeIdentityToken(domainFromMxid(mxid));
  return mxidDomain.isNotEmpty && normalizedValue == mxidDomain;
}

String _normalizeIdentityToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'/+$'), '');
}
