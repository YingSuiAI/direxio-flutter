import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _direxioApnsChannel = MethodChannel('direxio/apns');

Future<String?> fetchDirexioIosApnsToken() async {
  if (kIsWeb || !Platform.isIOS) return null;
  final token = await _direxioApnsChannel.invokeMethod<String>('requestToken');
  final clean = token?.trim() ?? '';
  return clean.isEmpty ? null : clean;
}
