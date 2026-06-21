class LocalEndpointResolver {
  const LocalEndpointResolver._(this._rules);

  /// Optional local development mapping.
  ///
  /// Format:
  /// `source_host[:source_port]=target_host:target_port,...`
  ///
  /// Example:
  /// `node.example:8448=127.0.0.1:18008`
  ///
  /// Production builds normally leave this empty, so no private development
  /// node names or ports are compiled into the app by default.
  static final LocalEndpointResolver environment = LocalEndpointResolver.parse(
    const String.fromEnvironment('DIREXIO_LOCAL_ENDPOINTS'),
  );

  static const empty = LocalEndpointResolver._(<_LocalEndpointRule>[]);

  final List<_LocalEndpointRule> _rules;

  static LocalEndpointResolver parse(String value) {
    final rules = <_LocalEndpointRule>[];
    for (final rawEntry in value.split(',')) {
      final entry = rawEntry.trim();
      if (entry.isEmpty) continue;
      final separator = entry.indexOf('=');
      if (separator <= 0 || separator + 1 >= entry.length) continue;
      final source = _parseSource(entry.substring(0, separator));
      final target = entry.substring(separator + 1).trim();
      if (source == null || target.isEmpty) continue;
      rules.add(_LocalEndpointRule(source.host, source.port, target));
    }
    if (rules.isEmpty) return empty;
    return LocalEndpointResolver._(List.unmodifiable(rules));
  }

  Uri? httpUriForServerName(String serverName, {String path = ''}) {
    final trimmed = serverName.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse('matrix://$trimmed');
    if (parsed == null || parsed.host.isEmpty) return null;
    return httpUriForHost(
      parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: path,
    );
  }

  Uri? httpUriForUri(Uri uri, {String path = ''}) {
    if (uri.host.isEmpty) return null;
    return httpUriForHost(
      uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  Uri? httpUriForHost(String host, {int? port, String path = ''}) {
    final normalized = _normalizeHost(host);
    if (normalized.isEmpty) return null;
    for (final rule in _rules) {
      if (!rule.matches(normalized, port)) continue;
      return _targetUri(rule.target, path: path);
    }
    return null;
  }

  static _EndpointSource? _parseSource(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse('matrix://$trimmed');
    if (parsed == null || parsed.host.isEmpty) return null;
    return _EndpointSource(
      _normalizeHost(parsed.host),
      parsed.hasPort ? parsed.port : null,
    );
  }

  static Uri? _targetUri(String value, {required String path}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final explicit = Uri.tryParse(trimmed);
    if (explicit != null && explicit.hasScheme && explicit.host.isNotEmpty) {
      return explicit.replace(path: path, query: '', fragment: '');
    }
    final portOnly = int.tryParse(trimmed);
    if (portOnly != null) {
      return Uri(scheme: 'http', host: '127.0.0.1', port: portOnly, path: path);
    }
    final parsed = Uri.tryParse('local://$trimmed');
    if (parsed == null || parsed.host.isEmpty) return null;
    return Uri(
      scheme: 'http',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: path,
    );
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}

class _EndpointSource {
  const _EndpointSource(this.host, this.port);

  final String host;
  final int? port;
}

class _LocalEndpointRule {
  const _LocalEndpointRule(this.host, this.port, this.target);

  final String host;
  final int? port;
  final String target;

  bool matches(String inputHost, int? inputPort) =>
      host == inputHost && (port == null || port == inputPort);
}
