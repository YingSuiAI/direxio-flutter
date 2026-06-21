const _localDevNodeAliasPorts = <String, int>{
  'dendrite-a': 18008,
  'dendrite-b': 28008,
  'dendrite-c': 38008,
};

const _localDevNodeFederationPorts = <int, int>{
  18448: 18008,
  28448: 28008,
  38448: 38008,
};

Uri? localDevNodeHttpUriForServerName(
  String serverName, {
  String path = '',
}) {
  final trimmed = serverName.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse('matrix://$trimmed');
  if (parsed == null || parsed.host.isEmpty) return null;
  return localDevNodeHttpUriForHost(
    parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: path,
  );
}

Uri? localDevNodeHttpUriForUri(Uri uri, {String path = ''}) {
  if (uri.host.isEmpty) return null;
  return localDevNodeHttpUriForHost(
    uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  );
}

Uri? localDevNodeHttpUriForHost(
  String host, {
  int? port,
  String path = '',
}) {
  final httpPort = localDevNodeHttpPortForHost(host, port: port);
  if (httpPort == null) return null;
  return Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: httpPort,
    path: path,
  );
}

int? localDevNodeHttpPortForHost(String host, {int? port}) {
  final normalized = host.trim().toLowerCase();
  final aliasPort = _localDevNodeAliasPorts[normalized];
  if (aliasPort != null) return aliasPort;
  if (normalized == 'host.docker.internal' && port != null) {
    return _localDevNodeFederationPorts[port];
  }
  return null;
}
