class LocalLoginDomainHint {
  const LocalLoginDomainHint({
    required this.recommendedAuthority,
  });

  final String recommendedAuthority;
}

const Map<int, String> _localThreeNodePortalAuthorities = {
  18008: 'host.docker.internal:18448',
  28008: 'host.docker.internal:28448',
  38008: 'host.docker.internal:38448',
};

LocalLoginDomainHint? localLoginDomainHintFor(String value) {
  final uri = _parseAuthority(value);
  if (uri == null || !_isLoopbackHost(uri.host) || !uri.hasPort) {
    return null;
  }
  final recommended = _localThreeNodePortalAuthorities[uri.port];
  if (recommended == null) return null;
  return LocalLoginDomainHint(recommendedAuthority: recommended);
}

Uri? _parseAuthority(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
  final candidate = hasScheme ? trimmed : 'matrix://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}

bool _isLoopbackHost(String host) {
  final normalized = host.trim().toLowerCase();
  return normalized == '127.0.0.1' ||
      normalized == 'localhost' ||
      normalized == '::1';
}
