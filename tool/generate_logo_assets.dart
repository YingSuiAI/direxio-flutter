import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final root = Directory.current.path;
  final logoFile = File('$root/assets/images/logo.png');
  final source = img.decodePng(logoFile.readAsBytesSync());
  if (source == null) {
    throw StateError('Unable to decode ${logoFile.path}');
  }

  final squareLogo = _extendTransparentCorners(source);

  const androidIcons = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  const iosIcons = {
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
        167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
        1024,
  };

  for (final entry in {...androidIcons, ...iosIcons}.entries) {
    _writeResizedPng(
      squareLogo,
      '$root/${entry.key}',
      entry.value,
      removeAlpha: true,
    );
  }

  final splash = _makeSplash(source, width: 1125, height: 2436);
  final splashTargets = [
    'assets/images/splash_launch.png',
    'android/app/src/main/res/drawable-nodpi/splash_launch.png',
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png',
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
  ];
  for (final path in splashTargets) {
    _writePng('$root/$path', splash);
  }
}

img.Image _extendTransparentCorners(img.Image source) {
  final output = img.Image(width: source.width, height: source.height);
  final centerY = source.height ~/ 2;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      if (pixel.a > 250) {
        output.setPixel(x, y, pixel);
        continue;
      }
      final fallback = _nearestOpaqueInColumn(source, x, y) ??
          _nearestOpaqueInRow(source, x, centerY) ??
          source.getPixel(source.width ~/ 2, centerY);
      output.setPixelRgba(x, y, fallback.r, fallback.g, fallback.b, 255);
    }
  }
  return output;
}

img.Pixel? _nearestOpaqueInColumn(img.Image image, int x, int y) {
  for (var delta = 0; delta < image.height; delta++) {
    final up = y - delta;
    if (up >= 0) {
      final pixel = image.getPixel(x, up);
      if (pixel.a > 250) return pixel;
    }
    final down = y + delta;
    if (down < image.height) {
      final pixel = image.getPixel(x, down);
      if (pixel.a > 250) return pixel;
    }
  }
  return null;
}

img.Pixel? _nearestOpaqueInRow(img.Image image, int x, int y) {
  for (var delta = 0; delta < image.width; delta++) {
    final left = x - delta;
    if (left >= 0) {
      final pixel = image.getPixel(left, y);
      if (pixel.a > 250) return pixel;
    }
    final right = x + delta;
    if (right < image.width) {
      final pixel = image.getPixel(right, y);
      if (pixel.a > 250) return pixel;
    }
  }
  return null;
}

img.Image _makeSplash(img.Image logo,
    {required int width, required int height}) {
  final splash = img.Image(width: width, height: height);
  img.fill(splash, color: img.ColorRgb8(20, 24, 29));
  final logoSize = math.min(288, (width * 0.26).round());
  final resizedLogo = img.copyResize(
    logo,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    splash,
    resizedLogo,
    dstX: (width - logoSize) ~/ 2,
    dstY: (height - logoSize) ~/ 2,
  );
  return splash;
}

void _writeResizedPng(
  img.Image image,
  String path,
  int size, {
  required bool removeAlpha,
}) {
  final resized = img.copyResize(
    image,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  _writePng(path, removeAlpha ? _withoutAlpha(resized) : resized);
}

img.Image _withoutAlpha(img.Image source) {
  final output = img.Image(width: source.width, height: source.height);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      output.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
    }
  }
  return output;
}

void _writePng(String path, img.Image image) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image, level: 9));
  stdout.writeln('wrote $path');
}
