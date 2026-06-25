import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native splash assets and Flutter splash overlay use the same image',
      () {
    final flutterSplash = File('assets/images/splash_launch.png');
    final androidSplash =
        File('android/app/src/main/res/drawable-nodpi/splash_launch.png');
    final iosSplash =
        File('ios/Runner/Assets.xcassets/LaunchImage.imageset/启动页.png');

    expect(flutterSplash.existsSync(), isTrue);
    expect(androidSplash.existsSync(), isTrue);
    expect(iosSplash.existsSync(), isTrue);
    expect(androidSplash.readAsBytesSync(), flutterSplash.readAsBytesSync());
    expect(iosSplash.readAsBytesSync(), flutterSplash.readAsBytesSync());
  });
}
