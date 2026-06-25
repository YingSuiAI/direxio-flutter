import 'dart:convert';

import 'package:crypto/crypto.dart';

const defaultImPublicBaseUrl = 'https://imadmin.direxio.ai/api';
const defaultImPublicSecret = 'f88c10fe-4559-fa77-b8b9-beadf468ddba';

String buildImPublicNonce({String seed = ''}) {
  final suffix = seed.trim().isEmpty ? '' : '-${seed.hashCode.toUnsigned(32)}';
  return '${DateTime.now().microsecondsSinceEpoch}$suffix';
}

Map<String, String> signedImPublicHeaders({
  required String secret,
  required String canonicalBody,
  String? nonce,
  Map<String, String> headers = const {},
}) {
  final cleanSecret = secret.trim();
  final cleanNonce =
      nonce?.trim().isNotEmpty == true ? nonce!.trim() : buildImPublicNonce();
  return {
    ...headers,
    'X-BI-Nonce': cleanNonce,
    'X-BI-Signature': buildImPublicSignature(
      secret: cleanSecret,
      nonce: cleanNonce,
      canonicalBody: canonicalBody,
    ),
  };
}

String buildImPublicSignature({
  required String secret,
  required String nonce,
  required String canonicalBody,
}) {
  final input = '${secret.trim()}\n$nonce\n$canonicalBody';
  return md5.convert(utf8.encode(input)).toString();
}

String canonicalImPublicJson(Object? value) {
  if (value is Map) {
    final entries = value.entries
        .where((entry) => entry.key != null)
        .map((entry) => MapEntry(entry.key.toString(), entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) {
      return '${jsonEncode(entry.key)}:${canonicalImPublicJson(entry.value)}';
    }).join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(canonicalImPublicJson).join(',')}]';
  }
  return jsonEncode(value);
}
