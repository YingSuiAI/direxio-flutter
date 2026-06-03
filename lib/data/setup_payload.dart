class SetupPayload {
  const SetupPayload({required this.server, required this.code});

  final Uri server;
  final String code;

  static final _setupCodePattern = RegExp(r'^[a-z0-9]{8}$');

  static SetupPayload parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'p2pim' || uri.host != 'setup') {
      throw const FormatException('不是有效的 P2P IM 设置二维码');
    }

    final serverRaw = uri.queryParameters['server']?.trim() ?? '';
    final code = uri.queryParameters['code']?.trim() ?? '';
    final server = Uri.tryParse(serverRaw);
    if (server == null || server.scheme != 'https' || server.host.isEmpty) {
      throw const FormatException('设置二维码缺少有效的 HTTPS Portal 地址');
    }
    if (!_setupCodePattern.hasMatch(code)) {
      throw const FormatException('设置二维码缺少有效的一次性设置码');
    }

    return SetupPayload(server: server, code: code);
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
      throw const FormatException('请输入 8 位一次性设置码');
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
        'code': code,
      },
    ).toString();
  }
}
