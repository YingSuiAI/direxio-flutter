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
