import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production app sources do not ship removed placeholder mock data', () {
    final forbidden = <String>[
      '吴世伟',
      '林佩瑜',
      '@wushiwei',
      '@linpeiyu',
      'Alice',
      '我正在考虑接受它！！',
      '用自己的节点，连接重要的人和内容。',
      'P2P IM 频道',
      '产品进展、节点部署和去中心化 IM 实验记录',
      'Niki',
      'Alex Chen',
      'Mina',
      'Bot Monitor',
      '@ray',
      'node sync note',
      'external link',
      'repeated advertising',
      '重复广告',
      '外部リンク',
      '重複広告',
    ];

    final productionFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
            (file) => file.path.endsWith('.dart') || file.path.endsWith('.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final matches = <String>[];
    for (final file in productionFiles) {
      final text = file.readAsStringSync();
      for (final token in forbidden) {
        if (text.contains(token)) {
          matches.add('${file.path}: $token');
        }
      }
    }

    expect(matches, isEmpty, reason: matches.join('\n'));
  });
}
