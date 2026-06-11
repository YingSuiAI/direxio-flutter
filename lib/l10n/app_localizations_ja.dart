// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'TokLink';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageDialogTitle => '言語';

  @override
  String get tabChats => 'チャット';

  @override
  String get tabContacts => '連絡先';

  @override
  String get tabChannels => 'チャンネル';

  @override
  String get tabMe => '自分';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGeneral => '一般設定';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsFollowSystem => 'システムに従う';

  @override
  String get settingsFavorites => 'お気に入り';

  @override
  String get settingsPrivacySecurity => 'プライバシーとセキュリティ';

  @override
  String get settingsBlacklist => '連絡先ブラックリスト';

  @override
  String get settingsMessagesNotifications => 'メッセージと通知';

  @override
  String get settingsDoNotDisturb => 'おやすみモード';

  @override
  String get settingsMessageSound => '新着メッセージ音';

  @override
  String get settingsMessageVibration => '新着メッセージの振動';

  @override
  String get settingsOther => 'その他';

  @override
  String get settingsAboutUs => '私たちについて';

  @override
  String get settingsClearChats => 'チャット履歴を消去';

  @override
  String get settingsLogout => 'ログアウト';

  @override
  String get settingsLogoutConfirmTitle => 'ログアウト';

  @override
  String get settingsLogoutConfirmMessage => 'ログアウトしてもよろしいですか？';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSearch => '検索';

  @override
  String get commonShare => '共有';

  @override
  String get addContactTitle => '友だちを追加';

  @override
  String get addContactEmptyHint => '相手のニックネームまたは Portal URL を入力して検索';

  @override
  String get addContactDomainNotProductUser => 'このドメインは製品ユーザーではありません';

  @override
  String get addContactMessageAfterAdding => '友だち追加後にメッセージを送信できます';

  @override
  String get addContactVoiceAfterAdding => '友だち追加後に音声通話できます';

  @override
  String get addContactVideoAfterAdding => '友だち追加後にビデオ通話できます';

  @override
  String get addContactRequestSent => '友だち申請を送信しました。承認を待っています。';

  @override
  String addContactRequestFailed(String error) {
    return '友だち申請の送信に失敗しました: $error';
  }

  @override
  String get contactSendMessage => 'メッセージ';

  @override
  String get contactVoiceCall => '音声通話';

  @override
  String get contactVideoCall => 'ビデオ通話';

  @override
  String get contactMuteMessages => '通知をミュート';

  @override
  String get contactBlockUser => 'ユーザーをブロック';

  @override
  String get contactReportUser => 'ユーザーを報告';

  @override
  String get contactReportTodo => '報告機能はまだ接続されていません';

  @override
  String get contactFriendRequested => '申請済み';

  @override
  String get contactApplyFriend => '友だち申請';

  @override
  String get qrInvalidFormat => '無効なQRコード形式です';

  @override
  String get qrInvalidUser => '無効なユーザーQRコードです';

  @override
  String get qrInvalidGroup => '無効なグループQRコードです';

  @override
  String get qrUnsupportedGroup => 'このグループQRコードはまだサポートされていません';

  @override
  String get qrScannerInstruction => 'QRコードを枠内に入れると自動でスキャンします';

  @override
  String get qrScannerSupportUsers => 'ユーザーQRコードのスキャンに対応しています';

  @override
  String get meQrTitle => '自分のQRコード';

  @override
  String get meQrHint => '上のQRコードをスキャンして友だちに追加できます。';

  @override
  String get meQrSaveToAlbum => '写真に保存';

  @override
  String get meQrSaveTodo => '写真への保存機能はまだ接続されていません';

  @override
  String get meQrUnconnectedDomain => '接続済みドメインなし';
}
