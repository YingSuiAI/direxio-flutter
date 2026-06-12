import 'dart:convert';

class SetupPayload {
  const SetupPayload({required this.server, required this.code});

  final Uri server;
  final String code;

  static final _setupCodePattern = RegExp(r'^[a-z0-9]{8}$');
  bool get hasCode => _setupCodePattern.hasMatch(code);

  static bool isValidSetupCode(String code) {
    return _setupCodePattern.hasMatch(code.trim());
  }

  static SetupPayload parse(String raw) {
    final value = raw.trim();
    final jsonPayload = _parseJson(value);
    if (jsonPayload != null) return jsonPayload;

    final uri = Uri.tryParse(value);
    if (uri == null) {
      throw const FormatException('不是有效的 P2P IM 设置二维码');
    }
    if (uri.scheme != 'p2pim' || uri.host != 'setup') {
      final queryPayload = _parseQueryUri(uri);
      if (queryPayload != null) return queryPayload;
      throw const FormatException('不是有效的 P2P IM 设置二维码');
    }

    return _fromRaw(
      serverRaw: uri.queryParameters['server']?.trim() ?? '',
      code: uri.queryParameters['code']?.trim() ?? '',
      allowMissingCode: true,
    );
  }

  static SetupPayload parseManual({
    required String portalOrDeepLink,
    required String code,
  }) {
    final raw = portalOrDeepLink.trim();
    if (raw.startsWith('p2pim://')) {
      return parse(raw);
    }

    final cleanCode = code.trim();
    if (!_setupCodePattern.hasMatch(cleanCode)) {
      throw const FormatException('请输入 8 位设置码');
    }

    var serverRaw = raw;
    if (serverRaw.isEmpty) {
      throw const FormatException('请输入 Portal URL');
    }
    if (!serverRaw.contains('://')) {
      serverRaw = 'https://$serverRaw';
    }

    final parsed = Uri.tryParse(serverRaw);
    if (parsed == null || parsed.host.isEmpty || parsed.scheme != 'https') {
      throw const FormatException('Portal URL 必须是有效的 HTTPS 地址');
    }

    final server = parsed.hasPort
        ? Uri(scheme: 'https', host: parsed.host, port: parsed.port)
        : Uri(scheme: 'https', host: parsed.host);
    return SetupPayload(server: server, code: cleanCode);
  }

  String toDeepLink() {
    return Uri(
      scheme: 'p2pim',
      host: 'setup',
      queryParameters: {
        'server': server.toString(),
        if (hasCode) 'code': code,
      },
    ).toString();
  }
}

SetupPayload? _parseJson(String value) {
  if (!value.startsWith('{')) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final serverRaw = _firstString(decoded, const [
    'server',
    'portal',
    'portal_url',
    'portalUrl',
    'homeserver',
    'homeserver_url',
  ]);
  final code = _firstString(decoded, const ['code', 'setup_code', 'setupCode']);
  return _fromRaw(
    serverRaw: serverRaw ?? '',
    code: code ?? '',
    allowMissingCode: true,
  );
}

SetupPayload? _parseQueryUri(Uri uri) {
  final code = _queryParam(uri, const ['code', 'setup_code', 'setupCode']);
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (code == null && uri.scheme == 'https' && path == '/setup') {
    return _fromRaw(
      serverRaw: _serverUriFromHttpsUri(uri).toString(),
      code: '',
      allowMissingCode: true,
    );
  }
  if (code == null) return null;
  final serverRaw = _queryParam(uri, const [
        'server',
        'portal',
        'portal_url',
        'portalUrl',
        'homeserver',
        'homeserver_url',
      ]) ??
      _serverUriFromHttpsUri(uri).toString();
  return _fromRaw(serverRaw: serverRaw, code: code);
}

Uri _serverUriFromHttpsUri(Uri uri) {
  return uri.hasPort
      ? Uri(scheme: 'https', host: uri.host, port: uri.port)
      : Uri(scheme: 'https', host: uri.host);
}

SetupPayload _fromRaw({
  required String serverRaw,
  required String code,
  bool allowMissingCode = false,
}) {
  final server = Uri.tryParse(serverRaw);
  if (server == null || server.scheme != 'https' || server.host.isEmpty) {
    throw const FormatException('设置二维码缺少有效的 HTTPS Portal 地址');
  }
  if (code.isEmpty && !allowMissingCode) {
    throw const FormatException('设置二维码缺少有效的设置码');
  }
  if (code.isNotEmpty && !SetupPayload._setupCodePattern.hasMatch(code)) {
    throw const FormatException('设置二维码缺少有效的设置码');
  }
  final cleanServer = server.hasPort
      ? Uri(scheme: 'https', host: server.host, port: server.port)
      : Uri(scheme: 'https', host: server.host);
  return SetupPayload(server: cleanServer, code: code);
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
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
