import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android native splash and Flutter splash overlay use the same image',
      () {
    final flutterSplash = File('assets/images/splash_launch.png');
    final androidSplash =
        File('android/app/src/main/res/drawable-nodpi/splash_launch.png');

    expect(flutterSplash.existsSync(), isTrue);
    expect(androidSplash.existsSync(), isTrue);
    expect(androidSplash.readAsBytesSync(), flutterSplash.readAsBytesSync());
  });
}
