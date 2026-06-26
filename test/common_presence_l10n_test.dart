import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/l10n/app_localizations_en.dart';
import 'package:portal_app/l10n/app_localizations_ja.dart';
import 'package:portal_app/l10n/app_localizations_zh.dart';

void main() {
  test('online and offline labels are localized', () {
    expect(AppLocalizationsZh().commonOnline, '在线');
    expect(AppLocalizationsZh().commonOffline, '离线');

    expect(AppLocalizationsEn().commonOnline, 'Online');
    expect(AppLocalizationsEn().commonOffline, 'Offline');

    expect(AppLocalizationsJa().commonOnline, 'オンライン');
    expect(AppLocalizationsJa().commonOffline, 'オフライン');
  });
}
