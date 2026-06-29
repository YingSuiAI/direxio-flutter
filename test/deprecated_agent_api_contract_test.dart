import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removed apis product actions are not exposed by Flutter client', () {
    const paths = [
      'lib/data/http_as_client.dart',
      'test/http_as_client_test.dart',
    ];

    final offenders = <String>[];
    for (final path in paths) {
      final content = File(path).readAsStringSync();
      if (content.contains('apis.list') ||
          content.contains('apis.status') ||
          content.contains('apis/status') ||
          RegExp(r'\blistApiPermissions\s*\(').hasMatch(content) ||
          RegExp(r'\bupdateApiPermissionStatus\s*\(').hasMatch(content)) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty);
  });
}
