import '../../data/local_endpoint_resolver.dart';

bool looksLikeMatrixRoomId(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('!') && trimmed.contains(':');
}

Uri? publicBaseUriForMatrixRoomId(
  String value, {
  LocalEndpointResolver? localEndpointResolver,
}) {
  final trimmed = value.trim();
  if (!looksLikeMatrixRoomId(trimmed)) return null;
  final separator = trimmed.indexOf(':');
  if (separator < 0 || separator + 1 >= trimmed.length) return null;
  final serverName = trimmed.substring(separator + 1).trim();
  if (serverName.isEmpty) return null;
  return publicBaseUriForServerName(
    serverName,
    localEndpointResolver: localEndpointResolver,
  );
}

Uri? publicBaseUriForServerName(
  String serverName, {
  LocalEndpointResolver? localEndpointResolver,
}) {
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
  final localEndpointBaseUri =
      (localEndpointResolver ?? LocalEndpointResolver.environment)
          .httpUriForHost(host, port: port, path: '/_p2p');
  if (localEndpointBaseUri != null) return localEndpointBaseUri;
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
