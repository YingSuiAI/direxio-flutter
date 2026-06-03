import 'dart:io';

import 'package:flutter/services.dart';

const chatFileActionsChannel = MethodChannel('p2p_im/file_actions');

Future<File> writeChatActionFile({
  required Directory directory,
  required String fileName,
  required List<int> bytes,
}) async {
  await directory.create(recursive: true);
  final safeName = sanitizeChatFileName(fileName);
  final file = await _availableFile(directory, safeName);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

String sanitizeChatFileName(String fileName) {
  final trimmed = fileName.trim();
  final fallback = trimmed.isEmpty ? 'file' : trimmed;
  final sanitized = fallback.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return sanitized.isEmpty ? 'file' : sanitized;
}

Future<File> _availableFile(Directory directory, String fileName) async {
  final first = File('${directory.path}/$fileName');
  if (!await first.exists()) return first;

  final dot = fileName.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < fileName.length - 1;
  final stem = hasExtension ? fileName.substring(0, dot) : fileName;
  final extension = hasExtension ? fileName.substring(dot) : '';
  for (var i = 1; i < 1000; i++) {
    final candidate = File('${directory.path}/$stem ($i)$extension');
    if (!await candidate.exists()) return candidate;
  }
  return File(
    '${directory.path}/$stem-${DateTime.now().microsecondsSinceEpoch}$extension',
  );
}

Future<void> previewChatActionFile(File file) {
  return chatFileActionsChannel.invokeMethod<void>(
    'previewFile',
    {'path': file.path},
  );
}
