// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TokLink';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageDialogTitle => 'Language';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabChannels => 'Channels';

  @override
  String get tabMe => 'Me';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsFollowSystem => 'Follow system';

  @override
  String get settingsFavorites => 'Favorites';

  @override
  String get settingsPrivacySecurity => 'Privacy & Security';

  @override
  String get settingsBlacklist => 'Blocked Contacts';

  @override
  String get settingsMessagesNotifications => 'Messages & Notifications';

  @override
  String get settingsDoNotDisturb => 'Do Not Disturb';

  @override
  String get settingsMessageSound => 'New Message Sound';

  @override
  String get settingsMessageVibration => 'New Message Vibration';

  @override
  String get settingsOther => 'Other';

  @override
  String get settingsAboutUs => 'About Us';

  @override
  String get settingsClearChats => 'Clear Chat History';

  @override
  String get settingsLogout => 'Log Out';

  @override
  String get settingsLogoutConfirmTitle => 'Log Out';

  @override
  String get settingsLogoutConfirmMessage =>
      'Are you sure you want to log out?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonShare => 'Share';

  @override
  String get addContactTitle => 'Add Friend';

  @override
  String get addContactEmptyHint => 'Enter a nickname or Portal URL to search';

  @override
  String get addContactDomainNotProductUser =>
      'This domain is not a product user';

  @override
  String get addContactMessageAfterAdding =>
      'Add this friend before sending messages';

  @override
  String get addContactVoiceAfterAdding =>
      'Add this friend before starting an audio call';

  @override
  String get addContactVideoAfterAdding =>
      'Add this friend before starting a video call';

  @override
  String get addContactRequestSent =>
      'Friend request sent. Waiting for acceptance.';

  @override
  String addContactRequestFailed(String error) {
    return 'Failed to send friend request: $error';
  }

  @override
  String get contactSendMessage => 'Message';

  @override
  String get contactVoiceCall => 'Audio Call';

  @override
  String get contactVideoCall => 'Video Call';

  @override
  String get contactMuteMessages => 'Mute Messages';

  @override
  String get contactBlockUser => 'Block User';

  @override
  String get contactReportUser => 'Report User';

  @override
  String get contactReportTodo => 'Report feature is not connected yet';

  @override
  String get contactFriendRequested => 'Requested';

  @override
  String get contactApplyFriend => 'Add Friend';

  @override
  String get qrInvalidFormat => 'Invalid QR code format';

  @override
  String get qrInvalidUser => 'Invalid user QR code';

  @override
  String get qrInvalidGroup => 'Invalid group QR code';

  @override
  String get qrUnsupportedGroup => 'This group QR code is not supported yet';

  @override
  String get qrScannerInstruction =>
      'Place the QR code inside the frame to scan automatically';

  @override
  String get qrScannerSupportUsers => 'User QR codes are supported';

  @override
  String get meQrTitle => 'My QR Code';

  @override
  String get meQrHint => 'Scan this QR code to add me as a friend.';

  @override
  String get meQrSaveToAlbum => 'Save to Photos';

  @override
  String get meQrSaveTodo => 'Save to Photos is not connected yet';

  @override
  String get meQrUnconnectedDomain => 'No connected domain';
}
