import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/pages/home_page.dart';

void main() {
  test('home bottom bar keeps a minimum bottom gap without system inset', () {
    expect(homeBottomBarEffectiveBottomInset(0), 12);
    expect(homeBottomBarEffectiveBottomInset(6), 12);
  });

  test('home bottom bar preserves larger system safe area inset', () {
    expect(homeBottomBarEffectiveBottomInset(34), 34);
  });
}
