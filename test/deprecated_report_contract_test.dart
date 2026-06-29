import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P2P report submit contract is not exposed by Flutter client', () {
    const paths = [
      'lib/data/as_client.dart',
      'lib/data/http_as_client.dart',
      'test/http_as_client_test.dart',
      'test/support/mock_as_client.dart',
      'test/widget_test.dart',
    ];

    final offenders = <String>[];
    for (final path in paths) {
      final content = File(path).readAsStringSync();
      if (content.contains('reports.submit') ||
          RegExp(r'\bsubmitReport\s*\(').hasMatch(content) ||
          RegExp(r'\bsubmitReport\s*\{').hasMatch(content)) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty);
  });
}
