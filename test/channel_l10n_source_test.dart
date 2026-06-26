import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel pages do not keep hardcoded visible Chinese copy', () {
    final files = [
      File('lib/presentation/channel/channel_home_tab.dart'),
      File('lib/presentation/pages/channel_page.dart'),
    ];

    const forbidden = [
      '正在同步频道',
      '请稍候',
      '我的频道',
      '我创建',
      '暂无我创建的频道',
      '暂无已加入频道',
      '创建的频道会显示在这里',
      '加入的频道会显示在这里',
      '频道正在同步，请稍后重试',
      '文字',
      '帖子',
      '取消置顶',
      '置顶',
      '已取消置顶',
      '已置顶',
      '不显示',
      '已隐藏',
      '删除频道',
      '已删除',
      '频道已经解散',
      '用户',
      '昨天',
      '周一',
    ];

    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final text in forbidden) {
        if (source.contains(text)) {
          offenders.add('${file.path}: $text');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
