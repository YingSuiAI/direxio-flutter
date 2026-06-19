bool looksLikeMatrixRoomId(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('!') && trimmed.contains(':');
}

Uri? publicBaseUriForMatrixRoomId(String value) {
  final trimmed = value.trim();
  if (!looksLikeMatrixRoomId(trimmed)) return null;
  final separator = trimmed.indexOf(':');
  if (separator < 0 || separator + 1 >= trimmed.length) return null;
  final serverName = trimmed.substring(separator + 1).trim();
  if (serverName.isEmpty) return null;
  return publicBaseUriForServerName(serverName);
}

Uri? publicBaseUriForServerName(String serverName) {
  final trimmed = serverName.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.host.isNotEmpty) {
    return parsed.replace(path: '/_p2p', query: '', fragment: '');
  }
  final hostAndPort = trimmed.split(':');
  final host = hostAndPort.first.trim();
  if (host.isEmpty) return null;
  final port = hostAndPort.length >= 2 ? int.tryParse(hostAndPort[1]) : null;
  final localDualNodeBaseUri = _localDualNodeBaseUri(host, port);
  if (localDualNodeBaseUri != null) return localDualNodeBaseUri;
  final localHost = host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.startsWith('192.168.') ||
      host.startsWith('10.');
  return Uri(
    scheme: localHost ? 'http' : 'https',
    host: host,
    port: port,
    path: '/_p2p',
  );
}

Uri? _localDualNodeBaseUri(String host, int? port) {
  final normalized = host.trim().toLowerCase();
  if (port != null && port != 8008 && port != 8448) return null;
  final hostPort = switch (normalized) {
    'dendrite-a' => 18008,
    'dendrite-b' => 28008,
    _ => null,
  };
  if (hostPort == null) return null;
  return Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: hostPort,
    path: '/_p2p',
  );
}
