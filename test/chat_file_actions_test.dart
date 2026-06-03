import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/chat_file_actions.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chat-file-actions-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('writes selected chat file with a safe filename', () async {
    final file = await writeChatActionFile(
      directory: tempDir,
      fileName: ' bad/name?.txt ',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(file.path.endsWith('/bad_name_.txt'), isTrue);
    expect(await file.readAsBytes(), [1, 2, 3]);
  });

  test('keeps existing local files by choosing a unique name', () async {
    await File('${tempDir.path}/report.pdf').writeAsString('old');

    final file = await writeChatActionFile(
      directory: tempDir,
      fileName: 'report.pdf',
      bytes: Uint8List.fromList([4]),
    );

    expect(file.path.endsWith('/report (1).pdf'), isTrue);
    expect(await file.readAsBytes(), [4]);
    expect(await File('${tempDir.path}/report.pdf').readAsString(), 'old');
  });
}
