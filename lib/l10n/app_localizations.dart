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
  /// **'Direxio'**
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
  /// **'聊天'**
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

  /// No description provided for @settingsClearChatsClearing.
  ///
  /// In zh, this message translates to:
  /// **'正在清空...'**
  String get settingsClearChatsClearing;

  /// No description provided for @settingsClearChatsConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将清空本机聊天记录、未读恢复和媒体缩略图缓存。服务器上的消息不会被删除。'**
  String get settingsClearChatsConfirmMessage;

  /// No description provided for @settingsClearChatsSuccess.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录已清空'**
  String get settingsClearChatsSuccess;

  /// No description provided for @settingsClearChatsFailure.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录失败，请稍后重试'**
  String get settingsClearChatsFailure;

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

  /// No description provided for @aboutWebsite.
  ///
  /// In zh, this message translates to:
  /// **'官网'**
  String get aboutWebsite;

  /// No description provided for @aboutEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get aboutEmail;

  /// No description provided for @aboutVersionUpdates.
  ///
  /// In zh, this message translates to:
  /// **'版本更新'**
  String get aboutVersionUpdates;

  /// No description provided for @channelManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道管理'**
  String get channelManageTitle;

  /// No description provided for @channelManageProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道资料'**
  String get channelManageProfileTitle;

  /// No description provided for @channelManageMembersTitle.
  ///
  /// In zh, this message translates to:
  /// **'成员与角色'**
  String get channelManageMembersTitle;

  /// No description provided for @channelManageModerationTitle.
  ///
  /// In zh, this message translates to:
  /// **'内容审核'**
  String get channelManageModerationTitle;

  /// No description provided for @channelManageTabOverview.
  ///
  /// In zh, this message translates to:
  /// **'我的频道'**
  String get channelManageTabOverview;

  /// No description provided for @channelManageTabProfile.
  ///
  /// In zh, this message translates to:
  /// **'资料权限'**
  String get channelManageTabProfile;

  /// No description provided for @channelManageTabMembers.
  ///
  /// In zh, this message translates to:
  /// **'成员角色'**
  String get channelManageTabMembers;

  /// No description provided for @channelManageTabModeration.
  ///
  /// In zh, this message translates to:
  /// **'内容审核'**
  String get channelManageTabModeration;

  /// No description provided for @channelManageStatSubscribers.
  ///
  /// In zh, this message translates to:
  /// **'订阅人数'**
  String get channelManageStatSubscribers;

  /// No description provided for @channelManageStatTodayMessages.
  ///
  /// In zh, this message translates to:
  /// **'今日消息'**
  String get channelManageStatTodayMessages;

  /// No description provided for @channelManageStatPending.
  ///
  /// In zh, this message translates to:
  /// **'待审核'**
  String get channelManageStatPending;

  /// No description provided for @channelManageStatAdmins.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get channelManageStatAdmins;

  /// No description provided for @channelManageStatNewToday.
  ///
  /// In zh, this message translates to:
  /// **'今日新增'**
  String get channelManageStatNewToday;

  /// No description provided for @channelManageStatMuted.
  ///
  /// In zh, this message translates to:
  /// **'禁言中'**
  String get channelManageStatMuted;

  /// No description provided for @channelManageStatReports.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get channelManageStatReports;

  /// No description provided for @channelManageStatAutoApproved.
  ///
  /// In zh, this message translates to:
  /// **'自动通过'**
  String get channelManageStatAutoApproved;

  /// No description provided for @channelManageMyChannels.
  ///
  /// In zh, this message translates to:
  /// **'我的频道'**
  String get channelManageMyChannels;

  /// No description provided for @channelManageCreateChannel.
  ///
  /// In zh, this message translates to:
  /// **'创建新频道'**
  String get channelManageCreateChannel;

  /// No description provided for @channelManageCreateChannelValue.
  ///
  /// In zh, this message translates to:
  /// **'名称、头像、简介'**
  String get channelManageCreateChannelValue;

  /// No description provided for @channelManageInviteLinks.
  ///
  /// In zh, this message translates to:
  /// **'频道邀请链接'**
  String get channelManageInviteLinks;

  /// No description provided for @channelManageInviteLinksValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个有效'**
  String channelManageInviteLinksValue(int count);

  /// No description provided for @channelManagePermissions.
  ///
  /// In zh, this message translates to:
  /// **'频道权限'**
  String get channelManagePermissions;

  /// No description provided for @channelManageVisibility.
  ///
  /// In zh, this message translates to:
  /// **'频道可见性'**
  String get channelManageVisibility;

  /// No description provided for @channelManageSpeechPermission.
  ///
  /// In zh, this message translates to:
  /// **'发言权限'**
  String get channelManageSpeechPermission;

  /// No description provided for @channelManageInvitePermission.
  ///
  /// In zh, this message translates to:
  /// **'邀请权限'**
  String get channelManageInvitePermission;

  /// No description provided for @channelManageMessageEncryption.
  ///
  /// In zh, this message translates to:
  /// **'消息加密'**
  String get channelManageMessageEncryption;

  /// No description provided for @channelManageEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get channelManageEnabled;

  /// No description provided for @channelManageDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get channelManageDisabled;

  /// No description provided for @channelManageDisableChannel.
  ///
  /// In zh, this message translates to:
  /// **'停用频道'**
  String get channelManageDisableChannel;

  /// No description provided for @channelManageVisibilityPublic.
  ///
  /// In zh, this message translates to:
  /// **'公开'**
  String get channelManageVisibilityPublic;

  /// No description provided for @channelManageVisibilityPrivate.
  ///
  /// In zh, this message translates to:
  /// **'私密'**
  String get channelManageVisibilityPrivate;

  /// No description provided for @channelManageSpeechAdminReview.
  ///
  /// In zh, this message translates to:
  /// **'管理员审核'**
  String get channelManageSpeechAdminReview;

  /// No description provided for @channelManageSpeechMembers.
  ///
  /// In zh, this message translates to:
  /// **'成员可发言'**
  String get channelManageSpeechMembers;

  /// No description provided for @channelManageInviteAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get channelManageInviteAdmin;

  /// No description provided for @channelManageInviteAdmins.
  ///
  /// In zh, this message translates to:
  /// **'邀请管理员'**
  String get channelManageInviteAdmins;

  /// No description provided for @channelManageInviteAdminsValue.
  ///
  /// In zh, this message translates to:
  /// **'通过 ID 或链接'**
  String get channelManageInviteAdminsValue;

  /// No description provided for @channelManageOwnerOnline.
  ///
  /// In zh, this message translates to:
  /// **'所有者 · 在线'**
  String get channelManageOwnerOnline;

  /// No description provided for @channelManageAdminModeration.
  ///
  /// In zh, this message translates to:
  /// **'管理员 · 内容审核'**
  String get channelManageAdminModeration;

  /// No description provided for @channelManageAdminOperations.
  ///
  /// In zh, this message translates to:
  /// **'管理员 · 成员运营'**
  String get channelManageAdminOperations;

  /// No description provided for @channelManageBotRiskControl.
  ///
  /// In zh, this message translates to:
  /// **'机器人 · 风控'**
  String get channelManageBotRiskControl;

  /// No description provided for @channelManageReviewSpeechTitle.
  ///
  /// In zh, this message translates to:
  /// **'新成员发言申请'**
  String get channelManageReviewSpeechTitle;

  /// No description provided for @channelManageReviewSpeechBody.
  ///
  /// In zh, this message translates to:
  /// **'用户 @ray 申请在公告频道发布节点同步说明。'**
  String get channelManageReviewSpeechBody;

  /// No description provided for @channelManageReviewSpeechTag.
  ///
  /// In zh, this message translates to:
  /// **'发言'**
  String get channelManageReviewSpeechTag;

  /// No description provided for @channelManageReviewLinkTitle.
  ///
  /// In zh, this message translates to:
  /// **'链接风险提示'**
  String get channelManageReviewLinkTitle;

  /// No description provided for @channelManageReviewLinkBody.
  ///
  /// In zh, this message translates to:
  /// **'检测到外部链接，需要管理员确认后展示。'**
  String get channelManageReviewLinkBody;

  /// No description provided for @channelManageReviewLinkTag.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get channelManageReviewLinkTag;

  /// No description provided for @channelManageReviewReportTitle.
  ///
  /// In zh, this message translates to:
  /// **'举报消息'**
  String get channelManageReviewReportTitle;

  /// No description provided for @channelManageReviewReportBody.
  ///
  /// In zh, this message translates to:
  /// **'2 位成员举报该消息包含重复广告内容。'**
  String get channelManageReviewReportBody;

  /// No description provided for @channelManageReviewReportTag.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get channelManageReviewReportTag;

  /// No description provided for @channelManageAutoRules.
  ///
  /// In zh, this message translates to:
  /// **'自动审核规则'**
  String get channelManageAutoRules;

  /// No description provided for @channelManageAutoRulesValue.
  ///
  /// In zh, this message translates to:
  /// **'关键词 / 链接 / 频率'**
  String get channelManageAutoRulesValue;

  /// No description provided for @channelManageEditProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get channelManageEditProfile;

  /// No description provided for @channelManageManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get channelManageManage;

  /// No description provided for @channelManageManaging.
  ///
  /// In zh, this message translates to:
  /// **'管理中'**
  String get channelManageManaging;

  /// No description provided for @channelManageApprove.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get channelManageApprove;

  /// No description provided for @channelManageReject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get channelManageReject;

  /// No description provided for @channelManageDefaultChannelName.
  ///
  /// In zh, this message translates to:
  /// **'P2P Matrix 公告'**
  String get channelManageDefaultChannelName;

  /// No description provided for @channelManageDefaultChannelDescription.
  ///
  /// In zh, this message translates to:
  /// **'项目公告、节点状态与版本发布'**
  String get channelManageDefaultChannelDescription;

  /// No description provided for @channelManageChannelSummary.
  ///
  /// In zh, this message translates to:
  /// **'{visibility}频道 · {members} 人 · 今日 {messages} 条'**
  String channelManageChannelSummary(
      String visibility, String members, int messages);

  /// No description provided for @channelManageComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'{label} 功能待接入'**
  String channelManageComingSoon(String label);

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
  /// **'你的域名'**
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

  /// No description provided for @loginTermsOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开用户协议与隐私条款'**
  String get loginTermsOpenFailed;

  /// No description provided for @loginAgreementRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'请先阅读并同意'**
  String get loginAgreementRequiredTitle;

  /// No description provided for @loginAgreementRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录前需要同意用户协议与隐私条款。'**
  String get loginAgreementRequiredMessage;

  /// No description provided for @loginAgreementConfirmAndLogin.
  ///
  /// In zh, this message translates to:
  /// **'同意并登录'**
  String get loginAgreementConfirmAndLogin;

  /// No description provided for @agreementPrefix.
  ///
  /// In zh, this message translates to:
  /// **'阅读并同意'**
  String get agreementPrefix;

  /// No description provided for @agreementTermsPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'《用户协议&隐私条款》'**
  String get agreementTermsPrivacy;

  /// No description provided for @initPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 8 位'**
  String get initPasswordTooShort;

  /// No description provided for @initPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get initPasswordMismatch;

  /// No description provided for @initPortalDomainHint.
  ///
  /// In zh, this message translates to:
  /// **'Portal 域名'**
  String get initPortalDomainHint;

  /// No description provided for @initDisplayNameHint.
  ///
  /// In zh, this message translates to:
  /// **'用户昵称'**
  String get initDisplayNameHint;

  /// No description provided for @initOwnerTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'长期登录口令'**
  String get initOwnerTokenHint;

  /// No description provided for @initPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'登录密码'**
  String get initPasswordHint;

  /// No description provided for @initConfirmOwnerTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'再次输入长期登录口令'**
  String get initConfirmOwnerTokenHint;

  /// No description provided for @initConfirmPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'再次输入登录密码'**
  String get initConfirmPasswordHint;

  /// No description provided for @initPasswordRule.
  ///
  /// In zh, this message translates to:
  /// **'密码至少8位'**
  String get initPasswordRule;

  /// No description provided for @initButton.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get initButton;

  /// No description provided for @initButtonLoading.
  ///
  /// In zh, this message translates to:
  /// **'初始化中…'**
  String get initButtonLoading;

  /// No description provided for @initExistingAccountLogin.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？登录'**
  String get initExistingAccountLogin;

  /// No description provided for @initAvatarRequired.
  ///
  /// In zh, this message translates to:
  /// **'请设置头像'**
  String get initAvatarRequired;

  /// No description provided for @initPortalDomainRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写 Portal 域名'**
  String get initPortalDomainRequired;

  /// No description provided for @initDisplayNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写用户昵称'**
  String get initDisplayNameRequired;

  /// No description provided for @initOwnerTokenRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写长期登录口令'**
  String get initOwnerTokenRequired;

  /// No description provided for @initConfirmOwnerTokenRequired.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入长期登录口令'**
  String get initConfirmOwnerTokenRequired;

  /// No description provided for @setupScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫码添加服务器'**
  String get setupScanTitle;

  /// No description provided for @setupScanHint.
  ///
  /// In zh, this message translates to:
  /// **'扫描 Portal 设置页上的二维码'**
  String get setupScanHint;

  /// No description provided for @setupManualEntry.
  ///
  /// In zh, this message translates to:
  /// **'手动输入'**
  String get setupManualEntry;

  /// No description provided for @setupManualTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动添加 Portal'**
  String get setupManualTitle;

  /// No description provided for @setupManualPortalLabel.
  ///
  /// In zh, this message translates to:
  /// **'Portal URL 或二维码链接'**
  String get setupManualPortalLabel;

  /// No description provided for @setupManualPortalHint.
  ///
  /// In zh, this message translates to:
  /// **'p2p-im.com 或 p2pim://setup?...'**
  String get setupManualPortalHint;

  /// No description provided for @setupManualCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'一次性设置码'**
  String get setupManualCodeLabel;

  /// No description provided for @setupManualCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'8 位小写字母或数字'**
  String get setupManualCodeHint;

  /// No description provided for @setupManualContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get setupManualContinue;

  /// No description provided for @setupInvalidCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入 8 位设置码'**
  String get setupInvalidCode;

  /// No description provided for @setupPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置登录口令'**
  String get setupPasswordTitle;

  /// No description provided for @setupPasswordQrCodeWillExpire.
  ///
  /// In zh, this message translates to:
  /// **'设置后，当前二维码设置码会失效'**
  String get setupPasswordQrCodeWillExpire;

  /// No description provided for @setupPasswordEnterCodeAndPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入该 Portal 的设置码并设置登录口令'**
  String get setupPasswordEnterCodeAndPassword;

  /// No description provided for @setupCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'设置码'**
  String get setupCodeHint;

  /// No description provided for @setupNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'新登录口令'**
  String get setupNewPasswordHint;

  /// No description provided for @setupConfirmNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'再次输入登录口令'**
  String get setupConfirmNewPasswordHint;

  /// No description provided for @setupPasswordSaving.
  ///
  /// In zh, this message translates to:
  /// **'设置中…'**
  String get setupPasswordSaving;

  /// No description provided for @setupPasswordDone.
  ///
  /// In zh, this message translates to:
  /// **'完成设置'**
  String get setupPasswordDone;

  /// No description provided for @setupPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的口令不一致'**
  String get setupPasswordMismatch;

  /// No description provided for @addContactTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get addContactTitle;

  /// No description provided for @addContactEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入对方域名查找'**
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

  /// No description provided for @addContactCannotAddSelf.
  ///
  /// In zh, this message translates to:
  /// **'不能添加自己'**
  String get addContactCannotAddSelf;

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

  /// No description provided for @createGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'发起群聊'**
  String get createGroupTitle;

  /// No description provided for @createGroupDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get createGroupDone;

  /// No description provided for @createGroupEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无可邀请联系人'**
  String get createGroupEmptyTitle;

  /// No description provided for @createGroupEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先添加好友后再发起群聊'**
  String get createGroupEmptySubtitle;

  /// No description provided for @createGroupNoResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有找到好友'**
  String get createGroupNoResultsTitle;

  /// No description provided for @createGroupNoResultsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'换个 ID、昵称或邮箱试试'**
  String get createGroupNoResultsSubtitle;

  /// No description provided for @createGroupDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get createGroupDefaultName;

  /// No description provided for @createGroupSingleName.
  ///
  /// In zh, this message translates to:
  /// **'{name}的群聊'**
  String createGroupSingleName(String name);

  /// No description provided for @createGroupMultipleName.
  ///
  /// In zh, this message translates to:
  /// **'{names}等人的群聊'**
  String createGroupMultipleName(String names);

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

  /// No description provided for @meQrSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get meQrSaving;

  /// No description provided for @meQrSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已保存到相册'**
  String get meQrSaveSuccess;

  /// No description provided for @meQrSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请检查相册权限'**
  String get meQrSaveFailed;

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

  /// No description provided for @commonOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号在其他设备登录'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'请重新登录'**
  String get sessionExpiredMessage;

  /// No description provided for @chatRecordForwarded.
  ///
  /// In zh, this message translates to:
  /// **'已转发聊天记录'**
  String get chatRecordForwarded;

  /// No description provided for @chatRecordForwardFailed.
  ///
  /// In zh, this message translates to:
  /// **'转发失败：{error}'**
  String chatRecordForwardFailed(String error);

  /// No description provided for @channelFallbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get channelFallbackTitle;

  /// No description provided for @channelMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道不存在'**
  String get channelMissingTitle;

  /// No description provided for @channelMissingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'该频道可能是私密频道、已删除，或目标节点暂时不可达'**
  String get channelMissingSubtitle;

  /// No description provided for @channelNoPublicContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有公开内容'**
  String get channelNoPublicContentTitle;

  /// No description provided for @channelNoPublicContentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'加入频道后可以查看后续发布内容'**
  String get channelNoPublicContentSubtitle;

  /// No description provided for @channelJoinFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入频道失败：{error}'**
  String channelJoinFailed(String error);

  /// No description provided for @channelJoinJoined.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get channelJoinJoined;

  /// No description provided for @channelJoinPending.
  ///
  /// In zh, this message translates to:
  /// **'待审核'**
  String get channelJoinPending;

  /// No description provided for @channelJoinSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get channelJoinSyncing;

  /// No description provided for @channelJoinRetry.
  ///
  /// In zh, this message translates to:
  /// **'重新加入'**
  String get channelJoinRetry;

  /// No description provided for @channelJoinApply.
  ///
  /// In zh, this message translates to:
  /// **'申请加入'**
  String get channelJoinApply;

  /// No description provided for @channelJoinAction.
  ///
  /// In zh, this message translates to:
  /// **'加入频道'**
  String get channelJoinAction;

  /// No description provided for @channelJoinProcessing.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get channelJoinProcessing;

  /// No description provided for @channelPostEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有频道内容'**
  String get channelPostEmptyTitle;

  /// No description provided for @channelPostEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'发布后会显示在这里'**
  String get channelPostEmptySubtitle;

  /// No description provided for @channelPostPublish.
  ///
  /// In zh, this message translates to:
  /// **'发表'**
  String get channelPostPublish;

  /// No description provided for @channelPostPublishing.
  ///
  /// In zh, this message translates to:
  /// **'发表中'**
  String get channelPostPublishing;

  /// No description provided for @channelPostPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'发表帖子...'**
  String get channelPostPlaceholder;

  /// No description provided for @channelPostPublishFailed.
  ///
  /// In zh, this message translates to:
  /// **'发表失败：{error}'**
  String channelPostPublishFailed(String error);

  /// No description provided for @channelPostImageUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片上传失败：{error}'**
  String channelPostImageUploadFailed(String error);

  /// No description provided for @channelPostDeleted.
  ///
  /// In zh, this message translates to:
  /// **'帖子已删除'**
  String get channelPostDeleted;

  /// No description provided for @channelPostDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除帖子失败：{error}'**
  String channelPostDeleteFailed(String error);

  /// No description provided for @channelPostDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除帖子'**
  String get channelPostDeleteTooltip;

  /// No description provided for @channelPostType.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get channelPostType;

  /// No description provided for @channelPostDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'我发布的帖子'**
  String get channelPostDefaultTitle;

  /// No description provided for @channelPostExpandMore.
  ///
  /// In zh, this message translates to:
  /// **'展开更多'**
  String get channelPostExpandMore;

  /// No description provided for @channelPostCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get channelPostCollapse;

  /// No description provided for @channelPostCommentHint.
  ///
  /// In zh, this message translates to:
  /// **'输入评论...'**
  String get channelPostCommentHint;

  /// No description provided for @channelPostDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'帖子详情'**
  String get channelPostDetailTitle;

  /// No description provided for @channelPostCommentLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'评论加载失败'**
  String get channelPostCommentLoadFailed;

  /// No description provided for @channelPostNoMoreComments.
  ///
  /// In zh, this message translates to:
  /// **'没有更多评论'**
  String get channelPostNoMoreComments;

  /// No description provided for @channelPostIdCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制帖子 ID'**
  String get channelPostIdCopied;

  /// No description provided for @channelPostReply.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get channelPostReply;

  /// No description provided for @channelPostCollapseComments.
  ///
  /// In zh, this message translates to:
  /// **'收起评论'**
  String get channelPostCollapseComments;

  /// No description provided for @channelPostCommentCount.
  ///
  /// In zh, this message translates to:
  /// **'共{count}条评论'**
  String channelPostCommentCount(int count);

  /// No description provided for @channelPostViewComments.
  ///
  /// In zh, this message translates to:
  /// **'查看评论{countText}'**
  String channelPostViewComments(String countText);

  /// No description provided for @channelPostMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'帖子不存在'**
  String get channelPostMissingTitle;

  /// No description provided for @channelPostMissingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'该帖子可能已删除，或尚未同步到本机。'**
  String get channelPostMissingSubtitle;

  /// No description provided for @meMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get meMenuTitle;

  /// No description provided for @meMyFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get meMyFavorites;

  /// No description provided for @meMyLikes.
  ///
  /// In zh, this message translates to:
  /// **'我的点赞'**
  String get meMyLikes;

  /// No description provided for @meMyComments.
  ///
  /// In zh, this message translates to:
  /// **'我的评论'**
  String get meMyComments;

  /// No description provided for @meFavoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get meFavoritesTitle;

  /// No description provided for @meLikesTitle.
  ///
  /// In zh, this message translates to:
  /// **'赞'**
  String get meLikesTitle;

  /// No description provided for @meCommentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get meCommentsTitle;

  /// No description provided for @meHelpFeedbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get meHelpFeedbackTitle;

  /// No description provided for @meHelpFeedbackBody.
  ///
  /// In zh, this message translates to:
  /// **'官方邮箱：support@direxio.ai\n\n温馨提示：请在反馈中描述问题发生的页面、操作步骤和设备型号。'**
  String get meHelpFeedbackBody;

  /// No description provided for @meHelpFeedbackOk.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get meHelpFeedbackOk;

  /// No description provided for @meUidCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 UID'**
  String get meUidCopied;

  /// No description provided for @meFavoriteDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏详情'**
  String get meFavoriteDetailTitle;

  /// No description provided for @meFavoriteDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除收藏'**
  String get meFavoriteDeleteAction;

  /// No description provided for @meFavoriteRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get meFavoriteRemoveTitle;

  /// No description provided for @meFavoriteDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认删除该收藏吗？'**
  String get meFavoriteDeleteConfirm;

  /// No description provided for @meFavoriteDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除收藏'**
  String get meFavoriteDeleted;

  /// No description provided for @meFavoriteDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除收藏失败：{error}'**
  String meFavoriteDeleteFailed(String error);

  /// No description provided for @meFavoritesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'收藏加载失败'**
  String get meFavoritesLoadFailed;

  /// No description provided for @meFavoritesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get meFavoritesEmptyTitle;

  /// No description provided for @meFavoritesEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'长按聊天消息收藏后会显示在这里'**
  String get meFavoritesEmptySubtitle;

  /// No description provided for @meLikesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'点赞加载失败'**
  String get meLikesLoadFailed;

  /// No description provided for @meLikesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无点赞'**
  String get meLikesEmptyTitle;

  /// No description provided for @meLikesEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你点过赞的频道帖子会显示在这里'**
  String get meLikesEmptySubtitle;

  /// No description provided for @meLikedPost.
  ///
  /// In zh, this message translates to:
  /// **'你赞了这条帖子'**
  String get meLikedPost;

  /// No description provided for @meReactedWith.
  ///
  /// In zh, this message translates to:
  /// **'你回应了：{value}'**
  String meReactedWith(String value);

  /// No description provided for @meCommentsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'评论加载失败'**
  String get meCommentsLoadFailed;

  /// No description provided for @meCommentsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get meCommentsEmptyTitle;

  /// No description provided for @meCommentsEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你在频道帖子下发表过的评论会显示在这里'**
  String get meCommentsEmptySubtitle;

  /// No description provided for @meCommentFallback.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get meCommentFallback;

  /// No description provided for @meCommentedWith.
  ///
  /// In zh, this message translates to:
  /// **'你评论了：{body}'**
  String meCommentedWith(String body);

  /// No description provided for @meChannelPostFallback.
  ///
  /// In zh, this message translates to:
  /// **'频道帖子'**
  String get meChannelPostFallback;

  /// No description provided for @meFavoriteMessageFallback.
  ///
  /// In zh, this message translates to:
  /// **'收藏消息'**
  String get meFavoriteMessageFallback;

  /// No description provided for @meFavoriteUnknownSender.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get meFavoriteUnknownSender;

  /// No description provided for @meFavoriteTypeText.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get meFavoriteTypeText;

  /// No description provided for @meFavoriteTypeImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get meFavoriteTypeImage;

  /// No description provided for @meFavoriteTypeVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get meFavoriteTypeVideo;

  /// No description provided for @meFavoriteTypeFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get meFavoriteTypeFile;

  /// No description provided for @meFavoriteTypeChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录'**
  String get meFavoriteTypeChatRecord;

  /// No description provided for @meFavoriteTypeAudio.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get meFavoriteTypeAudio;

  /// No description provided for @meFavoriteTypeLink.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get meFavoriteTypeLink;

  /// No description provided for @meFavoriteTypeMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get meFavoriteTypeMessage;

  /// No description provided for @meFavoriteFromDirect.
  ///
  /// In zh, this message translates to:
  /// **'来自私聊'**
  String get meFavoriteFromDirect;

  /// No description provided for @meFavoriteFromDirectWithSender.
  ///
  /// In zh, this message translates to:
  /// **'来自与 {sender} 的私聊'**
  String meFavoriteFromDirectWithSender(String sender);

  /// No description provided for @meFavoriteFromGroup.
  ///
  /// In zh, this message translates to:
  /// **'来自群聊'**
  String get meFavoriteFromGroup;

  /// No description provided for @meFavoriteFromGroupWithSender.
  ///
  /// In zh, this message translates to:
  /// **'来自群聊 · {sender}'**
  String meFavoriteFromGroupWithSender(String sender);

  /// No description provided for @meFavoriteFromChannel.
  ///
  /// In zh, this message translates to:
  /// **'来自频道'**
  String get meFavoriteFromChannel;

  /// No description provided for @meFavoriteFromChannelWithSender.
  ///
  /// In zh, this message translates to:
  /// **'来自频道 · {sender}'**
  String meFavoriteFromChannelWithSender(String sender);

  /// No description provided for @meFavoriteFromAgent.
  ///
  /// In zh, this message translates to:
  /// **'来自 Agent'**
  String get meFavoriteFromAgent;

  /// No description provided for @meFavoriteFromChat.
  ///
  /// In zh, this message translates to:
  /// **'来自聊天'**
  String get meFavoriteFromChat;

  /// No description provided for @meFavoriteFromChatWithSender.
  ///
  /// In zh, this message translates to:
  /// **'来自聊天 · {sender}'**
  String meFavoriteFromChatWithSender(String sender);

  /// No description provided for @meFavoriteDirectChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'私聊聊天记录'**
  String get meFavoriteDirectChatRecord;

  /// No description provided for @meFavoriteDirectChatRecordWithName.
  ///
  /// In zh, this message translates to:
  /// **'与 {name} 的聊天记录'**
  String meFavoriteDirectChatRecordWithName(String name);

  /// No description provided for @meFavoriteGroupChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'群聊聊天记录'**
  String get meFavoriteGroupChatRecord;

  /// No description provided for @meFavoriteGroupChatRecordWithName.
  ///
  /// In zh, this message translates to:
  /// **'群聊「{name}」的聊天记录'**
  String meFavoriteGroupChatRecordWithName(String name);

  /// No description provided for @meFavoriteChannelChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'频道聊天记录'**
  String get meFavoriteChannelChatRecord;

  /// No description provided for @meFavoriteChannelChatRecordWithName.
  ///
  /// In zh, this message translates to:
  /// **'频道「{name}」的聊天记录'**
  String meFavoriteChannelChatRecordWithName(String name);

  /// No description provided for @meFavoriteAgentChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'与 Agent 的聊天记录'**
  String get meFavoriteAgentChatRecord;

  /// No description provided for @meFavoriteDetailBody.
  ///
  /// In zh, this message translates to:
  /// **'收藏详情\n{title}\n共 1 条消息'**
  String meFavoriteDetailBody(String title);

  /// No description provided for @commonMe.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get commonMe;

  /// No description provided for @commonJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get commonJustNow;
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
