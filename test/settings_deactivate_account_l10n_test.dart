import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/l10n/app_localizations_en.dart';
import 'package:portal_app/l10n/app_localizations_ja.dart';
import 'package:portal_app/l10n/app_localizations_zh.dart';

void main() {
  test('settings account deactivation copy is localized as account deletion',
      () {
    expect(AppLocalizationsZh().settingsDeactivateLogin, '注销账号');
    expect(AppLocalizationsZh().settingsDeactivateLoginConfirmTitle, '注销账号');

    expect(AppLocalizationsEn().settingsDeactivateLogin, 'Delete Account');
    expect(
      AppLocalizationsEn().settingsDeactivateLoginConfirmTitle,
      'Delete Account',
    );

    expect(AppLocalizationsJa().settingsDeactivateLogin, 'アカウントを削除');
    expect(
      AppLocalizationsJa().settingsDeactivateLoginConfirmTitle,
      'アカウントを削除',
    );
  });
}
