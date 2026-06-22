// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Direxio';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageDialogTitle => '语言';

  @override
  String get tabChats => '聊天';

  @override
  String get tabContacts => '通讯录';

  @override
  String get tabChannels => '频道';

  @override
  String get tabMe => '我的';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsFollowSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsFavorites => '收藏';

  @override
  String get settingsPrivacySecurity => '隐私与安全';

  @override
  String get settingsBlacklist => '通讯录黑名单';

  @override
  String get settingsChangePassword => '修改密码';

  @override
  String get settingsMessagesNotifications => '消息与通知';

  @override
  String get settingsDoNotDisturb => '勿扰模式';

  @override
  String get settingsMessageSound => '新消息提示音';

  @override
  String get settingsMessageVibration => '新消息震动';

  @override
  String get settingsOther => '其他';

  @override
  String get settingsAboutUs => '关于我们';

  @override
  String get settingsClearChats => '清空聊天记录';

  @override
  String get settingsClearChatsClearing => '正在清空...';

  @override
  String get settingsClearChatsConfirmMessage =>
      '将清空本机聊天记录、未读恢复和媒体缩略图缓存。服务器上的消息不会被删除。';

  @override
  String get settingsClearChatsSuccess => '聊天记录已清空';

  @override
  String get settingsClearChatsFailure => '清空聊天记录失败，请稍后重试';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLogoutConfirmTitle => '退出登录';

  @override
  String get settingsLogoutConfirmMessage => '确定要退出登录吗？';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonShare => '分享';

  @override
  String get aboutWebsite => '官网';

  @override
  String get aboutEmail => '邮箱';

  @override
  String get aboutVersionUpdates => '版本更新';

  @override
  String get channelManageTitle => '频道管理';

  @override
  String get channelManageProfileTitle => '频道资料';

  @override
  String get channelManageMembersTitle => '成员与角色';

  @override
  String get channelManageModerationTitle => '内容审核';

  @override
  String get channelManageTabOverview => '我的频道';

  @override
  String get channelManageTabProfile => '资料权限';

  @override
  String get channelManageTabMembers => '成员角色';

  @override
  String get channelManageTabModeration => '内容审核';

  @override
  String get channelManageStatSubscribers => '订阅人数';

  @override
  String get channelManageStatTodayMessages => '今日消息';

  @override
  String get channelManageStatPending => '待审核';

  @override
  String get channelManageStatAdmins => '管理员';

  @override
  String get channelManageStatNewToday => '今日新增';

  @override
  String get channelManageStatMuted => '禁言中';

  @override
  String get channelManageStatReports => '举报';

  @override
  String get channelManageStatAutoApproved => '自动通过';

  @override
  String get channelManageMyChannels => '我的频道';

  @override
  String get channelManageCreateChannel => '创建新频道';

  @override
  String get channelManageCreateChannelValue => '名称、头像、简介';

  @override
  String get channelManageInviteLinks => '频道邀请链接';

  @override
  String channelManageInviteLinksValue(int count) {
    return '$count 个有效';
  }

  @override
  String get channelManagePermissions => '频道权限';

  @override
  String get channelManageVisibility => '频道可见性';

  @override
  String get channelManageSpeechPermission => '发言权限';

  @override
  String get channelManageInvitePermission => '邀请权限';

  @override
  String get channelManageMessageEncryption => '消息加密';

  @override
  String get channelManageEnabled => '已开启';

  @override
  String get channelManageDisabled => '未开启';

  @override
  String get channelManageDisableChannel => '停用频道';

  @override
  String get channelManageVisibilityPublic => '公开';

  @override
  String get channelManageVisibilityPrivate => '私密';

  @override
  String get channelManageSpeechAdminReview => '管理员审核';

  @override
  String get channelManageSpeechMembers => '成员可发言';

  @override
  String get channelManageInviteAdmin => '管理员';

  @override
  String get channelManageInviteAdmins => '邀请管理员';

  @override
  String get channelManageInviteAdminsValue => '通过 ID 或链接';

  @override
  String get channelManageOwnerOnline => '所有者 · 在线';

  @override
  String get channelManageAdminModeration => '管理员 · 内容审核';

  @override
  String get channelManageAdminOperations => '管理员 · 成员运营';

  @override
  String get channelManageBotRiskControl => '机器人 · 风控';

  @override
  String get channelManageReviewSpeechTitle => '新成员发言申请';

  @override
  String get channelManageReviewSpeechBody => '用户 @ray 申请在公告频道发布节点同步说明。';

  @override
  String get channelManageReviewSpeechTag => '发言';

  @override
  String get channelManageReviewLinkTitle => '链接风险提示';

  @override
  String get channelManageReviewLinkBody => '检测到外部链接，需要管理员确认后展示。';

  @override
  String get channelManageReviewLinkTag => '链接';

  @override
  String get channelManageReviewReportTitle => '举报消息';

  @override
  String get channelManageReviewReportBody => '2 位成员举报该消息包含重复广告内容。';

  @override
  String get channelManageReviewReportTag => '举报';

  @override
  String get channelManageAutoRules => '自动审核规则';

  @override
  String get channelManageAutoRulesValue => '关键词 / 链接 / 频率';

  @override
  String get channelManageEditProfile => '编辑资料';

  @override
  String get channelManageManage => '管理';

  @override
  String get channelManageManaging => '管理中';

  @override
  String get channelManageApprove => '通过';

  @override
  String get channelManageReject => '拒绝';

  @override
  String get channelManageDefaultChannelName => 'P2P Matrix 公告';

  @override
  String get channelManageDefaultChannelDescription => '项目公告、节点状态与版本发布';

  @override
  String channelManageChannelSummary(
      String visibility, String members, int messages) {
    return '$visibility频道 · $members 人 · 今日 $messages 条';
  }

  @override
  String channelManageComingSoon(String label) {
    return '$label 功能待接入';
  }

  @override
  String get loginTitle => 'Portal IM';

  @override
  String get loginSubtitle => '使用你的 Portal 域名和密码进入去中心化通讯空间';

  @override
  String get loginDomainHint => '你的域名';

  @override
  String get loginPasswordHint => '登录密码';

  @override
  String get loginButton => '登录';

  @override
  String get loginButtonLoading => '登录中…';

  @override
  String get loginTermsOpenFailed => '无法打开用户协议与隐私条款';

  @override
  String get loginAgreementRequiredTitle => '请先阅读并同意';

  @override
  String get loginAgreementRequiredMessage => '登录前需要同意用户协议与隐私条款。';

  @override
  String get loginAgreementConfirmAndLogin => '同意并登录';

  @override
  String get agreementPrefix => '阅读并同意';

  @override
  String get agreementTermsPrivacy => '《用户协议&隐私条款》';

  @override
  String get initPasswordTooShort => '密码至少 8 位';

  @override
  String get initPasswordMismatch => '两次输入的密码不一致';

  @override
  String get initPortalDomainHint => 'Portal 域名';

  @override
  String get initDisplayNameHint => '用户昵称';

  @override
  String get initOwnerTokenHint => '长期登录口令';

  @override
  String get initPasswordHint => '登录密码';

  @override
  String get initConfirmOwnerTokenHint => '再次输入长期登录口令';

  @override
  String get initConfirmPasswordHint => '再次输入登录密码';

  @override
  String get initPasswordRule => '密码至少8位';

  @override
  String get initButton => '确认';

  @override
  String get initButtonLoading => '初始化中…';

  @override
  String get initExistingAccountLogin => '已有账号？登录';

  @override
  String get addContactTitle => '添加好友';

  @override
  String get addContactEmptyHint => '输入对方域名查找';

  @override
  String get addContactDomainNotProductUser => '该域名不是产品用户';

  @override
  String get addContactMessageAfterAdding => '添加好友后即可发消息';

  @override
  String get addContactVoiceAfterAdding => '添加好友后即可音频通话';

  @override
  String get addContactVideoAfterAdding => '添加好友后即可视频通话';

  @override
  String get addContactVerificationTitle => '好友验证';

  @override
  String get addContactVerificationMessageTitle => '发送好友申请';

  @override
  String get addContactVerificationSend => '发送申请';

  @override
  String get addContactRequestSent => '好友请求已发送，等待对方接受。';

  @override
  String get addContactCannotAddSelf => '不能添加自己';

  @override
  String addContactRequestFailed(String error) {
    return '发送好友请求失败: $error';
  }

  @override
  String get contactSendMessage => '发消息';

  @override
  String get contactVoiceCall => '音频通话';

  @override
  String get contactVideoCall => '视频通话';

  @override
  String get contactMuteMessages => '消息免打扰';

  @override
  String get contactBlockUser => '屏蔽用户';

  @override
  String get contactReportUser => '举报用户';

  @override
  String get contactReportTodo => '举报功能待接入';

  @override
  String get contactFriendRequested => '已申请';

  @override
  String get contactApplyFriend => '申请好友';

  @override
  String get contactsSearchHint => 'ID/昵称/邮箱';

  @override
  String get contactsNewFriends => '新朋友';

  @override
  String get contactsNewGroup => '新的群聊';

  @override
  String get contactsMyGroups => '我的群组';

  @override
  String get contactsGroups => '群聊';

  @override
  String get contactsFollows => '关注';

  @override
  String get createGroupTitle => '发起群聊';

  @override
  String get createGroupDone => '完成';

  @override
  String get createGroupEmptyTitle => '暂无可邀请联系人';

  @override
  String get createGroupEmptySubtitle => '先添加好友后再发起群聊';

  @override
  String get createGroupNoResultsTitle => '没有找到好友';

  @override
  String get createGroupNoResultsSubtitle => '换个 ID、昵称或邮箱试试';

  @override
  String get createGroupDefaultName => '群聊';

  @override
  String createGroupSingleName(String name) {
    return '$name的群聊';
  }

  @override
  String createGroupMultipleName(String names) {
    return '$names等人的群聊';
  }

  @override
  String contactsCount(int count) {
    return '联系人 ($count)';
  }

  @override
  String get qrInvalidFormat => '无效的二维码格式';

  @override
  String get qrInvalidUser => '无效的用户二维码';

  @override
  String get qrInvalidGroup => '无效的群二维码';

  @override
  String get qrUnsupportedGroup => '暂不支持该群二维码';

  @override
  String get qrScannerInstruction => '将二维码放入框内，即可自动扫描';

  @override
  String get qrScannerSupportUsers => '支持扫描用户二维码';

  @override
  String get meQrTitle => '我的二维码';

  @override
  String get meQrHint => '扫一扫上面的二维码图案，加我为好友。';

  @override
  String get meQrSaveToAlbum => '保存到相册';

  @override
  String get meQrSaving => '保存中...';

  @override
  String get meQrSaveSuccess => '已保存到相册';

  @override
  String get meQrSaveFailed => '保存失败，请检查相册权限';

  @override
  String get meQrSaveTodo => '保存到相册功能待接入';

  @override
  String get meQrUnconnectedDomain => '未连接域名';

  @override
  String get groupInviteTitle => '邀请加入群聊';

  @override
  String groupInviteJoining(String groupName) {
    return '正在加入“$groupName”';
  }

  @override
  String groupInviteBody(String inviter, String groupName) {
    return '$inviter 邀请你加入“$groupName”';
  }

  @override
  String get groupInviteFallbackInviter => '对方';

  @override
  String get groupInviteJoinButton => '加入群聊';

  @override
  String get groupInviteJoiningButton => '加入中…';

  @override
  String get groupInviteAlreadyJoined => '已在群里中';
}
