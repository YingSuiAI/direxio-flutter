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

  /// No description provided for @homeDeleteChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除聊天记录'**
  String get homeDeleteChatTitle;

  /// No description provided for @homeDeleteChatMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」的所有聊天记录？该操作不可恢复。'**
  String homeDeleteChatMessage(String name);

  /// No description provided for @homeConversationDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{name}」'**
  String homeConversationDeleted(String name);

  /// No description provided for @homeDeleteChatFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除聊天记录失败: {error}'**
  String homeDeleteChatFailed(String error);

  /// No description provided for @homeAgentConversationNotSynced.
  ///
  /// In zh, this message translates to:
  /// **'Agent 会话还未同步'**
  String get homeAgentConversationNotSynced;

  /// No description provided for @homeDeleteChatMenu.
  ///
  /// In zh, this message translates to:
  /// **'删除聊天'**
  String get homeDeleteChatMenu;

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

  /// No description provided for @blacklistRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get blacklistRemove;

  /// No description provided for @blacklistRemovedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {name}'**
  String blacklistRemovedMessage(String name);

  /// No description provided for @blacklistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无黑名单联系人'**
  String get blacklistEmpty;

  /// No description provided for @settingsChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get settingsChangePassword;

  /// No description provided for @changePasswordOldHint.
  ///
  /// In zh, this message translates to:
  /// **'原密码'**
  String get changePasswordOldHint;

  /// No description provided for @changePasswordNewHint.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get changePasswordNewHint;

  /// No description provided for @changePasswordConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'再次输入新密码'**
  String get changePasswordConfirmHint;

  /// No description provided for @changePasswordRule.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 8 位'**
  String get changePasswordRule;

  /// No description provided for @changePasswordOldTooShort.
  ///
  /// In zh, this message translates to:
  /// **'原密码至少 8 位'**
  String get changePasswordOldTooShort;

  /// No description provided for @changePasswordNewTooShort.
  ///
  /// In zh, this message translates to:
  /// **'新密码至少 8 位'**
  String get changePasswordNewTooShort;

  /// No description provided for @changePasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get changePasswordMismatch;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码已修改'**
  String get changePasswordSuccess;

  /// No description provided for @changePasswordSubmitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中…'**
  String get changePasswordSubmitting;

  /// No description provided for @changePasswordSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交修改'**
  String get changePasswordSubmit;

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

  /// No description provided for @settingsDeactivateLogin.
  ///
  /// In zh, this message translates to:
  /// **'注销账号'**
  String get settingsDeactivateLogin;

  /// No description provided for @settingsDeactivateLoginConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'注销账号'**
  String get settingsDeactivateLoginConfirmTitle;

  /// No description provided for @settingsDeactivateLoginConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'14天内，只要登录一次账号，账号注销就会自动取消'**
  String get settingsDeactivateLoginConfirmMessage;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// No description provided for @commonSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get commonSend;

  /// No description provided for @commonShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get commonShare;

  /// No description provided for @commonOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get commonOnline;

  /// No description provided for @commonOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get commonOffline;

  /// No description provided for @toolCallDenied.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get toolCallDenied;

  /// No description provided for @toolCallArguments.
  ///
  /// In zh, this message translates to:
  /// **'参数'**
  String get toolCallArguments;

  /// No description provided for @toolCallWarnings.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get toolCallWarnings;

  /// No description provided for @mcpPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'MCP 权限'**
  String get mcpPermissionTitle;

  /// No description provided for @mcpPermissionDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理哪些 Agent 账号可以调用 MCP 工具。'**
  String get mcpPermissionDescription;

  /// No description provided for @mcpPermissionAuthorizeNewAgent.
  ///
  /// In zh, this message translates to:
  /// **'授权新的 Agent'**
  String get mcpPermissionAuthorizeNewAgent;

  /// No description provided for @mcpPermissionAuthorized.
  ///
  /// In zh, this message translates to:
  /// **'已授权'**
  String get mcpPermissionAuthorized;

  /// No description provided for @mcpPermissionDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get mcpPermissionDisabled;

  /// No description provided for @mcpPolicyRevokeAction.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get mcpPolicyRevokeAction;

  /// No description provided for @mcpPolicyRevokeAccess.
  ///
  /// In zh, this message translates to:
  /// **'撤销访问'**
  String get mcpPolicyRevokeAccess;

  /// No description provided for @mcpPolicyAuditEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无审计记录'**
  String get mcpPolicyAuditEmptyTitle;

  /// No description provided for @mcpPolicyAuditEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'工具调用记录会显示在这里'**
  String get mcpPolicyAuditEmptySubtitle;

  /// No description provided for @mcpPolicyCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get mcpPolicyCompleted;

  /// No description provided for @mcpPolicyWriteBadge.
  ///
  /// In zh, this message translates to:
  /// **'写入'**
  String get mcpPolicyWriteBadge;

  /// No description provided for @mcpPolicyConfirmBeforeCall.
  ///
  /// In zh, this message translates to:
  /// **'调用前确认'**
  String get mcpPolicyConfirmBeforeCall;

  /// No description provided for @mcpPolicySelectedRooms.
  ///
  /// In zh, this message translates to:
  /// **'已选择房间'**
  String get mcpPolicySelectedRooms;

  /// No description provided for @mcpPolicyExcludedRooms.
  ///
  /// In zh, this message translates to:
  /// **'已排除房间'**
  String get mcpPolicyExcludedRooms;

  /// No description provided for @mcpPolicyAddRoom.
  ///
  /// In zh, this message translates to:
  /// **'添加房间'**
  String get mcpPolicyAddRoom;

  /// No description provided for @channelCreatedNotice.
  ///
  /// In zh, this message translates to:
  /// **'频道已创建'**
  String get channelCreatedNotice;

  /// No description provided for @channelManageEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道'**
  String get channelManageEmptyTitle;

  /// No description provided for @channelManageEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'创建的频道会显示在这里'**
  String get channelManageEmptySubtitle;

  /// No description provided for @homeDetailPlaceholderTitle.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个{tabTitle}项目'**
  String homeDetailPlaceholderTitle(String tabTitle);

  /// No description provided for @homeDetailPlaceholderChatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开会话查看消息'**
  String get homeDetailPlaceholderChatsSubtitle;

  /// No description provided for @homeDetailPlaceholderDefaultSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择项目查看详情'**
  String get homeDetailPlaceholderDefaultSubtitle;

  /// No description provided for @groupDetailMissing.
  ///
  /// In zh, this message translates to:
  /// **'群聊不存在'**
  String get groupDetailMissing;

  /// No description provided for @groupDetailChatInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊信息（{count}）'**
  String groupDetailChatInfoTitle(int count);

  /// No description provided for @groupDetailDissolveTitle.
  ///
  /// In zh, this message translates to:
  /// **'解散群聊'**
  String get groupDetailDissolveTitle;

  /// No description provided for @groupDetailLeaveTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出群聊'**
  String get groupDetailLeaveTitle;

  /// No description provided for @groupDetailDissolveMessage.
  ///
  /// In zh, this message translates to:
  /// **'解散后，成员将无法继续使用此群聊。'**
  String get groupDetailDissolveMessage;

  /// No description provided for @groupDetailLeaveMessage.
  ///
  /// In zh, this message translates to:
  /// **'退出后，你将不再接收此群聊消息。'**
  String get groupDetailLeaveMessage;

  /// No description provided for @groupDetailDissolveAction.
  ///
  /// In zh, this message translates to:
  /// **'解散'**
  String get groupDetailDissolveAction;

  /// No description provided for @groupDetailLeaveAction.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get groupDetailLeaveAction;

  /// No description provided for @groupDetailLeaveOrDissolveFailed.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败：{error}'**
  String groupDetailLeaveOrDissolveFailed(String action, String error);

  /// No description provided for @groupDetailInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请'**
  String get groupDetailInvite;

  /// No description provided for @avatarAdjustTitle.
  ///
  /// In zh, this message translates to:
  /// **'调整头像'**
  String get avatarAdjustTitle;

  /// No description provided for @avatarAdjustHint.
  ///
  /// In zh, this message translates to:
  /// **'双指缩放或拖动图片'**
  String get avatarAdjustHint;

  /// No description provided for @avatarAdjustReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get avatarAdjustReset;

  /// No description provided for @avatarAdjustDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get avatarAdjustDone;

  /// No description provided for @avatarAdjustUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'头像更新失败: {error}'**
  String avatarAdjustUpdateFailed(String error);

  /// No description provided for @avatarAdjustPreviewNotReady.
  ///
  /// In zh, this message translates to:
  /// **'头像预览尚未准备好'**
  String get avatarAdjustPreviewNotReady;

  /// No description provided for @avatarAdjustExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'头像导出失败'**
  String get avatarAdjustExportFailed;

  /// No description provided for @profileInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的信息'**
  String get profileInfoTitle;

  /// No description provided for @profileInfoAvatarEdit.
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get profileInfoAvatarEdit;

  /// No description provided for @profileInfoMatrixSessionMissing.
  ///
  /// In zh, this message translates to:
  /// **'当前 Matrix 登录态缺失'**
  String get profileInfoMatrixSessionMissing;

  /// No description provided for @profileInfoAvatarUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'头像更新失败: {error}'**
  String profileInfoAvatarUpdateFailed(String error);

  /// No description provided for @profileInfoNickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get profileInfoNickname;

  /// No description provided for @profileInfoDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get profileInfoDisplayName;

  /// No description provided for @profileInfoGender.
  ///
  /// In zh, this message translates to:
  /// **'性别'**
  String get profileInfoGender;

  /// No description provided for @profileInfoGenderMale.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get profileInfoGenderMale;

  /// No description provided for @profileInfoGenderFemale.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get profileInfoGenderFemale;

  /// No description provided for @profileInfoGenderUpdated.
  ///
  /// In zh, this message translates to:
  /// **'性别已更新'**
  String get profileInfoGenderUpdated;

  /// No description provided for @profileInfoBirthday.
  ///
  /// In zh, this message translates to:
  /// **'生日'**
  String get profileInfoBirthday;

  /// No description provided for @profileInfoBirthdayPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择生日'**
  String get profileInfoBirthdayPickerTitle;

  /// No description provided for @profileInfoBirthdayUpdated.
  ///
  /// In zh, this message translates to:
  /// **'生日已更新'**
  String get profileInfoBirthdayUpdated;

  /// No description provided for @profileInfoEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get profileInfoEmail;

  /// No description provided for @profileInfoEmailUpdated.
  ///
  /// In zh, this message translates to:
  /// **'邮箱已更新'**
  String get profileInfoEmailUpdated;

  /// No description provided for @profileInfoUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get profileInfoUnset;

  /// No description provided for @profileInfoUidCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 UID'**
  String get profileInfoUidCopied;

  /// No description provided for @profileInfoEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改{field}'**
  String profileInfoEditTitle(String field);

  /// No description provided for @profileInfoInputHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入{field}'**
  String profileInfoInputHint(String field);

  /// No description provided for @profileInfoDisplayNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'用户名不能为空'**
  String get profileInfoDisplayNameEmpty;

  /// No description provided for @profileInfoDisplayNameSystemName.
  ///
  /// In zh, this message translates to:
  /// **'请设置一个不同于系统账号的用户名'**
  String get profileInfoDisplayNameSystemName;

  /// No description provided for @profileInfoDisplayNameUpdated.
  ///
  /// In zh, this message translates to:
  /// **'用户名已更新'**
  String get profileInfoDisplayNameUpdated;

  /// No description provided for @profileInfoFieldUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'{field}更新失败: {error}'**
  String profileInfoFieldUpdateFailed(String field, String error);

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

  /// No description provided for @channelManageStatOwner.
  ///
  /// In zh, this message translates to:
  /// **'频道主'**
  String get channelManageStatOwner;

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

  /// No description provided for @createChannelTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建频道'**
  String get createChannelTitle;

  /// No description provided for @createChannelNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道名称'**
  String get createChannelNameTitle;

  /// No description provided for @createChannelNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入'**
  String get createChannelNameHint;

  /// No description provided for @createChannelAvatarTitle.
  ///
  /// In zh, this message translates to:
  /// **'上传频道头像'**
  String get createChannelAvatarTitle;

  /// No description provided for @createChannelAvatarSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持图片上传，作为频道展示头像'**
  String get createChannelAvatarSubtitle;

  /// No description provided for @createChannelTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择频道类型'**
  String get createChannelTypeTitle;

  /// No description provided for @createChannelTypeText.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get createChannelTypeText;

  /// No description provided for @createChannelTypeTextSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'成员自由发言'**
  String get createChannelTypeTextSubtitle;

  /// No description provided for @createChannelTypePosts.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get createChannelTypePosts;

  /// No description provided for @createChannelTypePostsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'帖子与评论'**
  String get createChannelTypePostsSubtitle;

  /// No description provided for @createChannelPermissionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道权限'**
  String get createChannelPermissionsTitle;

  /// No description provided for @createChannelPublicTitle.
  ///
  /// In zh, this message translates to:
  /// **'是否公开'**
  String get createChannelPublicTitle;

  /// No description provided for @createChannelPublicSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后仅通过邀请加入'**
  String get createChannelPublicSubtitle;

  /// No description provided for @createChannelApprovalTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入是否需要审核'**
  String get createChannelApprovalTitle;

  /// No description provided for @createChannelApprovalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后新成员加入前需要频道审核'**
  String get createChannelApprovalSubtitle;

  /// No description provided for @createChannelIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道介绍'**
  String get createChannelIntroTitle;

  /// No description provided for @createChannelIntroHint.
  ///
  /// In zh, this message translates to:
  /// **'输入频道介绍...'**
  String get createChannelIntroHint;

  /// No description provided for @createChannelSubmit.
  ///
  /// In zh, this message translates to:
  /// **'创建频道'**
  String get createChannelSubmit;

  /// No description provided for @createChannelAvatarUploading.
  ///
  /// In zh, this message translates to:
  /// **'频道头像上传中，请稍候'**
  String get createChannelAvatarUploading;

  /// No description provided for @createChannelNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'频道名称不能为空'**
  String get createChannelNameRequired;

  /// No description provided for @createChannelAvatarRequired.
  ///
  /// In zh, this message translates to:
  /// **'请上传频道头像'**
  String get createChannelAvatarRequired;

  /// No description provided for @createChannelIntroRequired.
  ///
  /// In zh, this message translates to:
  /// **'频道介绍不能为空'**
  String get createChannelIntroRequired;

  /// No description provided for @createChannelAvatarUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'频道头像上传失败：{error}'**
  String createChannelAvatarUploadFailed(String error);

  /// No description provided for @createChannelCreated.
  ///
  /// In zh, this message translates to:
  /// **'频道已创建'**
  String get createChannelCreated;

  /// No description provided for @createChannelFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建频道失败：{error}'**
  String createChannelFailed(String error);

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

  /// No description provided for @channelManageSpeechOwnerReview.
  ///
  /// In zh, this message translates to:
  /// **'频道主审核'**
  String get channelManageSpeechOwnerReview;

  /// No description provided for @channelManageSpeechMembers.
  ///
  /// In zh, this message translates to:
  /// **'成员可发言'**
  String get channelManageSpeechMembers;

  /// No description provided for @channelManageInviteOwner.
  ///
  /// In zh, this message translates to:
  /// **'频道主'**
  String get channelManageInviteOwner;

  /// No description provided for @channelManageInviteMembers.
  ///
  /// In zh, this message translates to:
  /// **'邀请成员'**
  String get channelManageInviteMembers;

  /// No description provided for @channelManageInviteMembersValue.
  ///
  /// In zh, this message translates to:
  /// **'通过 ID 或链接'**
  String get channelManageInviteMembersValue;

  /// No description provided for @channelManageOwnerOnline.
  ///
  /// In zh, this message translates to:
  /// **'所有者 · 在线'**
  String get channelManageOwnerOnline;

  /// No description provided for @channelManageMemberModeration.
  ///
  /// In zh, this message translates to:
  /// **'成员 · 内容审核'**
  String get channelManageMemberModeration;

  /// No description provided for @channelManageMemberOperations.
  ///
  /// In zh, this message translates to:
  /// **'成员 · 运营'**
  String get channelManageMemberOperations;

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
  /// **'检测到外部链接，需要频道主确认后展示。'**
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

  /// No description provided for @loginGettingStartedGuide.
  ///
  /// In zh, this message translates to:
  /// **'入门指南'**
  String get loginGettingStartedGuide;

  /// No description provided for @loginProductOverview.
  ///
  /// In zh, this message translates to:
  /// **'产品概览'**
  String get loginProductOverview;

  /// No description provided for @loginLocalMatrixApiPortHint.
  ///
  /// In zh, this message translates to:
  /// **'本地三节点测试请填写 {recommendedAuthority}'**
  String loginLocalMatrixApiPortHint(String recommendedAuthority);

  /// No description provided for @loginLocalMatrixApiPortError.
  ///
  /// In zh, this message translates to:
  /// **'本地三节点测试请使用 {recommendedAuthority}，不要填写 127.0.0.1 的 Matrix API 端口。'**
  String loginLocalMatrixApiPortError(String recommendedAuthority);

  /// No description provided for @loginGuideIntroPrimary.
  ///
  /// In zh, this message translates to:
  /// **'首次使用前，请准备一个可用的 AI Agent（如 Codex、OpenClaw、Hermes），以及部署所需的云账号和域名。\n将 Direxio 部署技能仓库地址发送给你的 Agent：https://github.com/YingSuiAI/direxio-deployer'**
  String get loginGuideIntroPrimary;

  /// No description provided for @loginGuideIntroSecondary.
  ///
  /// In zh, this message translates to:
  /// **'它会按照标准流程自动完成安装、部署、域名绑定和插件配置。\n部署成功后，Agent 会返回你的 IM 访问地址、初始账号和密码。\n拿到这些信息后，回到本 App 输入服务器地址和密码即可登录。\n官方网站：direxio.ai'**
  String get loginGuideIntroSecondary;

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

  /// No description provided for @agreementTerms.
  ///
  /// In zh, this message translates to:
  /// **'《用户协议》'**
  String get agreementTerms;

  /// No description provided for @agreementPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'《隐私条款》'**
  String get agreementPrivacy;

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

  /// No description provided for @addContactOpenChatMissing.
  ///
  /// In zh, this message translates to:
  /// **'打开聊天失败: 缺少会话信息'**
  String get addContactOpenChatMissing;

  /// No description provided for @addContactChatSyncing.
  ///
  /// In zh, this message translates to:
  /// **'聊天会话同步中，请稍后重试'**
  String get addContactChatSyncing;

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

  /// No description provided for @contactSetRemark.
  ///
  /// In zh, this message translates to:
  /// **'设置备注'**
  String get contactSetRemark;

  /// No description provided for @contactRecommendFriend.
  ///
  /// In zh, this message translates to:
  /// **'推荐给朋友'**
  String get contactRecommendFriend;

  /// No description provided for @contactRecommendHim.
  ///
  /// In zh, this message translates to:
  /// **'把他推荐给朋友'**
  String get contactRecommendHim;

  /// No description provided for @contactSearchChat.
  ///
  /// In zh, this message translates to:
  /// **'搜索聊天'**
  String get contactSearchChat;

  /// No description provided for @contactDeleteFriend.
  ///
  /// In zh, this message translates to:
  /// **'删除好友'**
  String get contactDeleteFriend;

  /// No description provided for @contactBlockUserDetail.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户'**
  String get contactBlockUserDetail;

  /// No description provided for @contactHisChannels.
  ///
  /// In zh, this message translates to:
  /// **'他的频道'**
  String get contactHisChannels;

  /// No description provided for @contactChannelsLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载频道'**
  String get contactChannelsLoading;

  /// No description provided for @contactChannelsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'频道加载失败'**
  String get contactChannelsLoadFailed;

  /// No description provided for @contactChannelsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道'**
  String get contactChannelsEmpty;

  /// No description provided for @contactChannelsUnnamed.
  ///
  /// In zh, this message translates to:
  /// **'未命名频道'**
  String get contactChannelsUnnamed;

  /// No description provided for @contactChannelsPostTag.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get contactChannelsPostTag;

  /// No description provided for @contactChannelsTextTag.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get contactChannelsTextTag;

  /// No description provided for @contactAddFriend.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get contactAddFriend;

  /// No description provided for @contactSupportManager.
  ///
  /// In zh, this message translates to:
  /// **'客服经理'**
  String get contactSupportManager;

  /// No description provided for @contactRoomMissingSearch.
  ///
  /// In zh, this message translates to:
  /// **'缺少联系人房间信息，无法搜索聊天'**
  String get contactRoomMissingSearch;

  /// No description provided for @contactRoomMissingBlock.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户失败: 缺少联系人房间信息'**
  String get contactRoomMissingBlock;

  /// No description provided for @contactRoomMissingDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除好友失败: 缺少联系人房间信息'**
  String get contactRoomMissingDelete;

  /// No description provided for @contactRoomMissingRemark.
  ///
  /// In zh, this message translates to:
  /// **'缺少联系人房间信息，无法保存备注'**
  String get contactRoomMissingRemark;

  /// No description provided for @chatInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'聊天信息'**
  String get chatInfoTitle;

  /// No description provided for @chatInfoMissingConversation.
  ///
  /// In zh, this message translates to:
  /// **'会话不存在'**
  String get chatInfoMissingConversation;

  /// No description provided for @chatInfoSearchRecords.
  ///
  /// In zh, this message translates to:
  /// **'搜索聊天记录'**
  String get chatInfoSearchRecords;

  /// No description provided for @roomSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'查找聊天记录'**
  String get roomSearchTitle;

  /// No description provided for @roomSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索当前会话'**
  String get roomSearchHint;

  /// No description provided for @roomSearchEmptyPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索当前会话'**
  String get roomSearchEmptyPrompt;

  /// No description provided for @roomSearchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到包含「{query}」的消息'**
  String roomSearchNoResults(String query);

  /// No description provided for @roomSearchMessageFallback.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get roomSearchMessageFallback;

  /// No description provided for @chatInfoContactMissingRemark.
  ///
  /// In zh, this message translates to:
  /// **'缺少联系人信息，无法设置备注'**
  String get chatInfoContactMissingRemark;

  /// No description provided for @chatInfoSelfBlockDisabled.
  ///
  /// In zh, this message translates to:
  /// **'当前用户无法拉黑'**
  String get chatInfoSelfBlockDisabled;

  /// No description provided for @chatInfoSelfReportDisabled.
  ///
  /// In zh, this message translates to:
  /// **'当前用户无法举报'**
  String get chatInfoSelfReportDisabled;

  /// No description provided for @chatInfoClearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录'**
  String get chatInfoClearHistory;

  /// No description provided for @chatInfoClearHistoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空所有聊天记录？该操作不可恢复。'**
  String get chatInfoClearHistoryConfirm;

  /// No description provided for @chatInfoClearHistoryAction.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get chatInfoClearHistoryAction;

  /// No description provided for @chatInfoClearHistoryCleared.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录已清空'**
  String get chatInfoClearHistoryCleared;

  /// No description provided for @chatInfoClearHistoryFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录失败: {error}'**
  String chatInfoClearHistoryFailed(String error);

  /// No description provided for @chatInfoUidCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 UID'**
  String get chatInfoUidCopied;

  /// No description provided for @chatInfoContactSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步联系人信息'**
  String get chatInfoContactSyncing;

  /// No description provided for @groupInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'聊天信息({count})'**
  String groupInfoTitle(int count);

  /// No description provided for @groupInfoInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请'**
  String get groupInfoInvite;

  /// No description provided for @groupInfoRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get groupInfoRemove;

  /// No description provided for @groupInfoManagement.
  ///
  /// In zh, this message translates to:
  /// **'群管理'**
  String get groupInfoManagement;

  /// No description provided for @groupInfoSearchRecords.
  ///
  /// In zh, this message translates to:
  /// **'查找聊天记录'**
  String get groupInfoSearchRecords;

  /// No description provided for @groupInfoPinChat.
  ///
  /// In zh, this message translates to:
  /// **'置顶聊天'**
  String get groupInfoPinChat;

  /// No description provided for @groupInfoMyNickname.
  ///
  /// In zh, this message translates to:
  /// **'我在本群昵称'**
  String get groupInfoMyNickname;

  /// No description provided for @groupInfoShowMemberNicknames.
  ///
  /// In zh, this message translates to:
  /// **'显示群成员昵称'**
  String get groupInfoShowMemberNicknames;

  /// No description provided for @groupInfoReportGroup.
  ///
  /// In zh, this message translates to:
  /// **'举报群聊'**
  String get groupInfoReportGroup;

  /// No description provided for @groupInfoDissolveGroup.
  ///
  /// In zh, this message translates to:
  /// **'解散群聊'**
  String get groupInfoDissolveGroup;

  /// No description provided for @groupInfoLeaveGroup.
  ///
  /// In zh, this message translates to:
  /// **'退出群聊'**
  String get groupInfoLeaveGroup;

  /// No description provided for @groupInfoNoRemovableMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂无可移除成员'**
  String get groupInfoNoRemovableMembers;

  /// No description provided for @groupInfoRemoveMemberTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除成员'**
  String get groupInfoRemoveMemberTitle;

  /// No description provided for @groupInfoRemoveMemberConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定将 {name} 移出群聊吗？'**
  String groupInfoRemoveMemberConfirm(String name);

  /// No description provided for @groupInfoMemberRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已移除{name}'**
  String groupInfoMemberRemoved(String name);

  /// No description provided for @groupInfoRemoveMemberFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除成员失败: {error}'**
  String groupInfoRemoveMemberFailed(String error);

  /// No description provided for @groupInfoRemarkTitle.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get groupInfoRemarkTitle;

  /// No description provided for @groupInfoRemarkHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群聊备注'**
  String get groupInfoRemarkHint;

  /// No description provided for @groupInfoRemarkCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除群聊备注'**
  String get groupInfoRemarkCleared;

  /// No description provided for @groupInfoRemarkUpdated.
  ///
  /// In zh, this message translates to:
  /// **'群聊备注已更新'**
  String get groupInfoRemarkUpdated;

  /// No description provided for @groupInfoNicknameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群昵称'**
  String get groupInfoNicknameHint;

  /// No description provided for @groupInfoNicknameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'群昵称不能为空'**
  String get groupInfoNicknameEmpty;

  /// No description provided for @groupInfoCurrentUserMissing.
  ///
  /// In zh, this message translates to:
  /// **'缺少当前用户信息'**
  String get groupInfoCurrentUserMissing;

  /// No description provided for @groupInfoNicknameUpdated.
  ///
  /// In zh, this message translates to:
  /// **'群昵称已更新'**
  String get groupInfoNicknameUpdated;

  /// No description provided for @groupInfoNicknameUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置群昵称失败: {error}'**
  String groupInfoNicknameUpdateFailed(String error);

  /// No description provided for @groupInfoClearHistoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空当前群聊的所有聊天记录？该操作不可恢复。'**
  String get groupInfoClearHistoryConfirm;

  /// No description provided for @groupInfoDissolveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要解散该群聊吗？'**
  String get groupInfoDissolveConfirm;

  /// No description provided for @groupInfoLeaveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出该群聊吗？'**
  String get groupInfoLeaveConfirm;

  /// No description provided for @groupInfoDissolveAction.
  ///
  /// In zh, this message translates to:
  /// **'解散'**
  String get groupInfoDissolveAction;

  /// No description provided for @groupInfoLeaveAction.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get groupInfoLeaveAction;

  /// No description provided for @groupInfoLeaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'{action}群聊失败: {error}'**
  String groupInfoLeaveFailed(String action, String error);

  /// No description provided for @groupCreateCreated.
  ///
  /// In zh, this message translates to:
  /// **'群聊已创建'**
  String get groupCreateCreated;

  /// No description provided for @groupCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败: {error}'**
  String groupCreateFailed(String error);

  /// No description provided for @groupCreateNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入群聊名称'**
  String get groupCreateNameHint;

  /// No description provided for @groupInviteAddMembersTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加群成员'**
  String get groupInviteAddMembersTitle;

  /// No description provided for @channelInviteAddMembersTitle.
  ///
  /// In zh, this message translates to:
  /// **'邀请频道成员'**
  String get channelInviteAddMembersTitle;

  /// No description provided for @groupInviteNoContacts.
  ///
  /// In zh, this message translates to:
  /// **'暂无可邀请联系人'**
  String get groupInviteNoContacts;

  /// No description provided for @groupInviteSend.
  ///
  /// In zh, this message translates to:
  /// **'发送邀请'**
  String get groupInviteSend;

  /// No description provided for @groupManageNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'群名称'**
  String get groupManageNameTitle;

  /// No description provided for @groupManageNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群名称'**
  String get groupManageNameHint;

  /// No description provided for @groupManageNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'群名称不能为空'**
  String get groupManageNameEmpty;

  /// No description provided for @groupManageNameUpdated.
  ///
  /// In zh, this message translates to:
  /// **'群名称已更新'**
  String get groupManageNameUpdated;

  /// No description provided for @groupManageNameUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改群名称失败: {error}'**
  String groupManageNameUpdateFailed(String error);

  /// No description provided for @groupManageAvatarUpdated.
  ///
  /// In zh, this message translates to:
  /// **'群头像已更新'**
  String get groupManageAvatarUpdated;

  /// No description provided for @groupManageAvatarUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改群头像失败: {error}'**
  String groupManageAvatarUpdateFailed(String error);

  /// No description provided for @groupManageMuteEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启全员禁言'**
  String get groupManageMuteEnabled;

  /// No description provided for @groupManageMuteDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已解除全员禁言'**
  String get groupManageMuteDisabled;

  /// No description provided for @groupManageMuteEnableFailed.
  ///
  /// In zh, this message translates to:
  /// **'开启全员禁言失败: {error}'**
  String groupManageMuteEnableFailed(String error);

  /// No description provided for @groupManageMuteDisableFailed.
  ///
  /// In zh, this message translates to:
  /// **'解除全员禁言失败: {error}'**
  String groupManageMuteDisableFailed(String error);

  /// No description provided for @groupManageInvitePolicyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新添加成员权限'**
  String get groupManageInvitePolicyUpdated;

  /// No description provided for @groupManageInvitePolicyUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新添加成员权限失败: {error}'**
  String groupManageInvitePolicyUpdateFailed(String error);

  /// No description provided for @mcpPolicySaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get mcpPolicySaved;

  /// No description provided for @mcpPolicyRevokeTitle.
  ///
  /// In zh, this message translates to:
  /// **'撤销授权？'**
  String get mcpPolicyRevokeTitle;

  /// No description provided for @mcpPolicyRevokeMessage.
  ///
  /// In zh, this message translates to:
  /// **'Agent 将立即失去全部 MCP 权限。'**
  String get mcpPolicyRevokeMessage;

  /// No description provided for @mcpPolicyBlockedKeywordAdd.
  ///
  /// In zh, this message translates to:
  /// **'+ 添加'**
  String get mcpPolicyBlockedKeywordAdd;

  /// No description provided for @mcpPolicyBlockedKeywordTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加屏蔽关键词'**
  String get mcpPolicyBlockedKeywordTitle;

  /// No description provided for @mcpPolicyBlockedKeywordHint.
  ///
  /// In zh, this message translates to:
  /// **'命中该词的消息将被遮蔽'**
  String get mcpPolicyBlockedKeywordHint;

  /// No description provided for @contactFriendRequestRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复旧会话，可以继续聊天。'**
  String get contactFriendRequestRestored;

  /// No description provided for @contactFriendRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'好友请求已发送，等待对方接受。'**
  String get contactFriendRequestSent;

  /// No description provided for @contactDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除好友'**
  String get contactDeleteConfirmTitle;

  /// No description provided for @contactDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后将不再显示该联系人，会话关系也会同步更新。'**
  String get contactDeleteConfirmBody;

  /// No description provided for @contactDeleteConfirmBodyWithName.
  ///
  /// In zh, this message translates to:
  /// **'删除 {name} 后，双方的私聊关系会解除。'**
  String contactDeleteConfirmBodyWithName(String name);

  /// No description provided for @contactDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get contactDeleteAction;

  /// No description provided for @contactDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除好友'**
  String get contactDeleted;

  /// No description provided for @contactDeletedName.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {name}'**
  String contactDeletedName(String name);

  /// No description provided for @contactApplied.
  ///
  /// In zh, this message translates to:
  /// **'已申请'**
  String get contactApplied;

  /// No description provided for @contactFollowFailed.
  ///
  /// In zh, this message translates to:
  /// **'关注失败: {error}'**
  String contactFollowFailed(String error);

  /// No description provided for @contactUnfollowFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消关注失败: {error}'**
  String contactUnfollowFailed(String error);

  /// No description provided for @contactFriendRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送好友请求失败: {error}'**
  String contactFriendRequestFailed(String error);

  /// No description provided for @contactDeleteMissingRoom.
  ///
  /// In zh, this message translates to:
  /// **'删除好友失败: 缺少联系人房间信息'**
  String get contactDeleteMissingRoom;

  /// No description provided for @contactDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除好友失败: {error}'**
  String contactDeleteFailed(String error);

  /// No description provided for @contactBlockConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户'**
  String get contactBlockConfirmTitle;

  /// No description provided for @contactBlockConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'拉黑后将移除该联系人和会话关系。'**
  String get contactBlockConfirmBody;

  /// No description provided for @contactBlockAction.
  ///
  /// In zh, this message translates to:
  /// **'拉黑'**
  String get contactBlockAction;

  /// No description provided for @contactBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已拉黑用户'**
  String get contactBlocked;

  /// No description provided for @contactBlockFailed.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户失败: {error}'**
  String contactBlockFailed(String error);

  /// No description provided for @contactReportSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'举报已提交'**
  String get contactReportSubmitted;

  /// No description provided for @contactReportSubmitFailed.
  ///
  /// In zh, this message translates to:
  /// **'举报提交失败: {error}'**
  String contactReportSubmitFailed(String error);

  /// No description provided for @reportReasonDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'请选择举报原因'**
  String get reportReasonDialogTitle;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In zh, this message translates to:
  /// **'骚扰/辱骂'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonSpam.
  ///
  /// In zh, this message translates to:
  /// **'垃圾信息/广告'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonSexual.
  ///
  /// In zh, this message translates to:
  /// **'色情/不当内容'**
  String get reportReasonSexual;

  /// No description provided for @reportReasonViolence.
  ///
  /// In zh, this message translates to:
  /// **'暴力内容'**
  String get reportReasonViolence;

  /// No description provided for @reportReasonFraud.
  ///
  /// In zh, this message translates to:
  /// **'欺诈'**
  String get reportReasonFraud;

  /// No description provided for @reportReasonOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get reportReasonOther;

  /// No description provided for @reportReasonOtherHint.
  ///
  /// In zh, this message translates to:
  /// **'请填写举报原因'**
  String get reportReasonOtherHint;

  /// No description provided for @reportReasonPickImages.
  ///
  /// In zh, this message translates to:
  /// **'上传图片'**
  String get reportReasonPickImages;

  /// No description provided for @reportReasonImagesSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择{count}张图片'**
  String reportReasonImagesSelected(int count);

  /// No description provided for @reportReasonPickImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片选择失败: {error}'**
  String reportReasonPickImageFailed(String error);

  /// No description provided for @reportReasonSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get reportReasonSubmit;

  /// No description provided for @contactRemarkEmpty.
  ///
  /// In zh, this message translates to:
  /// **'备注不能为空'**
  String get contactRemarkEmpty;

  /// No description provided for @contactRemarkUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'备注更新失败: {error}'**
  String contactRemarkUpdateFailed(String error);

  /// No description provided for @contactRemarkUpdated.
  ///
  /// In zh, this message translates to:
  /// **'备注已更新'**
  String get contactRemarkUpdated;

  /// No description provided for @contactRemarkHint.
  ///
  /// In zh, this message translates to:
  /// **'输入备注名'**
  String get contactRemarkHint;

  /// No description provided for @contactRemarkSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get contactRemarkSave;

  /// No description provided for @contactShareText.
  ///
  /// In zh, this message translates to:
  /// **'推荐联系人：{name}\n{userId}'**
  String contactShareText(String name, String userId);

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

  /// No description provided for @groupsListSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索群聊'**
  String get groupsListSearchHint;

  /// No description provided for @groupsListSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步群聊'**
  String get groupsListSyncing;

  /// No description provided for @groupsListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有群聊'**
  String get groupsListEmpty;

  /// No description provided for @groupsListNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的群聊'**
  String get groupsListNoMatches;

  /// No description provided for @groupsListOwnerBadge.
  ///
  /// In zh, this message translates to:
  /// **'群主'**
  String get groupsListOwnerBadge;

  /// No description provided for @groupsListYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get groupsListYesterday;

  /// No description provided for @requestsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get requestsSearchHint;

  /// No description provided for @requestsPendingHidden.
  ///
  /// In zh, this message translates to:
  /// **'待接受'**
  String get requestsPendingHidden;

  /// No description provided for @requestsWaitingPeerAccept.
  ///
  /// In zh, this message translates to:
  /// **'等待对方接受'**
  String get requestsWaitingPeerAccept;

  /// No description provided for @requestsRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get requestsRejected;

  /// No description provided for @requestsPeerRejected.
  ///
  /// In zh, this message translates to:
  /// **'对方已拒绝'**
  String get requestsPeerRejected;

  /// No description provided for @requestsAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加'**
  String get requestsAdded;

  /// No description provided for @requestsBecameFriends.
  ///
  /// In zh, this message translates to:
  /// **'已成为朋友'**
  String get requestsBecameFriends;

  /// No description provided for @requestsEmptyPending.
  ///
  /// In zh, this message translates to:
  /// **'暂无好友请求'**
  String get requestsEmptyPending;

  /// No description provided for @requestsEmptyAdded.
  ///
  /// In zh, this message translates to:
  /// **'暂无已添加联系人'**
  String get requestsEmptyAdded;

  /// No description provided for @requestsRequestAsFriend.
  ///
  /// In zh, this message translates to:
  /// **'请求添加你为朋友'**
  String get requestsRequestAsFriend;

  /// No description provided for @requestsMyRequestAsFriend.
  ///
  /// In zh, this message translates to:
  /// **'我:请求添加你为朋友'**
  String get requestsMyRequestAsFriend;

  /// No description provided for @requestsIncomingRequestMessage.
  ///
  /// In zh, this message translates to:
  /// **'请求加为好友'**
  String get requestsIncomingRequestMessage;

  /// No description provided for @requestsFriendNoticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'好友申请'**
  String get requestsFriendNoticeTitle;

  /// No description provided for @requestsFriendNoticeFallback.
  ///
  /// In zh, this message translates to:
  /// **'好友申请通知'**
  String get requestsFriendNoticeFallback;

  /// No description provided for @requestsGroupNoticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊通知'**
  String get requestsGroupNoticeTitle;

  /// No description provided for @requestsGroupNoticeFallback.
  ///
  /// In zh, this message translates to:
  /// **'邀请你加入群聊'**
  String get requestsGroupNoticeFallback;

  /// No description provided for @requestsChannelNoticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道通知'**
  String get requestsChannelNoticeTitle;

  /// No description provided for @requestsChannelNoticeFallback.
  ///
  /// In zh, this message translates to:
  /// **'邀请你加入频道'**
  String get requestsChannelNoticeFallback;

  /// No description provided for @requestsView.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get requestsView;

  /// No description provided for @requestsAccept.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get requestsAccept;

  /// No description provided for @requestsReject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get requestsReject;

  /// No description provided for @requestsCannotIdentifySource.
  ///
  /// In zh, this message translates to:
  /// **'无法识别请求来源'**
  String get requestsCannotIdentifySource;

  /// No description provided for @requestsAcceptSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已接受好友请求'**
  String get requestsAcceptSuccess;

  /// No description provided for @requestsRejectSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝好友请求'**
  String get requestsRejectSuccess;

  /// No description provided for @requestsAcceptFailed.
  ///
  /// In zh, this message translates to:
  /// **'接受失败：{error}'**
  String requestsAcceptFailed(String error);

  /// No description provided for @requestsRejectFailed.
  ///
  /// In zh, this message translates to:
  /// **'拒绝失败：{error}'**
  String requestsRejectFailed(String error);

  /// No description provided for @requestsInvalidDomainInput.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的域名或 Matrix ID'**
  String get requestsInvalidDomainInput;

  /// No description provided for @requestsDomainNotProductUser.
  ///
  /// In zh, this message translates to:
  /// **'该域名不是产品用户'**
  String get requestsDomainNotProductUser;

  /// No description provided for @requestsCannotAddSelf.
  ///
  /// In zh, this message translates to:
  /// **'不能添加自己'**
  String get requestsCannotAddSelf;

  /// No description provided for @requestsAlreadyContact.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已经是联系人'**
  String requestsAlreadyContact(String name);

  /// No description provided for @requestsAlreadySent.
  ///
  /// In zh, this message translates to:
  /// **'已向 {name} 发送过好友请求，等待对方接受'**
  String requestsAlreadySent(String name);

  /// No description provided for @requestsRestoredConversation.
  ///
  /// In zh, this message translates to:
  /// **'已恢复与 {name} 的旧会话'**
  String requestsRestoredConversation(String name);

  /// No description provided for @requestsSentTo.
  ///
  /// In zh, this message translates to:
  /// **'已向 {name} 发送好友请求'**
  String requestsSentTo(String name);

  /// No description provided for @createGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'发起群聊'**
  String get createGroupTitle;

  /// No description provided for @createGroupMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建群聊'**
  String get createGroupMenuTitle;

  /// No description provided for @createGroupSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建群聊'**
  String get createGroupSetupTitle;

  /// No description provided for @createGroupDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get createGroupDone;

  /// No description provided for @createGroupDoneWithCount.
  ///
  /// In zh, this message translates to:
  /// **'完成({count})'**
  String createGroupDoneWithCount(int count);

  /// No description provided for @createGroupSubmit.
  ///
  /// In zh, this message translates to:
  /// **'完成创建'**
  String get createGroupSubmit;

  /// No description provided for @createGroupMembers.
  ///
  /// In zh, this message translates to:
  /// **'群成员'**
  String get createGroupMembers;

  /// No description provided for @createGroupMemberCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}人'**
  String createGroupMemberCount(int count);

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
  /// **'支持扫描用户和群二维码'**
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

  /// No description provided for @groupQrTitle.
  ///
  /// In zh, this message translates to:
  /// **'群二维码'**
  String get groupQrTitle;

  /// No description provided for @groupQrId.
  ///
  /// In zh, this message translates to:
  /// **'ID {roomId}'**
  String groupQrId(String roomId);

  /// No description provided for @groupQrHint.
  ///
  /// In zh, this message translates to:
  /// **'扫一扫上面的二维码图案，加入群聊。'**
  String get groupQrHint;

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
  /// **'已在群聊中'**
  String get groupInviteAlreadyJoined;

  /// No description provided for @groupChatUnknownMember.
  ///
  /// In zh, this message translates to:
  /// **'未知成员'**
  String get groupChatUnknownMember;

  /// No description provided for @groupChatVoiceRecordFailed.
  ///
  /// In zh, this message translates to:
  /// **'语音录制失败：{error}'**
  String groupChatVoiceRecordFailed(String error);

  /// No description provided for @groupChatRecordingTooShort.
  ///
  /// In zh, this message translates to:
  /// **'说话时间太短'**
  String get groupChatRecordingTooShort;

  /// No description provided for @groupChatOriginalMessageUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'原消息暂不可见'**
  String get groupChatOriginalMessageUnavailable;

  /// No description provided for @groupChatOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开失败：{error}'**
  String groupChatOpenFailed(String error);

  /// No description provided for @groupChatPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败：{error}'**
  String groupChatPlaybackFailed(String error);

  /// No description provided for @groupChatDownloadSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存到 Files / Portal App / P2P IM Downloads / {filename}'**
  String groupChatDownloadSaved(String filename);

  /// No description provided for @groupChatDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败：{error}'**
  String groupChatDownloadFailed(String error);

  /// No description provided for @groupChatSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败：{error}'**
  String groupChatSendFailed(String error);

  /// No description provided for @groupChatCannotSendChannel.
  ///
  /// In zh, this message translates to:
  /// **'加入频道后才能发送消息'**
  String get groupChatCannotSendChannel;

  /// No description provided for @groupChatCannotSendGroup.
  ///
  /// In zh, this message translates to:
  /// **'加入群聊后才能发送消息'**
  String get groupChatCannotSendGroup;

  /// No description provided for @groupChatChannel.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get groupChatChannel;

  /// No description provided for @groupChatGroup.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get groupChatGroup;

  /// No description provided for @groupChatMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'{title}不存在'**
  String groupChatMissingTitle(String title);

  /// No description provided for @groupChatRecovering.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复{title}...'**
  String groupChatRecovering(String title);

  /// No description provided for @groupChatSyncTimeout.
  ///
  /// In zh, this message translates to:
  /// **'{title}同步超时，请检查网络后重试'**
  String groupChatSyncTimeout(String title);

  /// No description provided for @groupChatCannotOpen.
  ///
  /// In zh, this message translates to:
  /// **'这个{title}暂时无法打开'**
  String groupChatCannotOpen(String title);

  /// No description provided for @groupChatMemberCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 名成员'**
  String groupChatMemberCount(int count);

  /// No description provided for @groupChatCalling.
  ///
  /// In zh, this message translates to:
  /// **'正在群通话'**
  String get groupChatCalling;

  /// No description provided for @groupChatVoiceCall.
  ///
  /// In zh, this message translates to:
  /// **'语音通话'**
  String get groupChatVoiceCall;

  /// No description provided for @groupChatDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get groupChatDetails;

  /// No description provided for @groupChatEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有消息'**
  String get groupChatEmpty;

  /// No description provided for @groupChatMentionTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒的人'**
  String get groupChatMentionTitle;

  /// No description provided for @groupChatClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get groupChatClose;

  /// No description provided for @groupChatMentionSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索群成员'**
  String get groupChatMentionSearchHint;

  /// No description provided for @groupChatNoMentionMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂无可提醒成员'**
  String get groupChatNoMentionMembers;

  /// No description provided for @groupChatNoMembersFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到成员'**
  String get groupChatNoMembersFound;

  /// No description provided for @groupChatImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get groupChatImage;

  /// No description provided for @groupChatVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get groupChatVideo;

  /// No description provided for @groupChatFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get groupChatFile;

  /// No description provided for @messagePreviewSentImage.
  ///
  /// In zh, this message translates to:
  /// **'发送图片'**
  String get messagePreviewSentImage;

  /// No description provided for @messagePreviewReceivedImage.
  ///
  /// In zh, this message translates to:
  /// **'收到图片'**
  String get messagePreviewReceivedImage;

  /// No description provided for @messagePreviewSentVideo.
  ///
  /// In zh, this message translates to:
  /// **'发送视频'**
  String get messagePreviewSentVideo;

  /// No description provided for @messagePreviewReceivedVideo.
  ///
  /// In zh, this message translates to:
  /// **'收到视频'**
  String get messagePreviewReceivedVideo;

  /// No description provided for @messagePreviewSentFile.
  ///
  /// In zh, this message translates to:
  /// **'发送文件'**
  String get messagePreviewSentFile;

  /// No description provided for @messagePreviewReceivedFile.
  ///
  /// In zh, this message translates to:
  /// **'收到文件'**
  String get messagePreviewReceivedFile;

  /// No description provided for @messagePreviewImageBracket.
  ///
  /// In zh, this message translates to:
  /// **'[图片]'**
  String get messagePreviewImageBracket;

  /// No description provided for @messagePreviewVideoBracket.
  ///
  /// In zh, this message translates to:
  /// **'[视频]'**
  String get messagePreviewVideoBracket;

  /// No description provided for @messagePreviewFileBracket.
  ///
  /// In zh, this message translates to:
  /// **'[文件]'**
  String get messagePreviewFileBracket;

  /// No description provided for @messagePreviewVoiceBracket.
  ///
  /// In zh, this message translates to:
  /// **'[语音]'**
  String get messagePreviewVoiceBracket;

  /// No description provided for @messagePreviewChatRecordBracket.
  ///
  /// In zh, this message translates to:
  /// **'[聊天记录]'**
  String get messagePreviewChatRecordBracket;

  /// No description provided for @messagePreviewChannelBracket.
  ///
  /// In zh, this message translates to:
  /// **'[频道]'**
  String get messagePreviewChannelBracket;

  /// No description provided for @messagePreviewChannelShare.
  ///
  /// In zh, this message translates to:
  /// **'频道分享'**
  String get messagePreviewChannelShare;

  /// No description provided for @messagePreviewGroupInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请加入群聊'**
  String get messagePreviewGroupInvite;

  /// No description provided for @messagePreviewMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messagePreviewMessage;

  /// No description provided for @messagePreviewSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get messagePreviewSendFailed;

  /// No description provided for @messagePreviewCallRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝通话'**
  String get messagePreviewCallRejected;

  /// No description provided for @messagePreviewCallMissed.
  ///
  /// In zh, this message translates to:
  /// **'未接通通话'**
  String get messagePreviewCallMissed;

  /// No description provided for @messagePreviewGroupCall.
  ///
  /// In zh, this message translates to:
  /// **'群通话'**
  String get messagePreviewGroupCall;

  /// No description provided for @messagePreviewCall.
  ///
  /// In zh, this message translates to:
  /// **'通话'**
  String get messagePreviewCall;

  /// No description provided for @messagePreviewChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录'**
  String get messagePreviewChatRecord;

  /// No description provided for @messagePreviewGroupChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'群聊的聊天记录'**
  String get messagePreviewGroupChatRecord;

  /// No description provided for @messagePreviewDirectChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'私聊的聊天记录'**
  String get messagePreviewDirectChatRecord;

  /// No description provided for @messagePreviewChannelChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'频道的聊天记录'**
  String get messagePreviewChannelChatRecord;

  /// No description provided for @messagePreviewAgentChatRecord.
  ///
  /// In zh, this message translates to:
  /// **'Agent 聊天记录'**
  String get messagePreviewAgentChatRecord;

  /// No description provided for @callReady.
  ///
  /// In zh, this message translates to:
  /// **'准备通话'**
  String get callReady;

  /// No description provided for @callCalling.
  ///
  /// In zh, this message translates to:
  /// **'正在呼叫...'**
  String get callCalling;

  /// No description provided for @callInviteVoice.
  ///
  /// In zh, this message translates to:
  /// **'邀请你语音通话'**
  String get callInviteVoice;

  /// No description provided for @callInviteVideo.
  ///
  /// In zh, this message translates to:
  /// **'邀请你视频通话'**
  String get callInviteVideo;

  /// No description provided for @callWaitingAnswer.
  ///
  /// In zh, this message translates to:
  /// **'等待对方接听'**
  String get callWaitingAnswer;

  /// No description provided for @callConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接...'**
  String get callConnecting;

  /// No description provided for @callVideoConnected.
  ///
  /// In zh, this message translates to:
  /// **'视频通话中'**
  String get callVideoConnected;

  /// No description provided for @callVoiceConnected.
  ///
  /// In zh, this message translates to:
  /// **'通话中'**
  String get callVoiceConnected;

  /// No description provided for @callEnded.
  ///
  /// In zh, this message translates to:
  /// **'通话已结束'**
  String get callEnded;

  /// No description provided for @callFailed.
  ///
  /// In zh, this message translates to:
  /// **'通话失败'**
  String get callFailed;

  /// No description provided for @callPeerRejected.
  ///
  /// In zh, this message translates to:
  /// **'对方已拒绝'**
  String get callPeerRejected;

  /// No description provided for @callRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝通话'**
  String get callRejected;

  /// No description provided for @callPeerHungUp.
  ///
  /// In zh, this message translates to:
  /// **'对方已挂断'**
  String get callPeerHungUp;

  /// No description provided for @callMissed.
  ///
  /// In zh, this message translates to:
  /// **'未接听'**
  String get callMissed;

  /// No description provided for @callNoPeer.
  ///
  /// In zh, this message translates to:
  /// **'无法确定通话对象'**
  String get callNoPeer;

  /// No description provided for @callAlreadyActive.
  ///
  /// In zh, this message translates to:
  /// **'已有通话正在进行'**
  String get callAlreadyActive;

  /// No description provided for @callServiceNotReady.
  ///
  /// In zh, this message translates to:
  /// **'通话服务还没有准备好'**
  String get callServiceNotReady;

  /// No description provided for @callStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在发起通话'**
  String get callStarting;

  /// No description provided for @callRoomMissing.
  ///
  /// In zh, this message translates to:
  /// **'通话房间不存在'**
  String get callRoomMissing;

  /// No description provided for @callStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'通话发起失败，请稍后重试'**
  String get callStartFailed;

  /// No description provided for @callOutgoingNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'拨打失败，请检查你的网络或节点后重试'**
  String get callOutgoingNetworkFailed;

  /// No description provided for @callPeerNoResponse.
  ///
  /// In zh, this message translates to:
  /// **'对方暂无响应，已结束拨打'**
  String get callPeerNoResponse;

  /// No description provided for @callNetworkUnstable.
  ///
  /// In zh, this message translates to:
  /// **'网络不稳定'**
  String get callNetworkUnstable;

  /// No description provided for @callInterrupted.
  ///
  /// In zh, this message translates to:
  /// **'通话中断'**
  String get callInterrupted;

  /// No description provided for @callMediaPermissionVideo.
  ///
  /// In zh, this message translates to:
  /// **'无法使用摄像头或麦克风，请检查权限'**
  String get callMediaPermissionVideo;

  /// No description provided for @callMediaPermissionVoice.
  ///
  /// In zh, this message translates to:
  /// **'无法使用麦克风，请检查权限'**
  String get callMediaPermissionVoice;

  /// No description provided for @callPeerBusy.
  ///
  /// In zh, this message translates to:
  /// **'对方正在通话中'**
  String get callPeerBusy;

  /// No description provided for @callMinimize.
  ///
  /// In zh, this message translates to:
  /// **'小窗'**
  String get callMinimize;

  /// No description provided for @callMiniRestore.
  ///
  /// In zh, this message translates to:
  /// **'返回通话'**
  String get callMiniRestore;

  /// No description provided for @callCameraOn.
  ///
  /// In zh, this message translates to:
  /// **'开摄像头'**
  String get callCameraOn;

  /// No description provided for @callCameraOff.
  ///
  /// In zh, this message translates to:
  /// **'关摄像头'**
  String get callCameraOff;

  /// No description provided for @callCameraOffState.
  ///
  /// In zh, this message translates to:
  /// **'摄像头已关'**
  String get callCameraOffState;

  /// No description provided for @callCameraStarting.
  ///
  /// In zh, this message translates to:
  /// **'摄像头打开中'**
  String get callCameraStarting;

  /// No description provided for @callRemoteCameraUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'对方摄像头不可用'**
  String get callRemoteCameraUnavailable;

  /// No description provided for @callWaitingRemoteVideo.
  ///
  /// In zh, this message translates to:
  /// **'等待对方画面'**
  String get callWaitingRemoteVideo;

  /// No description provided for @callSpeaker.
  ///
  /// In zh, this message translates to:
  /// **'扬声器'**
  String get callSpeaker;

  /// No description provided for @callEarpiece.
  ///
  /// In zh, this message translates to:
  /// **'听筒'**
  String get callEarpiece;

  /// No description provided for @callEncrypted.
  ///
  /// In zh, this message translates to:
  /// **'端到端加密'**
  String get callEncrypted;

  /// No description provided for @callReject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get callReject;

  /// No description provided for @callAnswer.
  ///
  /// In zh, this message translates to:
  /// **'接听'**
  String get callAnswer;

  /// No description provided for @callMuted.
  ///
  /// In zh, this message translates to:
  /// **'已静音'**
  String get callMuted;

  /// No description provided for @callMute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get callMute;

  /// No description provided for @callUnmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get callUnmute;

  /// No description provided for @callHangup.
  ///
  /// In zh, this message translates to:
  /// **'挂断'**
  String get callHangup;

  /// No description provided for @groupCallTitleVoice.
  ///
  /// In zh, this message translates to:
  /// **'群语音通话'**
  String get groupCallTitleVoice;

  /// No description provided for @groupCallTitleVideo.
  ///
  /// In zh, this message translates to:
  /// **'群视频通话'**
  String get groupCallTitleVideo;

  /// No description provided for @groupCallInviteVoice.
  ///
  /// In zh, this message translates to:
  /// **'邀请你加入群语音通话'**
  String get groupCallInviteVoice;

  /// No description provided for @groupCallInviteVideo.
  ///
  /// In zh, this message translates to:
  /// **'邀请你加入群视频通话'**
  String get groupCallInviteVideo;

  /// No description provided for @groupCallJoiningVoice.
  ///
  /// In zh, this message translates to:
  /// **'正在进入群语音通话'**
  String get groupCallJoiningVoice;

  /// No description provided for @groupCallJoiningVideo.
  ///
  /// In zh, this message translates to:
  /// **'正在进入群视频通话'**
  String get groupCallJoiningVideo;

  /// No description provided for @groupCallConnectedVoice.
  ///
  /// In zh, this message translates to:
  /// **'群语音通话中'**
  String get groupCallConnectedVoice;

  /// No description provided for @groupCallConnectedVideo.
  ///
  /// In zh, this message translates to:
  /// **'群视频通话中'**
  String get groupCallConnectedVideo;

  /// No description provided for @groupCallEnded.
  ///
  /// In zh, this message translates to:
  /// **'群通话已结束'**
  String get groupCallEnded;

  /// No description provided for @groupCallFailed.
  ///
  /// In zh, this message translates to:
  /// **'群通话失败'**
  String get groupCallFailed;

  /// No description provided for @groupCallNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'群通话发起失败，请检查网络或节点后重试'**
  String get groupCallNetworkFailed;

  /// No description provided for @groupCallRoomMissing.
  ///
  /// In zh, this message translates to:
  /// **'群聊不存在'**
  String get groupCallRoomMissing;

  /// No description provided for @groupCallUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'该群暂不支持群通话'**
  String get groupCallUnsupported;

  /// No description provided for @groupCallCameraUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'摄像头不可用'**
  String get groupCallCameraUnavailable;

  /// No description provided for @groupCallWaitingVideo.
  ///
  /// In zh, this message translates to:
  /// **'等待视频画面'**
  String get groupCallWaitingVideo;

  /// No description provided for @groupCallWaitingMembersVideo.
  ///
  /// In zh, this message translates to:
  /// **'等待群成员视频画面'**
  String get groupCallWaitingMembersVideo;

  /// No description provided for @groupCallMemberFallback.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get groupCallMemberFallback;

  /// No description provided for @groupCallWaitingMembers.
  ///
  /// In zh, this message translates to:
  /// **'等待成员加入'**
  String get groupCallWaitingMembers;

  /// No description provided for @groupCallParticipantCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人通话中'**
  String groupCallParticipantCount(int count);

  /// No description provided for @groupCallReadyToJoin.
  ///
  /// In zh, this message translates to:
  /// **'准备加入'**
  String get groupCallReadyToJoin;

  /// No description provided for @groupCallBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get groupCallBack;

  /// No description provided for @groupCallJoin.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get groupCallJoin;

  /// No description provided for @groupCallLeave.
  ///
  /// In zh, this message translates to:
  /// **'离开'**
  String get groupCallLeave;

  /// No description provided for @groupCallSelectVideoMembers.
  ///
  /// In zh, this message translates to:
  /// **'选择视频成员'**
  String get groupCallSelectVideoMembers;

  /// No description provided for @groupCallSelectVoiceMembers.
  ///
  /// In zh, this message translates to:
  /// **'选择语音成员'**
  String get groupCallSelectVoiceMembers;

  /// No description provided for @groupCallStartVideo.
  ///
  /// In zh, this message translates to:
  /// **'发起视频通话'**
  String get groupCallStartVideo;

  /// No description provided for @groupCallStartVoice.
  ///
  /// In zh, this message translates to:
  /// **'发起语音通话'**
  String get groupCallStartVoice;

  /// No description provided for @groupCallSelectAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'选择至少 1 名成员发起邀请'**
  String get groupCallSelectAtLeastOne;

  /// No description provided for @groupCallSelectedMembers.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {selected} / {total} 名成员'**
  String groupCallSelectedMembers(int selected, int total);

  /// No description provided for @groupCallNoInviteMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂无可邀请成员'**
  String get groupCallNoInviteMembers;

  /// No description provided for @chatInputVoice.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get chatInputVoice;

  /// No description provided for @chatInputKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'键盘'**
  String get chatInputKeyboard;

  /// No description provided for @chatInputHoldToTalk.
  ///
  /// In zh, this message translates to:
  /// **'按住 说话'**
  String get chatInputHoldToTalk;

  /// No description provided for @chatInputReleaseToSend.
  ///
  /// In zh, this message translates to:
  /// **'松开 发送'**
  String get chatInputReleaseToSend;

  /// No description provided for @chatInputReleaseToCancel.
  ///
  /// In zh, this message translates to:
  /// **'松开 取消'**
  String get chatInputReleaseToCancel;

  /// No description provided for @chatInputReleaseToCancelCompact.
  ///
  /// In zh, this message translates to:
  /// **'松开取消'**
  String get chatInputReleaseToCancelCompact;

  /// No description provided for @chatInputReleaseToSendSwipeCancel.
  ///
  /// In zh, this message translates to:
  /// **'松开发送，上滑取消'**
  String get chatInputReleaseToSendSwipeCancel;

  /// No description provided for @chatInputMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get chatInputMore;

  /// No description provided for @chatAttachmentAlbum.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get chatAttachmentAlbum;

  /// No description provided for @chatAttachmentCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍摄'**
  String get chatAttachmentCamera;

  /// No description provided for @chatAttachmentVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get chatAttachmentVideo;

  /// No description provided for @chatAttachmentLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get chatAttachmentLocation;

  /// No description provided for @chatAttachmentContactCard.
  ///
  /// In zh, this message translates to:
  /// **'个人名片'**
  String get chatAttachmentContactCard;

  /// No description provided for @chatAttachmentFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get chatAttachmentFile;

  /// No description provided for @chatAttachmentNoImageSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择图片'**
  String get chatAttachmentNoImageSelected;

  /// No description provided for @chatAttachmentNoPhotoTaken.
  ///
  /// In zh, this message translates to:
  /// **'未拍摄照片'**
  String get chatAttachmentNoPhotoTaken;

  /// No description provided for @chatAttachmentNoFileSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择文件'**
  String get chatAttachmentNoFileSelected;

  /// No description provided for @chatAttachmentNoVideoSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择视频'**
  String get chatAttachmentNoVideoSelected;

  /// No description provided for @chatMediaPhoto.
  ///
  /// In zh, this message translates to:
  /// **'照片'**
  String get chatMediaPhoto;

  /// No description provided for @chatMediaAudio.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get chatMediaAudio;

  /// No description provided for @chatMediaGeneric.
  ///
  /// In zh, this message translates to:
  /// **'媒体'**
  String get chatMediaGeneric;

  /// No description provided for @chatMediaReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'{label}读取失败，请重新选择'**
  String chatMediaReadFailed(String label);

  /// No description provided for @chatMediaUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'{label}上传失败，请检查网络后重试'**
  String chatMediaUploadFailed(String label);

  /// No description provided for @groupChatLocalMediaMissing.
  ///
  /// In zh, this message translates to:
  /// **'本地原{label}已丢失，请重新选择{label}'**
  String groupChatLocalMediaMissing(String label);

  /// No description provided for @groupChatCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get groupChatCopied;

  /// No description provided for @groupChatDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get groupChatDeleted;

  /// No description provided for @groupChatCannotFavoriteSending.
  ///
  /// In zh, this message translates to:
  /// **'发送中的消息暂不能收藏'**
  String get groupChatCannotFavoriteSending;

  /// No description provided for @groupChatActionAvailableAfterSent.
  ///
  /// In zh, this message translates to:
  /// **'消息发送完成后可使用该操作'**
  String get groupChatActionAvailableAfterSent;

  /// No description provided for @groupChatNoRecallPermission.
  ///
  /// In zh, this message translates to:
  /// **'没有权限撤回该消息'**
  String get groupChatNoRecallPermission;

  /// No description provided for @groupChatRecallTitle.
  ///
  /// In zh, this message translates to:
  /// **'撤回消息'**
  String get groupChatRecallTitle;

  /// No description provided for @groupChatRecallBody.
  ///
  /// In zh, this message translates to:
  /// **'撤回后，群成员也将看不到这条消息。'**
  String get groupChatRecallBody;

  /// No description provided for @groupChatCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get groupChatCancel;

  /// No description provided for @groupChatRecall.
  ///
  /// In zh, this message translates to:
  /// **'撤回'**
  String get groupChatRecall;

  /// No description provided for @groupChatRecalled.
  ///
  /// In zh, this message translates to:
  /// **'消息已撤回'**
  String get groupChatRecalled;

  /// No description provided for @groupChatRecallFailed.
  ///
  /// In zh, this message translates to:
  /// **'撤回消息失败：{error}'**
  String groupChatRecallFailed(String error);

  /// No description provided for @groupChatDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除消息失败：{error}'**
  String groupChatDeleteFailed(String error);

  /// No description provided for @groupChatFavoriting.
  ///
  /// In zh, this message translates to:
  /// **'正在收藏到我的节点…'**
  String get groupChatFavoriting;

  /// No description provided for @groupChatFavorited.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get groupChatFavorited;

  /// No description provided for @groupChatFavoriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'收藏失败：{error}'**
  String groupChatFavoriteFailed(String error);

  /// No description provided for @groupChatForwardedRecord.
  ///
  /// In zh, this message translates to:
  /// **'已转发聊天记录'**
  String get groupChatForwardedRecord;

  /// No description provided for @groupChatForwardFailed.
  ///
  /// In zh, this message translates to:
  /// **'转发失败：{error}'**
  String groupChatForwardFailed(String error);

  /// No description provided for @groupChatCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get groupChatCopy;

  /// No description provided for @groupChatForward.
  ///
  /// In zh, this message translates to:
  /// **'转发'**
  String get groupChatForward;

  /// No description provided for @groupChatFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get groupChatFavorite;

  /// No description provided for @groupChatDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get groupChatDelete;

  /// No description provided for @groupChatMultiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get groupChatMultiSelect;

  /// No description provided for @groupChatQuote.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get groupChatQuote;

  /// No description provided for @groupChatSelectMessage.
  ///
  /// In zh, this message translates to:
  /// **'选择消息'**
  String get groupChatSelectMessage;

  /// No description provided for @groupChatCancelSelectMessage.
  ///
  /// In zh, this message translates to:
  /// **'取消选择消息'**
  String get groupChatCancelSelectMessage;

  /// No description provided for @chatAiSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'AI 建议'**
  String get chatAiSuggestions;

  /// No description provided for @chatRecordForwardTitle.
  ///
  /// In zh, this message translates to:
  /// **'转发聊天记录'**
  String get chatRecordForwardTitle;

  /// No description provided for @chatVideoCannotPlay.
  ///
  /// In zh, this message translates to:
  /// **'该视频无法播放'**
  String get chatVideoCannotPlay;

  /// No description provided for @redPacketMineDetailAction.
  ///
  /// In zh, this message translates to:
  /// **'查看发出详情'**
  String get redPacketMineDetailAction;

  /// No description provided for @redPacketDetailAction.
  ///
  /// In zh, this message translates to:
  /// **'查看领取详情'**
  String get redPacketDetailAction;

  /// No description provided for @redPacketMineDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'发出的红包'**
  String get redPacketMineDetailTitle;

  /// No description provided for @redPacketDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'红包详情'**
  String get redPacketDetailTitle;

  /// No description provided for @groupChatMe.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get groupChatMe;

  /// No description provided for @groupChatMessageFallback.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get groupChatMessageFallback;

  /// No description provided for @chatReplyTo.
  ///
  /// In zh, this message translates to:
  /// **'回复 {sender}'**
  String chatReplyTo(String sender);

  /// No description provided for @groupChatQuotedMessage.
  ///
  /// In zh, this message translates to:
  /// **'引用消息'**
  String get groupChatQuotedMessage;

  /// No description provided for @groupChatRetryFile.
  ///
  /// In zh, this message translates to:
  /// **'重新发送文件'**
  String get groupChatRetryFile;

  /// No description provided for @groupChatRetryMessage.
  ///
  /// In zh, this message translates to:
  /// **'重新发送消息'**
  String get groupChatRetryMessage;

  /// No description provided for @groupChatDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get groupChatDownloading;

  /// No description provided for @groupChatDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get groupChatDownloaded;

  /// No description provided for @groupChatDownloadFile.
  ///
  /// In zh, this message translates to:
  /// **'下载文件'**
  String get groupChatDownloadFile;

  /// No description provided for @groupChatRemovedCannotSend.
  ///
  /// In zh, this message translates to:
  /// **'无法在已退出的群聊中发送消息'**
  String get groupChatRemovedCannotSend;

  /// No description provided for @chatPeerAcceptBeforeSend.
  ///
  /// In zh, this message translates to:
  /// **'对方接受好友请求后才能发送消息'**
  String get chatPeerAcceptBeforeSend;

  /// No description provided for @contactHomeMissing.
  ///
  /// In zh, this message translates to:
  /// **'联系人不存在'**
  String get contactHomeMissing;

  /// No description provided for @chatPeerDeletedContact.
  ///
  /// In zh, this message translates to:
  /// **'对方已删除联系人关系，消息未送达'**
  String get chatPeerDeletedContact;

  /// No description provided for @chatRecallBody.
  ///
  /// In zh, this message translates to:
  /// **'撤回后，对方也将看不到这条消息。'**
  String get chatRecallBody;

  /// No description provided for @chatImageSavedToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'已保存原图到相册'**
  String get chatImageSavedToAlbum;

  /// No description provided for @chatGroupSyncingRetryLater.
  ///
  /// In zh, this message translates to:
  /// **'群聊正在同步，请稍后重试'**
  String get chatGroupSyncingRetryLater;

  /// No description provided for @chatGroupInviteExpired.
  ///
  /// In zh, this message translates to:
  /// **'你未被邀请或邀请已失效'**
  String get chatGroupInviteExpired;

  /// No description provided for @chatJoinGroupFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入群聊失败: {error}'**
  String chatJoinGroupFailed(String error);

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

  /// No description provided for @commonUser.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get commonUser;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号在其他设备登录'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前账号已在其他设备登录。点击确定后请重新手动输入密码登录。'**
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

  /// No description provided for @chatRecordOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开失败：{error}'**
  String chatRecordOpenFailed(String error);

  /// No description provided for @chatRecordSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 条'**
  String chatRecordSelectedCount(int count);

  /// No description provided for @chatRecordMessageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条消息'**
  String chatRecordMessageCount(int count);

  /// No description provided for @chatRecordEmptyDetails.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息详情'**
  String get chatRecordEmptyDetails;

  /// No description provided for @chatVideoSavedToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'已保存原视频到相册'**
  String get chatVideoSavedToAlbum;

  /// No description provided for @chatSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String chatSaveFailed(String error);

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

  /// No description provided for @channelEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有频道'**
  String get channelEmptyTitle;

  /// No description provided for @channelEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'加入或创建频道后会显示在这里'**
  String get channelEmptySubtitle;

  /// No description provided for @channelSyncingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在同步频道'**
  String get channelSyncingTitle;

  /// No description provided for @channelSyncingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请稍候'**
  String get channelSyncingSubtitle;

  /// No description provided for @channelConversationQuoted.
  ///
  /// In zh, this message translates to:
  /// **'已引用'**
  String get channelConversationQuoted;

  /// No description provided for @channelConversationForwardPending.
  ///
  /// In zh, this message translates to:
  /// **'转发功能即将接入频道真实消息'**
  String get channelConversationForwardPending;

  /// No description provided for @channelConversationMultiSelectPending.
  ///
  /// In zh, this message translates to:
  /// **'多选功能即将接入频道真实消息'**
  String get channelConversationMultiSelectPending;

  /// No description provided for @channelMyChannelsTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的频道'**
  String get channelMyChannelsTitle;

  /// No description provided for @channelJoinedSection.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get channelJoinedSection;

  /// No description provided for @channelCreatedSection.
  ///
  /// In zh, this message translates to:
  /// **'我创建'**
  String get channelCreatedSection;

  /// No description provided for @channelCreatedEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无我创建的频道'**
  String get channelCreatedEmptyTitle;

  /// No description provided for @channelJoinedEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无已加入频道'**
  String get channelJoinedEmptyTitle;

  /// No description provided for @channelCreatedEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'创建的频道会显示在这里'**
  String get channelCreatedEmptySubtitle;

  /// No description provided for @channelJoinedEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'加入的频道会显示在这里'**
  String get channelJoinedEmptySubtitle;

  /// No description provided for @channelOpenSyncing.
  ///
  /// In zh, this message translates to:
  /// **'频道正在同步，请稍后重试'**
  String get channelOpenSyncing;

  /// No description provided for @channelDissolved.
  ///
  /// In zh, this message translates to:
  /// **'频道已经解散'**
  String get channelDissolved;

  /// No description provided for @channelKindText.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get channelKindText;

  /// No description provided for @channelKindPost.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get channelKindPost;

  /// No description provided for @channelAvatarFallback.
  ///
  /// In zh, this message translates to:
  /// **'频'**
  String get channelAvatarFallback;

  /// No description provided for @channelMenuPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get channelMenuPin;

  /// No description provided for @channelMenuUnpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get channelMenuUnpin;

  /// No description provided for @channelMenuPinned.
  ///
  /// In zh, this message translates to:
  /// **'已置顶「{name}」'**
  String channelMenuPinned(String name);

  /// No description provided for @channelMenuUnpinned.
  ///
  /// In zh, this message translates to:
  /// **'已取消置顶「{name}」'**
  String channelMenuUnpinned(String name);

  /// No description provided for @channelMenuHide.
  ///
  /// In zh, this message translates to:
  /// **'不显示'**
  String get channelMenuHide;

  /// No description provided for @channelMenuHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏「{name}」'**
  String channelMenuHidden(String name);

  /// No description provided for @channelMenuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除频道'**
  String get channelMenuDelete;

  /// No description provided for @channelMenuDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{name}」'**
  String channelMenuDeleted(String name);

  /// No description provided for @channelTimeMonday.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get channelTimeMonday;

  /// No description provided for @channelTimeTuesday.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get channelTimeTuesday;

  /// No description provided for @channelTimeWednesday.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get channelTimeWednesday;

  /// No description provided for @channelTimeThursday.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get channelTimeThursday;

  /// No description provided for @channelTimeFriday.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get channelTimeFriday;

  /// No description provided for @channelTimeSaturday.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get channelTimeSaturday;

  /// No description provided for @channelTimeSunday.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get channelTimeSunday;

  /// No description provided for @channelInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道信息'**
  String get channelInfoTitle;

  /// No description provided for @channelInfoDetailAction.
  ///
  /// In zh, this message translates to:
  /// **'频道详情'**
  String get channelInfoDetailAction;

  /// No description provided for @channelInfoShareAction.
  ///
  /// In zh, this message translates to:
  /// **'分享频道'**
  String get channelInfoShareAction;

  /// No description provided for @channelInfoReportAction.
  ///
  /// In zh, this message translates to:
  /// **'举报频道'**
  String get channelInfoReportAction;

  /// No description provided for @channelInfoLeaveAction.
  ///
  /// In zh, this message translates to:
  /// **'退出频道'**
  String get channelInfoLeaveAction;

  /// No description provided for @channelInfoDissolveAction.
  ///
  /// In zh, this message translates to:
  /// **'解散频道'**
  String get channelInfoDissolveAction;

  /// No description provided for @channelInfoNoRemovableMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂无可移除成员'**
  String get channelInfoNoRemovableMembers;

  /// No description provided for @channelInfoRemoveMembersTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除频道成员'**
  String get channelInfoRemoveMembersTitle;

  /// No description provided for @channelInfoConfirmRemove.
  ///
  /// In zh, this message translates to:
  /// **'确认移除{name}'**
  String channelInfoConfirmRemove(String name);

  /// No description provided for @channelInfoMemberRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已移除成员'**
  String get channelInfoMemberRemoved;

  /// No description provided for @channelInfoRemoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除失败：{error}'**
  String channelInfoRemoveFailed(String error);

  /// No description provided for @channelInfoMuteAll.
  ///
  /// In zh, this message translates to:
  /// **'全员禁言'**
  String get channelInfoMuteAll;

  /// No description provided for @channelInfoMuteEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启全员禁言'**
  String get channelInfoMuteEnabled;

  /// No description provided for @channelInfoMuteDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已解除全员禁言'**
  String get channelInfoMuteDisabled;

  /// No description provided for @channelInfoMuteEnableFailed.
  ///
  /// In zh, this message translates to:
  /// **'开启全员禁言失败：{error}'**
  String channelInfoMuteEnableFailed(String error);

  /// No description provided for @channelInfoMuteDisableFailed.
  ///
  /// In zh, this message translates to:
  /// **'解除全员禁言失败：{error}'**
  String channelInfoMuteDisableFailed(String error);

  /// No description provided for @channelInfoReportMissingRoom.
  ///
  /// In zh, this message translates to:
  /// **'举报提交失败: 缺少频道房间ID'**
  String get channelInfoReportMissingRoom;

  /// No description provided for @channelInfoReportSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'举报已提交'**
  String get channelInfoReportSubmitted;

  /// No description provided for @channelInfoReportFailed.
  ///
  /// In zh, this message translates to:
  /// **'举报提交失败: {error}'**
  String channelInfoReportFailed(String error);

  /// No description provided for @channelInfoShared.
  ///
  /// In zh, this message translates to:
  /// **'已分享频道'**
  String get channelInfoShared;

  /// No description provided for @channelInfoShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享频道失败：{error}'**
  String channelInfoShareFailed(String error);

  /// No description provided for @channelInfoLeaveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定退出？'**
  String get channelInfoLeaveConfirm;

  /// No description provided for @channelInfoLeft.
  ///
  /// In zh, this message translates to:
  /// **'已退出频道'**
  String get channelInfoLeft;

  /// No description provided for @channelInfoLeaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'退出频道失败：{error}'**
  String channelInfoLeaveFailed(String error);

  /// No description provided for @channelInfoDissolveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定解散？'**
  String get channelInfoDissolveConfirm;

  /// No description provided for @channelInfoDissolved.
  ///
  /// In zh, this message translates to:
  /// **'已解散频道'**
  String get channelInfoDissolved;

  /// No description provided for @channelInfoDissolveFailed.
  ///
  /// In zh, this message translates to:
  /// **'解散频道失败：{error}'**
  String channelInfoDissolveFailed(String error);

  /// No description provided for @channelDetailIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道介绍'**
  String get channelDetailIntroTitle;

  /// No description provided for @channelDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道详情'**
  String get channelDetailTitle;

  /// No description provided for @channelDetailCopiedId.
  ///
  /// In zh, this message translates to:
  /// **'已复制频道 ID'**
  String get channelDetailCopiedId;

  /// No description provided for @channelDetailNoIntro.
  ///
  /// In zh, this message translates to:
  /// **'暂无频道介绍'**
  String get channelDetailNoIntro;

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

  /// No description provided for @channelShareRequested.
  ///
  /// In zh, this message translates to:
  /// **'已申请加入频道'**
  String get channelShareRequested;

  /// No description provided for @channelShareTextType.
  ///
  /// In zh, this message translates to:
  /// **'文字'**
  String get channelShareTextType;

  /// No description provided for @channelShareTargetTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享频道到'**
  String get channelShareTargetTitle;

  /// No description provided for @channelReviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'频道审核'**
  String get channelReviewTitle;

  /// No description provided for @channelReviewLoadFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'审核加载失败'**
  String get channelReviewLoadFailedTitle;

  /// No description provided for @channelReviewLoadFailedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请稍后重试'**
  String get channelReviewLoadFailedSubtitle;

  /// No description provided for @channelReviewEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无加入申请'**
  String get channelReviewEmptyTitle;

  /// No description provided for @channelReviewEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'新的频道加入申请会显示在这里'**
  String get channelReviewEmptySubtitle;

  /// No description provided for @channelReviewUnnamedChannel.
  ///
  /// In zh, this message translates to:
  /// **'未命名频道'**
  String get channelReviewUnnamedChannel;

  /// No description provided for @channelReviewApprove.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get channelReviewApprove;

  /// No description provided for @channelReviewReject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get channelReviewReject;

  /// No description provided for @channelReviewStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'待审核'**
  String get channelReviewStatusPending;

  /// No description provided for @channelReviewStatusApproved.
  ///
  /// In zh, this message translates to:
  /// **'已同意'**
  String get channelReviewStatusApproved;

  /// No description provided for @channelReviewStatusJoining.
  ///
  /// In zh, this message translates to:
  /// **'加入中'**
  String get channelReviewStatusJoining;

  /// No description provided for @channelReviewStatusJoined.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get channelReviewStatusJoined;

  /// No description provided for @channelReviewStatusJoinFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入失败'**
  String get channelReviewStatusJoinFailed;

  /// No description provided for @channelReviewStatusRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get channelReviewStatusRejected;

  /// No description provided for @channelReviewApproveFailed.
  ///
  /// In zh, this message translates to:
  /// **'同意失败：{error}'**
  String channelReviewApproveFailed(String error);

  /// No description provided for @channelReviewRejectFailed.
  ///
  /// In zh, this message translates to:
  /// **'拒绝失败：{error}'**
  String channelReviewRejectFailed(String error);

  /// No description provided for @channelReviewTimeNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get channelReviewTimeNow;

  /// No description provided for @channelReviewTimeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get channelReviewTimeYesterday;

  /// No description provided for @channelSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索频道...'**
  String get channelSearchHint;

  /// No description provided for @channelSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索频道'**
  String get channelSearchTitle;

  /// No description provided for @channelSearchPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入频道名称/ID查找频道'**
  String get channelSearchPrompt;

  /// No description provided for @channelSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败，请稍后重试'**
  String get channelSearchFailed;

  /// No description provided for @channelSearchNetworkHint.
  ///
  /// In zh, this message translates to:
  /// **'请检查网络或目标节点地址'**
  String get channelSearchNetworkHint;

  /// No description provided for @channelSearchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到频道'**
  String get channelSearchNoResults;

  /// No description provided for @channelSearchPrivateHint.
  ///
  /// In zh, this message translates to:
  /// **'私密频道不会出现在搜索结果中，需要通过邀请或分享卡片加入'**
  String get channelSearchPrivateHint;

  /// No description provided for @channelSearchSyncing.
  ///
  /// In zh, this message translates to:
  /// **'频道正在同步，请稍后重试'**
  String get channelSearchSyncing;

  /// No description provided for @channelSearchUnnamed.
  ///
  /// In zh, this message translates to:
  /// **'未命名频道'**
  String get channelSearchUnnamed;

  /// No description provided for @channelSearchPublicChannel.
  ///
  /// In zh, this message translates to:
  /// **'公开频道'**
  String get channelSearchPublicChannel;

  /// No description provided for @channelSearchPublicApproval.
  ///
  /// In zh, this message translates to:
  /// **'公开频道 · 加入需审核'**
  String get channelSearchPublicApproval;

  /// No description provided for @globalSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get globalSearchTitle;

  /// No description provided for @globalSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get globalSearchHint;

  /// No description provided for @globalSearchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到包含「{query}」的内容'**
  String globalSearchNoResults(String query);

  /// No description provided for @globalSearchMessageFallback.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get globalSearchMessageFallback;

  /// No description provided for @globalSearchMessageLabel.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get globalSearchMessageLabel;

  /// No description provided for @globalSearchContactLabel.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get globalSearchContactLabel;

  /// No description provided for @globalSearchGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get globalSearchGroupLabel;

  /// No description provided for @globalSearchChannelLabel.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get globalSearchChannelLabel;

  /// No description provided for @globalSearchChannelDetailPending.
  ///
  /// In zh, this message translates to:
  /// **'频道详情功能待接入'**
  String get globalSearchChannelDetailPending;

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

  /// No description provided for @channelPostNewTextPreview.
  ///
  /// In zh, this message translates to:
  /// **'新文字帖'**
  String get channelPostNewTextPreview;

  /// No description provided for @channelPostNewImagePreview.
  ///
  /// In zh, this message translates to:
  /// **'新图片帖'**
  String get channelPostNewImagePreview;

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
  /// **'官方邮箱：liyananinsh@outlook.com\n\n温馨提示：请在反馈中描述问题发生的页面、操作步骤和设备型号。'**
  String get meHelpFeedbackBody;

  /// No description provided for @meHelpFeedbackHeadline.
  ///
  /// In zh, this message translates to:
  /// **'一起打造更好的\nDirexio'**
  String get meHelpFeedbackHeadline;

  /// No description provided for @meHelpFeedbackPrompt.
  ///
  /// In zh, this message translates to:
  /// **'发现问题或有好想法？'**
  String get meHelpFeedbackPrompt;

  /// No description provided for @meHelpFeedbackContactLine.
  ///
  /// In zh, this message translates to:
  /// **'联系我们：{email}'**
  String meHelpFeedbackContactLine(Object email);

  /// No description provided for @meHelpFeedbackNote.
  ///
  /// In zh, this message translates to:
  /// **'我们会持续根据你的反馈优化产品。'**
  String get meHelpFeedbackNote;

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

  /// No description provided for @meFavoriteImagePreviewUrlMissing.
  ///
  /// In zh, this message translates to:
  /// **'收藏图片地址为空，无法预览'**
  String get meFavoriteImagePreviewUrlMissing;

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

  /// No description provided for @agentChatEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'开始我们的聊天吧'**
  String get agentChatEmptyTitle;

  /// No description provided for @agentChatOfflineReply.
  ///
  /// In zh, this message translates to:
  /// **'目前Agent离线，请耐心等待'**
  String get agentChatOfflineReply;
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
