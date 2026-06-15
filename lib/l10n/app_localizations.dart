import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
    Locale('ja')
  ];

  /// Application title
  ///
  /// In zh, this message translates to:
  /// **'TokLink'**
  String get appTitle;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageDialogTitle;

  /// No description provided for @tabChats.
  ///
  /// In zh, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabContacts.
  ///
  /// In zh, this message translates to:
  /// **'通讯录'**
  String get tabContacts;

  /// No description provided for @tabChannels.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get tabChannels;

  /// No description provided for @tabMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabMe;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用设置'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsFollowSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get settingsFavorites;

  /// No description provided for @settingsPrivacySecurity.
  ///
  /// In zh, this message translates to:
  /// **'隐私与安全'**
  String get settingsPrivacySecurity;

  /// No description provided for @settingsBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'通讯录黑名单'**
  String get settingsBlacklist;

  /// No description provided for @settingsChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get settingsChangePassword;

  /// No description provided for @settingsMessagesNotifications.
  ///
  /// In zh, this message translates to:
  /// **'消息与通知'**
  String get settingsMessagesNotifications;

  /// No description provided for @settingsDoNotDisturb.
  ///
  /// In zh, this message translates to:
  /// **'勿扰模式'**
  String get settingsDoNotDisturb;

  /// No description provided for @settingsMessageSound.
  ///
  /// In zh, this message translates to:
  /// **'新消息提示音'**
  String get settingsMessageSound;

  /// No description provided for @settingsMessageVibration.
  ///
  /// In zh, this message translates to:
  /// **'新消息震动'**
  String get settingsMessageVibration;

  /// No description provided for @settingsOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get settingsOther;

  /// No description provided for @settingsAboutUs.
  ///
  /// In zh, this message translates to:
  /// **'关于我们'**
  String get settingsAboutUs;

  /// No description provided for @settingsClearChats.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录'**
  String get settingsClearChats;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get settingsLogoutConfirmMessage;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// No description provided for @commonShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get commonShare;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'Portal IM'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用你的 Portal 域名和密码进入去中心化通讯空间'**
  String get loginSubtitle;

  /// No description provided for @loginDomainHint.
  ///
  /// In zh, this message translates to:
  /// **'https://你的域名'**
  String get loginDomainHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'登录密码'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginButton;

  /// No description provided for @loginButtonLoading.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get loginButtonLoading;

  /// No description provided for @addContactTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get addContactTitle;

  /// No description provided for @addContactEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入对方昵称或 Portal URL 查找'**
  String get addContactEmptyHint;

  /// No description provided for @addContactDomainNotProductUser.
  ///
  /// In zh, this message translates to:
  /// **'该域名不是产品用户'**
  String get addContactDomainNotProductUser;

  /// No description provided for @addContactMessageAfterAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加好友后即可发消息'**
  String get addContactMessageAfterAdding;

  /// No description provided for @addContactVoiceAfterAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加好友后即可音频通话'**
  String get addContactVoiceAfterAdding;

  /// No description provided for @addContactVideoAfterAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加好友后即可视频通话'**
  String get addContactVideoAfterAdding;

  /// No description provided for @addContactVerificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'好友验证'**
  String get addContactVerificationTitle;

  /// No description provided for @addContactVerificationMessageTitle.
  ///
  /// In zh, this message translates to:
  /// **'发送好友申请'**
  String get addContactVerificationMessageTitle;

  /// No description provided for @addContactVerificationSend.
  ///
  /// In zh, this message translates to:
  /// **'发送申请'**
  String get addContactVerificationSend;

  /// No description provided for @addContactRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'好友请求已发送，等待对方接受。'**
  String get addContactRequestSent;

  /// No description provided for @addContactRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送好友请求失败: {error}'**
  String addContactRequestFailed(String error);

  /// No description provided for @contactSendMessage.
  ///
  /// In zh, this message translates to:
  /// **'发消息'**
  String get contactSendMessage;

  /// No description provided for @contactVoiceCall.
  ///
  /// In zh, this message translates to:
  /// **'音频通话'**
  String get contactVoiceCall;

  /// No description provided for @contactVideoCall.
  ///
  /// In zh, this message translates to:
  /// **'视频通话'**
  String get contactVideoCall;

  /// No description provided for @contactMuteMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息免打扰'**
  String get contactMuteMessages;

  /// No description provided for @contactBlockUser.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽用户'**
  String get contactBlockUser;

  /// No description provided for @contactReportUser.
  ///
  /// In zh, this message translates to:
  /// **'举报用户'**
  String get contactReportUser;

  /// No description provided for @contactReportTodo.
  ///
  /// In zh, this message translates to:
  /// **'举报功能待接入'**
  String get contactReportTodo;

  /// No description provided for @contactFriendRequested.
  ///
  /// In zh, this message translates to:
  /// **'已申请'**
  String get contactFriendRequested;

  /// No description provided for @contactApplyFriend.
  ///
  /// In zh, this message translates to:
  /// **'申请好友'**
  String get contactApplyFriend;

  /// No description provided for @contactsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'ID/昵称/邮箱'**
  String get contactsSearchHint;

  /// No description provided for @contactsNewFriends.
  ///
  /// In zh, this message translates to:
  /// **'新朋友'**
  String get contactsNewFriends;

  /// No description provided for @contactsNewGroup.
  ///
  /// In zh, this message translates to:
  /// **'新的群聊'**
  String get contactsNewGroup;

  /// No description provided for @contactsMyGroups.
  ///
  /// In zh, this message translates to:
  /// **'我的群组'**
  String get contactsMyGroups;

  /// No description provided for @contactsGroups.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get contactsGroups;

  /// No description provided for @contactsFollows.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get contactsFollows;

  /// No description provided for @contactsCount.
  ///
  /// In zh, this message translates to:
  /// **'联系人 ({count})'**
  String contactsCount(int count);

  /// No description provided for @qrInvalidFormat.
  ///
  /// In zh, this message translates to:
  /// **'无效的二维码格式'**
  String get qrInvalidFormat;

  /// No description provided for @qrInvalidUser.
  ///
  /// In zh, this message translates to:
  /// **'无效的用户二维码'**
  String get qrInvalidUser;

  /// No description provided for @qrInvalidGroup.
  ///
  /// In zh, this message translates to:
  /// **'无效的群二维码'**
  String get qrInvalidGroup;

  /// No description provided for @qrUnsupportedGroup.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持该群二维码'**
  String get qrUnsupportedGroup;

  /// No description provided for @qrScannerInstruction.
  ///
  /// In zh, this message translates to:
  /// **'将二维码放入框内，即可自动扫描'**
  String get qrScannerInstruction;

  /// No description provided for @qrScannerSupportUsers.
  ///
  /// In zh, this message translates to:
  /// **'支持扫描用户二维码'**
  String get qrScannerSupportUsers;

  /// No description provided for @meQrTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的二维码'**
  String get meQrTitle;

  /// No description provided for @meQrHint.
  ///
  /// In zh, this message translates to:
  /// **'扫一扫上面的二维码图案，加我为好友。'**
  String get meQrHint;

  /// No description provided for @meQrSaveToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册'**
  String get meQrSaveToAlbum;

  /// No description provided for @meQrSaveTodo.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册功能待接入'**
  String get meQrSaveTodo;

  /// No description provided for @meQrUnconnectedDomain.
  ///
  /// In zh, this message translates to:
  /// **'未连接域名'**
  String get meQrUnconnectedDomain;

  /// No description provided for @groupInviteTitle.
  ///
  /// In zh, this message translates to:
  /// **'邀请加入群聊'**
  String get groupInviteTitle;

  /// No description provided for @groupInviteJoining.
  ///
  /// In zh, this message translates to:
  /// **'正在加入“{groupName}”'**
  String groupInviteJoining(String groupName);

  /// No description provided for @groupInviteBody.
  ///
  /// In zh, this message translates to:
  /// **'{inviter} 邀请你加入“{groupName}”'**
  String groupInviteBody(String inviter, String groupName);

  /// No description provided for @groupInviteFallbackInviter.
  ///
  /// In zh, this message translates to:
  /// **'对方'**
  String get groupInviteFallbackInviter;

  /// No description provided for @groupInviteJoinButton.
  ///
  /// In zh, this message translates to:
  /// **'加入群聊'**
  String get groupInviteJoinButton;

  /// No description provided for @groupInviteJoiningButton.
  ///
  /// In zh, this message translates to:
  /// **'加入中…'**
  String get groupInviteJoiningButton;

  /// No description provided for @groupInviteAlreadyJoined.
  ///
  /// In zh, this message translates to:
  /// **'已在群里中'**
  String get groupInviteAlreadyJoined;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
