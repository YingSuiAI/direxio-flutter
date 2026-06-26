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
  String get blacklistRemove => '移除';

  @override
  String blacklistRemovedMessage(String name) {
    return '已移除 $name';
  }

  @override
  String get blacklistEmpty => '暂无黑名单联系人';

  @override
  String get settingsChangePassword => '修改密码';

  @override
  String get changePasswordOldHint => '原密码';

  @override
  String get changePasswordNewHint => '新密码';

  @override
  String get changePasswordConfirmHint => '再次输入新密码';

  @override
  String get changePasswordRule => '密码至少 8 位';

  @override
  String get changePasswordOldTooShort => '原密码至少 8 位';

  @override
  String get changePasswordNewTooShort => '新密码至少 8 位';

  @override
  String get changePasswordMismatch => '两次输入的密码不一致';

  @override
  String get changePasswordSuccess => '密码已修改';

  @override
  String get changePasswordSubmitting => '提交中…';

  @override
  String get changePasswordSubmit => '提交修改';

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
  String get settingsDeactivateLogin => '注销登录';

  @override
  String get settingsDeactivateLoginConfirmTitle => '注销登录';

  @override
  String get settingsDeactivateLoginConfirmMessage => '14天内，只要登录一次账号，注销就会自动取消';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonShare => '分享';

  @override
  String get avatarAdjustTitle => '调整头像';

  @override
  String get avatarAdjustHint => '双指缩放或拖动图片';

  @override
  String get avatarAdjustReset => '重置';

  @override
  String get avatarAdjustDone => '完成';

  @override
  String avatarAdjustUpdateFailed(String error) {
    return '头像更新失败: $error';
  }

  @override
  String get avatarAdjustPreviewNotReady => '头像预览尚未准备好';

  @override
  String get avatarAdjustExportFailed => '头像导出失败';

  @override
  String get profileInfoTitle => '我的信息';

  @override
  String get profileInfoAvatarEdit => '修改';

  @override
  String get profileInfoMatrixSessionMissing => '当前 Matrix 登录态缺失';

  @override
  String profileInfoAvatarUpdateFailed(String error) {
    return '头像更新失败: $error';
  }

  @override
  String get profileInfoNickname => '昵称';

  @override
  String get profileInfoDisplayName => '用户名';

  @override
  String get profileInfoGender => '性别';

  @override
  String get profileInfoGenderMale => '男';

  @override
  String get profileInfoGenderFemale => '女';

  @override
  String get profileInfoGenderUpdated => '性别已更新';

  @override
  String get profileInfoBirthday => '生日';

  @override
  String get profileInfoBirthdayPickerTitle => '选择生日';

  @override
  String get profileInfoBirthdayUpdated => '生日已更新';

  @override
  String get profileInfoEmail => '邮箱';

  @override
  String get profileInfoEmailUpdated => '邮箱已更新';

  @override
  String get profileInfoUnset => '未设置';

  @override
  String get profileInfoUidCopied => '已复制 UID';

  @override
  String profileInfoEditTitle(String field) {
    return '修改$field';
  }

  @override
  String profileInfoInputHint(String field) {
    return '请输入$field';
  }

  @override
  String get profileInfoDisplayNameEmpty => '用户名不能为空';

  @override
  String get profileInfoDisplayNameSystemName => '请设置一个不同于系统账号的用户名';

  @override
  String get profileInfoDisplayNameUpdated => '用户名已更新';

  @override
  String profileInfoFieldUpdateFailed(String field, String error) {
    return '$field更新失败: $error';
  }

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
  String get channelManageStatOwner => '频道主';

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
  String get createChannelTitle => '创建频道';

  @override
  String get createChannelNameTitle => '频道名称';

  @override
  String get createChannelNameHint => '请输入';

  @override
  String get createChannelAvatarTitle => '上传频道头像';

  @override
  String get createChannelAvatarSubtitle => '支持图片上传，作为频道展示头像';

  @override
  String get createChannelTypeTitle => '选择频道类型';

  @override
  String get createChannelTypeText => '文字';

  @override
  String get createChannelTypeTextSubtitle => '成员自由发言';

  @override
  String get createChannelTypePosts => '帖子';

  @override
  String get createChannelTypePostsSubtitle => '帖子与评论';

  @override
  String get createChannelPermissionsTitle => '频道权限';

  @override
  String get createChannelPublicTitle => '是否公开';

  @override
  String get createChannelPublicSubtitle => '关闭后仅通过邀请加入';

  @override
  String get createChannelApprovalTitle => '加入是否需要审核';

  @override
  String get createChannelApprovalSubtitle => '开启后新成员加入前需要频道审核';

  @override
  String get createChannelIntroTitle => '频道介绍';

  @override
  String get createChannelIntroHint => '输入频道介绍...';

  @override
  String get createChannelSubmit => '创建频道';

  @override
  String get createChannelAvatarUploading => '频道头像上传中，请稍候';

  @override
  String get createChannelNameRequired => '频道名称不能为空';

  @override
  String get createChannelAvatarRequired => '请上传频道头像';

  @override
  String get createChannelIntroRequired => '频道介绍不能为空';

  @override
  String createChannelAvatarUploadFailed(String error) {
    return '频道头像上传失败：$error';
  }

  @override
  String get createChannelCreated => '频道已创建';

  @override
  String createChannelFailed(String error) {
    return '创建频道失败：$error';
  }

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
  String get channelManageSpeechOwnerReview => '频道主审核';

  @override
  String get channelManageSpeechMembers => '成员可发言';

  @override
  String get channelManageInviteOwner => '频道主';

  @override
  String get channelManageInviteMembers => '邀请成员';

  @override
  String get channelManageInviteMembersValue => '通过 ID 或链接';

  @override
  String get channelManageOwnerOnline => '所有者 · 在线';

  @override
  String get channelManageMemberModeration => '成员 · 内容审核';

  @override
  String get channelManageMemberOperations => '成员 · 运营';

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
  String get channelManageReviewLinkBody => '检测到外部链接，需要频道主确认后展示。';

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
  String get loginGettingStartedGuide => '入门指南';

  @override
  String get loginProductOverview => '产品概览';

  @override
  String loginLocalMatrixApiPortHint(String recommendedAuthority) {
    return '本地三节点测试请填写 $recommendedAuthority';
  }

  @override
  String loginLocalMatrixApiPortError(String recommendedAuthority) {
    return '本地三节点测试请使用 $recommendedAuthority，不要填写 127.0.0.1 的 Matrix API 端口。';
  }

  @override
  String get loginGuideIntroPrimary =>
      '首次使用前，请准备一个可用的 AI Agent（如 Codex、OpenClaw、Hermes），以及部署所需的云账号和域名。\n将 Direxio 部署技能仓库地址发送给你的 Agent：https://github.com/YingSuiAI/direxio-deployer';

  @override
  String get loginGuideIntroSecondary =>
      '它会按照标准流程自动完成安装、部署、域名绑定和插件配置。\n部署成功后，Agent 会返回你的 IM 访问地址、初始账号和密码。\n拿到这些信息后，回到本 App 输入服务器地址和密码即可登录。\n官方网站：direxio.ai';

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
  String get agreementTerms => '《用户协议》';

  @override
  String get agreementPrivacy => '《隐私条款》';

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
  String get initAvatarRequired => '请设置头像';

  @override
  String get initPortalDomainRequired => '请填写 Portal 域名';

  @override
  String get initDisplayNameRequired => '请填写用户昵称';

  @override
  String get initOwnerTokenRequired => '请填写长期登录口令';

  @override
  String get initConfirmOwnerTokenRequired => '请再次输入长期登录口令';

  @override
  String get setupScanTitle => '扫码添加服务器';

  @override
  String get setupScanHint => '扫描 Portal 设置页上的二维码';

  @override
  String get setupManualEntry => '手动输入';

  @override
  String get setupManualTitle => '手动添加 Portal';

  @override
  String get setupManualPortalLabel => 'Portal URL 或二维码链接';

  @override
  String get setupManualPortalHint => 'p2p-im.com 或 p2pim://setup?...';

  @override
  String get setupManualCodeLabel => '一次性设置码';

  @override
  String get setupManualCodeHint => '8 位小写字母或数字';

  @override
  String get setupManualContinue => '继续';

  @override
  String get setupInvalidCode => '请输入 8 位设置码';

  @override
  String get setupPasswordTitle => '设置登录口令';

  @override
  String get setupPasswordQrCodeWillExpire => '设置后，当前二维码设置码会失效';

  @override
  String get setupPasswordEnterCodeAndPassword => '输入该 Portal 的设置码并设置登录口令';

  @override
  String get setupCodeHint => '设置码';

  @override
  String get setupNewPasswordHint => '新登录口令';

  @override
  String get setupConfirmNewPasswordHint => '再次输入登录口令';

  @override
  String get setupPasswordSaving => '设置中…';

  @override
  String get setupPasswordDone => '完成设置';

  @override
  String get setupPasswordMismatch => '两次输入的口令不一致';

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
  String get contactSetRemark => '设置备注';

  @override
  String get contactRecommendFriend => '推荐给朋友';

  @override
  String get contactRecommendHim => '把他推荐给朋友';

  @override
  String get contactSearchChat => '搜索聊天';

  @override
  String get contactDeleteFriend => '删除好友';

  @override
  String get contactBlockUserDetail => '拉黑用户';

  @override
  String get contactHisChannels => '他的频道';

  @override
  String get contactAddFriend => '添加好友';

  @override
  String get contactSupportManager => '客服经理';

  @override
  String get contactRoomMissingSearch => '缺少联系人房间信息，无法搜索聊天';

  @override
  String get contactRoomMissingBlock => '拉黑用户失败: 缺少联系人房间信息';

  @override
  String get contactRoomMissingDelete => '删除好友失败: 缺少联系人房间信息';

  @override
  String get contactRoomMissingRemark => '缺少联系人房间信息，无法保存备注';

  @override
  String get chatInfoTitle => '聊天信息';

  @override
  String get chatInfoMissingConversation => '会话不存在';

  @override
  String get chatInfoSearchRecords => '搜索聊天记录';

  @override
  String get chatInfoContactMissingRemark => '缺少联系人信息，无法设置备注';

  @override
  String get chatInfoSelfBlockDisabled => '当前用户无法拉黑';

  @override
  String get chatInfoSelfReportDisabled => '当前用户无法举报';

  @override
  String get chatInfoClearHistory => '清空聊天记录';

  @override
  String get chatInfoClearHistoryConfirm => '确定清空所有聊天记录？该操作不可恢复。';

  @override
  String get chatInfoClearHistoryAction => '清空';

  @override
  String get chatInfoClearHistoryCleared => '聊天记录已清空';

  @override
  String chatInfoClearHistoryFailed(String error) {
    return '清空聊天记录失败: $error';
  }

  @override
  String get chatInfoUidCopied => '已复制 UID';

  @override
  String get chatInfoContactSyncing => '正在同步联系人信息';

  @override
  String groupInfoTitle(int count) {
    return '聊天信息($count)';
  }

  @override
  String get groupInfoInvite => '邀请';

  @override
  String get groupInfoRemove => '移除';

  @override
  String get groupInfoManagement => '群管理';

  @override
  String get groupInfoSearchRecords => '查找聊天记录';

  @override
  String get groupInfoPinChat => '置顶聊天';

  @override
  String get groupInfoMyNickname => '我在本群昵称';

  @override
  String get groupInfoShowMemberNicknames => '显示群成员昵称';

  @override
  String get groupInfoReportGroup => '举报群聊';

  @override
  String get groupInfoDissolveGroup => '解散群聊';

  @override
  String get groupInfoLeaveGroup => '退出群聊';

  @override
  String get groupInfoNoRemovableMembers => '暂无可移除成员';

  @override
  String get groupInfoRemoveMemberTitle => '移除成员';

  @override
  String groupInfoRemoveMemberConfirm(String name) {
    return '确定将 $name 移出群聊吗？';
  }

  @override
  String groupInfoMemberRemoved(String name) {
    return '已移除$name';
  }

  @override
  String groupInfoRemoveMemberFailed(String error) {
    return '移除成员失败: $error';
  }

  @override
  String get groupInfoRemarkTitle => '备注';

  @override
  String get groupInfoRemarkHint => '输入群聊备注';

  @override
  String get groupInfoRemarkCleared => '已清除群聊备注';

  @override
  String get groupInfoRemarkUpdated => '群聊备注已更新';

  @override
  String get groupInfoNicknameHint => '输入群昵称';

  @override
  String get groupInfoNicknameEmpty => '群昵称不能为空';

  @override
  String get groupInfoCurrentUserMissing => '缺少当前用户信息';

  @override
  String get groupInfoNicknameUpdated => '群昵称已更新';

  @override
  String groupInfoNicknameUpdateFailed(String error) {
    return '设置群昵称失败: $error';
  }

  @override
  String get groupInfoClearHistoryConfirm => '确定清空当前群聊的所有聊天记录？该操作不可恢复。';

  @override
  String get groupInfoDissolveConfirm => '确定要解散该群聊吗？';

  @override
  String get groupInfoLeaveConfirm => '确定要退出该群聊吗？';

  @override
  String get groupInfoDissolveAction => '解散';

  @override
  String get groupInfoLeaveAction => '退出';

  @override
  String groupInfoLeaveFailed(String action, String error) {
    return '$action群聊失败: $error';
  }

  @override
  String get contactFriendRequestRestored => '已恢复旧会话，可以继续聊天。';

  @override
  String get contactFriendRequestSent => '好友请求已发送，等待对方接受。';

  @override
  String get contactDeleteConfirmTitle => '删除好友';

  @override
  String get contactDeleteConfirmBody => '删除后将不再显示该联系人，会话关系也会同步更新。';

  @override
  String get contactDeleteAction => '删除';

  @override
  String get contactDeleted => '已删除好友';

  @override
  String contactDeleteFailed(String error) {
    return '删除好友失败: $error';
  }

  @override
  String get contactBlockConfirmTitle => '拉黑用户';

  @override
  String get contactBlockConfirmBody => '拉黑后将移除该联系人和会话关系。';

  @override
  String get contactBlockAction => '拉黑';

  @override
  String get contactBlocked => '已拉黑用户';

  @override
  String contactBlockFailed(String error) {
    return '拉黑用户失败: $error';
  }

  @override
  String get contactReportSubmitted => '举报已提交';

  @override
  String contactReportSubmitFailed(String error) {
    return '举报提交失败: $error';
  }

  @override
  String get reportReasonDialogTitle => '请选择举报原因';

  @override
  String get reportReasonHarassment => '骚扰/辱骂';

  @override
  String get reportReasonSpam => '垃圾信息/广告';

  @override
  String get reportReasonSexual => '色情/不当内容';

  @override
  String get reportReasonViolence => '暴力内容';

  @override
  String get reportReasonFraud => '欺诈';

  @override
  String get reportReasonOther => '其他';

  @override
  String get reportReasonOtherHint => '请填写举报原因';

  @override
  String get reportReasonPickImages => '上传图片';

  @override
  String reportReasonImagesSelected(int count) {
    return '已选择$count张图片';
  }

  @override
  String reportReasonPickImageFailed(String error) {
    return '图片选择失败: $error';
  }

  @override
  String get reportReasonSubmit => '提交';

  @override
  String get contactRemarkEmpty => '备注不能为空';

  @override
  String contactRemarkUpdateFailed(String error) {
    return '备注更新失败: $error';
  }

  @override
  String get contactRemarkUpdated => '备注已更新';

  @override
  String get contactRemarkHint => '输入备注名';

  @override
  String get contactRemarkSave => '保存';

  @override
  String contactShareText(String name, String userId) {
    return '推荐联系人：$name\n$userId';
  }

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
  String get groupsListSearchHint => '搜索群聊';

  @override
  String get groupsListSyncing => '正在同步群聊';

  @override
  String get groupsListEmpty => '还没有群聊';

  @override
  String get groupsListNoMatches => '没有匹配的群聊';

  @override
  String get groupsListOwnerBadge => '群主';

  @override
  String get groupsListYesterday => '昨天';

  @override
  String get requestsSearchHint => '搜索';

  @override
  String get requestsPendingHidden => '待接受';

  @override
  String get requestsWaitingPeerAccept => '等待对方接受';

  @override
  String get requestsRejected => '已拒绝';

  @override
  String get requestsPeerRejected => '对方已拒绝';

  @override
  String get requestsAdded => '已添加';

  @override
  String get requestsEmptyPending => '暂无好友请求';

  @override
  String get requestsEmptyAdded => '暂无已添加联系人';

  @override
  String get requestsRequestAsFriend => '请求添加你为朋友';

  @override
  String get requestsMyRequestAsFriend => '我:请求添加你为朋友';

  @override
  String get requestsIncomingRequestMessage => '请求加为好友';

  @override
  String get requestsFriendNoticeTitle => '好友申请';

  @override
  String get requestsFriendNoticeFallback => '好友申请通知';

  @override
  String get requestsChannelNoticeTitle => '频道通知';

  @override
  String get requestsChannelNoticeFallback => '频道通知';

  @override
  String get requestsView => '查看';

  @override
  String get requestsAccept => '接受';

  @override
  String get requestsReject => '拒绝';

  @override
  String get requestsCannotIdentifySource => '无法识别请求来源';

  @override
  String get requestsAcceptSuccess => '已接受好友请求';

  @override
  String get requestsRejectSuccess => '已拒绝好友请求';

  @override
  String requestsAcceptFailed(String error) {
    return '接受失败：$error';
  }

  @override
  String requestsRejectFailed(String error) {
    return '拒绝失败：$error';
  }

  @override
  String get requestsInvalidDomainInput => '请输入有效的域名或 Matrix ID';

  @override
  String get requestsDomainNotProductUser => '该域名不是产品用户';

  @override
  String get requestsCannotAddSelf => '不能添加自己';

  @override
  String requestsAlreadyContact(String name) {
    return '$name 已经是联系人';
  }

  @override
  String requestsAlreadySent(String name) {
    return '已向 $name 发送过好友请求，等待对方接受';
  }

  @override
  String requestsRestoredConversation(String name) {
    return '已恢复与 $name 的旧会话';
  }

  @override
  String requestsSentTo(String name) {
    return '已向 $name 发送好友请求';
  }

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

  @override
  String get groupChatUnknownMember => '未知成员';

  @override
  String groupChatVoiceRecordFailed(String error) {
    return '语音录制失败：$error';
  }

  @override
  String get groupChatRecordingTooShort => '说话时间太短';

  @override
  String get groupChatOriginalMessageUnavailable => '原消息暂不可见';

  @override
  String groupChatOpenFailed(String error) {
    return '打开失败：$error';
  }

  @override
  String groupChatPlaybackFailed(String error) {
    return '播放失败：$error';
  }

  @override
  String groupChatDownloadSaved(String filename) {
    return '已保存到 Files / Portal App / P2P IM Downloads / $filename';
  }

  @override
  String groupChatDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String groupChatSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String get groupChatCannotSendChannel => '加入频道后才能发送消息';

  @override
  String get groupChatCannotSendGroup => '加入群聊后才能发送消息';

  @override
  String get groupChatChannel => '频道';

  @override
  String get groupChatGroup => '群聊';

  @override
  String groupChatMissingTitle(String title) {
    return '$title不存在';
  }

  @override
  String groupChatRecovering(String title) {
    return '正在恢复$title...';
  }

  @override
  String groupChatSyncTimeout(String title) {
    return '$title同步超时，请检查网络后重试';
  }

  @override
  String groupChatCannotOpen(String title) {
    return '这个$title暂时无法打开';
  }

  @override
  String groupChatMemberCount(int count) {
    return '$count 名成员';
  }

  @override
  String get groupChatCalling => '正在群通话';

  @override
  String get groupChatVoiceCall => '语音通话';

  @override
  String get groupChatDetails => '详情';

  @override
  String get groupChatEmpty => '还没有消息';

  @override
  String get groupChatMentionTitle => '选择提醒的人';

  @override
  String get groupChatClose => '关闭';

  @override
  String get groupChatMentionSearchHint => '搜索群成员';

  @override
  String get groupChatNoMentionMembers => '暂无可提醒成员';

  @override
  String get groupChatNoMembersFound => '未找到成员';

  @override
  String get groupChatImage => '图片';

  @override
  String get groupChatVideo => '视频';

  @override
  String get groupChatFile => '文件';

  @override
  String get messagePreviewSentImage => '发送图片';

  @override
  String get messagePreviewReceivedImage => '收到图片';

  @override
  String get messagePreviewSentVideo => '发送视频';

  @override
  String get messagePreviewReceivedVideo => '收到视频';

  @override
  String get messagePreviewSentFile => '发送文件';

  @override
  String get messagePreviewReceivedFile => '收到文件';

  @override
  String get messagePreviewImageBracket => '[图片]';

  @override
  String get messagePreviewVideoBracket => '[视频]';

  @override
  String get messagePreviewFileBracket => '[文件]';

  @override
  String get messagePreviewVoiceBracket => '[语音]';

  @override
  String get messagePreviewChatRecordBracket => '[聊天记录]';

  @override
  String get messagePreviewChannelBracket => '[频道]';

  @override
  String get messagePreviewChannelShare => '频道分享';

  @override
  String get messagePreviewGroupInvite => '邀请加入群聊';

  @override
  String get messagePreviewMessage => '消息';

  @override
  String get messagePreviewSendFailed => '发送失败';

  @override
  String get messagePreviewCallRejected => '已拒绝通话';

  @override
  String get messagePreviewCallMissed => '未接通通话';

  @override
  String get messagePreviewGroupCall => '群通话';

  @override
  String get messagePreviewCall => '通话';

  @override
  String get messagePreviewChatRecord => '聊天记录';

  @override
  String get messagePreviewGroupChatRecord => '群聊的聊天记录';

  @override
  String get messagePreviewDirectChatRecord => '私聊的聊天记录';

  @override
  String get messagePreviewChannelChatRecord => '频道的聊天记录';

  @override
  String get messagePreviewAgentChatRecord => 'Agent 聊天记录';

  @override
  String get callReady => '准备通话';

  @override
  String get callCalling => '正在呼叫...';

  @override
  String get callInviteVoice => '邀请你语音通话';

  @override
  String get callInviteVideo => '邀请你视频通话';

  @override
  String get callWaitingAnswer => '等待对方接听';

  @override
  String get callConnecting => '正在连接...';

  @override
  String get callVideoConnected => '视频通话中';

  @override
  String get callVoiceConnected => '通话中';

  @override
  String get callEnded => '通话已结束';

  @override
  String get callFailed => '通话失败';

  @override
  String get callPeerRejected => '对方已拒绝';

  @override
  String get callRejected => '已拒绝通话';

  @override
  String get callPeerHungUp => '对方已挂断';

  @override
  String get callMissed => '未接听';

  @override
  String get callNoPeer => '无法确定通话对象';

  @override
  String get callAlreadyActive => '已有通话正在进行';

  @override
  String get callServiceNotReady => '通话服务还没有准备好';

  @override
  String get callStarting => '正在发起通话';

  @override
  String get callRoomMissing => '通话房间不存在';

  @override
  String get callStartFailed => '通话发起失败，请稍后重试';

  @override
  String get callOutgoingNetworkFailed => '拨打失败，请检查你的网络或节点后重试';

  @override
  String get callPeerNoResponse => '对方暂无响应，已结束拨打';

  @override
  String get callNetworkUnstable => '网络不稳定';

  @override
  String get callInterrupted => '通话中断';

  @override
  String get callMediaPermissionVideo => '无法使用摄像头或麦克风，请检查权限';

  @override
  String get callMediaPermissionVoice => '无法使用麦克风，请检查权限';

  @override
  String get callPeerBusy => '对方正在通话中';

  @override
  String get callCameraOn => '开摄像头';

  @override
  String get callCameraOff => '关摄像头';

  @override
  String get callCameraOffState => '摄像头已关';

  @override
  String get callCameraStarting => '摄像头打开中';

  @override
  String get callRemoteCameraUnavailable => '对方摄像头不可用';

  @override
  String get callWaitingRemoteVideo => '等待对方画面';

  @override
  String get callSpeaker => '扬声器';

  @override
  String get callEarpiece => '听筒';

  @override
  String get callEncrypted => '端到端加密';

  @override
  String get callReject => '拒绝';

  @override
  String get callAnswer => '接听';

  @override
  String get callMuted => '已静音';

  @override
  String get callMute => '静音';

  @override
  String get callUnmute => '取消静音';

  @override
  String get callHangup => '挂断';

  @override
  String get groupCallTitleVoice => '群语音通话';

  @override
  String get groupCallTitleVideo => '群视频通话';

  @override
  String get groupCallInviteVoice => '邀请你加入群语音通话';

  @override
  String get groupCallInviteVideo => '邀请你加入群视频通话';

  @override
  String get groupCallJoiningVoice => '正在进入群语音通话';

  @override
  String get groupCallJoiningVideo => '正在进入群视频通话';

  @override
  String get groupCallConnectedVoice => '群语音通话中';

  @override
  String get groupCallConnectedVideo => '群视频通话中';

  @override
  String get groupCallEnded => '群通话已结束';

  @override
  String get groupCallFailed => '群通话失败';

  @override
  String get groupCallNetworkFailed => '群通话发起失败，请检查网络或节点后重试';

  @override
  String get groupCallRoomMissing => '群聊不存在';

  @override
  String get groupCallUnsupported => '该群暂不支持群通话';

  @override
  String get groupCallCameraUnavailable => '摄像头不可用';

  @override
  String get groupCallWaitingVideo => '等待视频画面';

  @override
  String get groupCallWaitingMembersVideo => '等待群成员视频画面';

  @override
  String get groupCallMemberFallback => '成员';

  @override
  String get groupCallWaitingMembers => '等待成员加入';

  @override
  String groupCallParticipantCount(int count) {
    return '$count 人通话中';
  }

  @override
  String get groupCallReadyToJoin => '准备加入';

  @override
  String get groupCallBack => '返回';

  @override
  String get groupCallJoin => '加入';

  @override
  String get groupCallLeave => '离开';

  @override
  String get groupCallSelectVideoMembers => '选择视频成员';

  @override
  String get groupCallSelectVoiceMembers => '选择语音成员';

  @override
  String get groupCallStartVideo => '发起视频通话';

  @override
  String get groupCallStartVoice => '发起语音通话';

  @override
  String get groupCallSelectAtLeastOne => '选择至少 1 名成员发起邀请';

  @override
  String groupCallSelectedMembers(int selected, int total) {
    return '已选择 $selected / $total 名成员';
  }

  @override
  String get groupCallNoInviteMembers => '暂无可邀请成员';

  @override
  String get chatInputVoice => '语音';

  @override
  String get chatInputKeyboard => '键盘';

  @override
  String get chatInputHoldToTalk => '按住 说话';

  @override
  String get chatInputReleaseToSend => '松开 发送';

  @override
  String get chatInputReleaseToCancel => '松开 取消';

  @override
  String get chatInputReleaseToCancelCompact => '松开取消';

  @override
  String get chatInputReleaseToSendSwipeCancel => '松开发送，上滑取消';

  @override
  String get chatAttachmentAlbum => '相册';

  @override
  String get chatAttachmentCamera => '拍摄';

  @override
  String get chatAttachmentVideo => '视频';

  @override
  String get chatAttachmentLocation => '位置';

  @override
  String get chatAttachmentContactCard => '个人名片';

  @override
  String get chatAttachmentFile => '文件';

  @override
  String groupChatLocalMediaMissing(String label) {
    return '本地原$label已丢失，请重新选择$label';
  }

  @override
  String get groupChatCopied => '已复制';

  @override
  String get groupChatDeleted => '已删除';

  @override
  String get groupChatCannotFavoriteSending => '发送中的消息暂不能收藏';

  @override
  String get groupChatActionAvailableAfterSent => '消息发送完成后可使用该操作';

  @override
  String get groupChatNoRecallPermission => '没有权限撤回该消息';

  @override
  String get groupChatRecallTitle => '撤回消息';

  @override
  String get groupChatRecallBody => '撤回后，群成员也将看不到这条消息。';

  @override
  String get groupChatCancel => '取消';

  @override
  String get groupChatRecall => '撤回';

  @override
  String get groupChatRecalled => '消息已撤回';

  @override
  String groupChatRecallFailed(String error) {
    return '撤回消息失败：$error';
  }

  @override
  String groupChatDeleteFailed(String error) {
    return '删除消息失败：$error';
  }

  @override
  String get groupChatFavoriting => '正在收藏到我的节点…';

  @override
  String get groupChatFavorited => '已收藏';

  @override
  String groupChatFavoriteFailed(String error) {
    return '收藏失败：$error';
  }

  @override
  String get groupChatForwardedRecord => '已转发聊天记录';

  @override
  String groupChatForwardFailed(String error) {
    return '转发失败：$error';
  }

  @override
  String get groupChatCopy => '复制';

  @override
  String get groupChatForward => '转发';

  @override
  String get groupChatFavorite => '收藏';

  @override
  String get groupChatDelete => '删除';

  @override
  String get groupChatMultiSelect => '多选';

  @override
  String get groupChatQuote => '引用';

  @override
  String get groupChatSelectMessage => '选择消息';

  @override
  String get groupChatCancelSelectMessage => '取消选择消息';

  @override
  String get groupChatMe => '我';

  @override
  String get groupChatMessageFallback => '消息';

  @override
  String get groupChatQuotedMessage => '引用消息';

  @override
  String get groupChatRetryFile => '重新发送文件';

  @override
  String get groupChatRetryMessage => '重新发送消息';

  @override
  String get groupChatDownloading => '下载中';

  @override
  String get groupChatDownloaded => '已下载';

  @override
  String get groupChatDownloadFile => '下载文件';

  @override
  String get groupChatRemovedCannotSend => '无法在已退出的群聊中发送消息';

  @override
  String get commonOk => '确定';

  @override
  String get commonRetry => '重试';

  @override
  String get commonUser => '用户';

  @override
  String get sessionExpiredTitle => '账号在其他设备登录';

  @override
  String get sessionExpiredMessage => '当前账号已在其他设备登录。点击确定后请重新手动输入密码登录。';

  @override
  String get chatRecordForwarded => '已转发聊天记录';

  @override
  String chatRecordForwardFailed(String error) {
    return '转发失败：$error';
  }

  @override
  String get channelFallbackTitle => '频道';

  @override
  String get channelMissingTitle => '频道不存在';

  @override
  String get channelMissingSubtitle => '该频道可能是私密频道、已删除，或目标节点暂时不可达';

  @override
  String get channelNoPublicContentTitle => '还没有公开内容';

  @override
  String get channelNoPublicContentSubtitle => '加入频道后可以查看后续发布内容';

  @override
  String get channelEmptyTitle => '还没有频道';

  @override
  String get channelEmptySubtitle => '加入或创建频道后会显示在这里';

  @override
  String get channelSyncingTitle => '正在同步频道';

  @override
  String get channelSyncingSubtitle => '请稍候';

  @override
  String get channelMyChannelsTitle => '我的频道';

  @override
  String get channelJoinedSection => '已加入';

  @override
  String get channelCreatedSection => '我创建';

  @override
  String get channelCreatedEmptyTitle => '暂无我创建的频道';

  @override
  String get channelJoinedEmptyTitle => '暂无已加入频道';

  @override
  String get channelCreatedEmptySubtitle => '创建的频道会显示在这里';

  @override
  String get channelJoinedEmptySubtitle => '加入的频道会显示在这里';

  @override
  String get channelOpenSyncing => '频道正在同步，请稍后重试';

  @override
  String get channelDissolved => '频道已经解散';

  @override
  String get channelKindText => '文字';

  @override
  String get channelKindPost => '帖子';

  @override
  String get channelAvatarFallback => '频';

  @override
  String get channelMenuPin => '置顶';

  @override
  String get channelMenuUnpin => '取消置顶';

  @override
  String channelMenuPinned(String name) {
    return '已置顶「$name」';
  }

  @override
  String channelMenuUnpinned(String name) {
    return '已取消置顶「$name」';
  }

  @override
  String get channelMenuHide => '不显示';

  @override
  String channelMenuHidden(String name) {
    return '已隐藏「$name」';
  }

  @override
  String get channelMenuDelete => '删除频道';

  @override
  String channelMenuDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String get channelTimeMonday => '周一';

  @override
  String get channelTimeTuesday => '周二';

  @override
  String get channelTimeWednesday => '周三';

  @override
  String get channelTimeThursday => '周四';

  @override
  String get channelTimeFriday => '周五';

  @override
  String get channelTimeSaturday => '周六';

  @override
  String get channelTimeSunday => '周日';

  @override
  String get channelInfoTitle => '频道信息';

  @override
  String get channelInfoDetailAction => '频道详情';

  @override
  String get channelInfoShareAction => '分享频道';

  @override
  String get channelInfoReportAction => '举报频道';

  @override
  String get channelInfoLeaveAction => '退出频道';

  @override
  String get channelInfoDissolveAction => '解散频道';

  @override
  String get channelInfoNoRemovableMembers => '暂无可移除成员';

  @override
  String get channelInfoRemoveMembersTitle => '移除频道成员';

  @override
  String channelInfoConfirmRemove(String name) {
    return '确认移除$name';
  }

  @override
  String get channelInfoMemberRemoved => '已移除成员';

  @override
  String channelInfoRemoveFailed(String error) {
    return '移除失败：$error';
  }

  @override
  String get channelInfoMuteAll => '全员禁言';

  @override
  String get channelInfoMuteEnabled => '已开启全员禁言';

  @override
  String get channelInfoMuteDisabled => '已解除全员禁言';

  @override
  String channelInfoMuteEnableFailed(String error) {
    return '开启全员禁言失败：$error';
  }

  @override
  String channelInfoMuteDisableFailed(String error) {
    return '解除全员禁言失败：$error';
  }

  @override
  String get channelInfoReportMissingRoom => '举报提交失败: 缺少频道房间ID';

  @override
  String get channelInfoReportSubmitted => '举报已提交';

  @override
  String channelInfoReportFailed(String error) {
    return '举报提交失败: $error';
  }

  @override
  String get channelInfoShared => '已分享频道';

  @override
  String channelInfoShareFailed(String error) {
    return '分享频道失败：$error';
  }

  @override
  String get channelInfoLeaveConfirm => '确定退出？';

  @override
  String get channelInfoLeft => '已退出频道';

  @override
  String channelInfoLeaveFailed(String error) {
    return '退出频道失败：$error';
  }

  @override
  String get channelInfoDissolveConfirm => '确定解散？';

  @override
  String get channelInfoDissolved => '已解散频道';

  @override
  String channelInfoDissolveFailed(String error) {
    return '解散频道失败：$error';
  }

  @override
  String get channelDetailIntroTitle => '频道介绍';

  @override
  String get channelDetailTitle => '频道详情';

  @override
  String get channelDetailCopiedId => '已复制频道 ID';

  @override
  String get channelDetailNoIntro => '暂无频道介绍';

  @override
  String channelJoinFailed(String error) {
    return '加入频道失败：$error';
  }

  @override
  String get channelJoinJoined => '已加入';

  @override
  String get channelJoinPending => '待审核';

  @override
  String get channelJoinSyncing => '同步中';

  @override
  String get channelJoinRetry => '重新加入';

  @override
  String get channelJoinApply => '申请加入';

  @override
  String get channelJoinAction => '加入频道';

  @override
  String get channelJoinProcessing => '处理中';

  @override
  String get channelShareRequested => '已申请加入频道';

  @override
  String get channelShareTextType => '文字';

  @override
  String get channelShareTargetTitle => '分享频道到';

  @override
  String get channelReviewTitle => '频道审核';

  @override
  String get channelReviewLoadFailedTitle => '审核加载失败';

  @override
  String get channelReviewLoadFailedSubtitle => '请稍后重试';

  @override
  String get channelReviewEmptyTitle => '暂无加入申请';

  @override
  String get channelReviewEmptySubtitle => '新的频道加入申请会显示在这里';

  @override
  String get channelReviewUnnamedChannel => '未命名频道';

  @override
  String get channelReviewApprove => '通过';

  @override
  String get channelReviewReject => '拒绝';

  @override
  String get channelReviewStatusPending => '待审核';

  @override
  String get channelReviewStatusApproved => '已同意';

  @override
  String get channelReviewStatusJoining => '加入中';

  @override
  String get channelReviewStatusJoined => '已加入';

  @override
  String get channelReviewStatusJoinFailed => '加入失败';

  @override
  String get channelReviewStatusRejected => '已拒绝';

  @override
  String channelReviewApproveFailed(String error) {
    return '同意失败：$error';
  }

  @override
  String channelReviewRejectFailed(String error) {
    return '拒绝失败：$error';
  }

  @override
  String get channelReviewTimeNow => '刚刚';

  @override
  String get channelReviewTimeYesterday => '昨天';

  @override
  String get channelSearchHint => '搜索频道...';

  @override
  String get channelSearchTitle => '搜索频道';

  @override
  String get channelSearchPrompt => '输入频道名称/ID查找频道';

  @override
  String get channelSearchFailed => '搜索失败，请稍后重试';

  @override
  String get channelSearchNetworkHint => '请检查网络或目标节点地址';

  @override
  String get channelSearchNoResults => '没有找到频道';

  @override
  String get channelSearchPrivateHint => '私密频道不会出现在搜索结果中，需要通过邀请或分享卡片加入';

  @override
  String get channelSearchSyncing => '频道正在同步，请稍后重试';

  @override
  String get channelSearchUnnamed => '未命名频道';

  @override
  String get channelSearchPublicChannel => '公开频道';

  @override
  String get channelSearchPublicApproval => '公开频道 · 加入需审核';

  @override
  String get globalSearchTitle => '搜索';

  @override
  String get globalSearchHint => '搜索';

  @override
  String globalSearchNoResults(String query) {
    return '没有找到包含「$query」的内容';
  }

  @override
  String get globalSearchMessageFallback => '消息';

  @override
  String get globalSearchMessageLabel => '消息';

  @override
  String get globalSearchContactLabel => '联系人';

  @override
  String get globalSearchGroupLabel => '群聊';

  @override
  String get globalSearchChannelLabel => '频道';

  @override
  String get globalSearchChannelDetailPending => '频道详情功能待接入';

  @override
  String get channelPostEmptyTitle => '还没有频道内容';

  @override
  String get channelPostEmptySubtitle => '发布后会显示在这里';

  @override
  String get channelPostPublish => '发表';

  @override
  String get channelPostPublishing => '发表中';

  @override
  String get channelPostPlaceholder => '发表帖子...';

  @override
  String channelPostPublishFailed(String error) {
    return '发表失败：$error';
  }

  @override
  String channelPostImageUploadFailed(String error) {
    return '图片上传失败：$error';
  }

  @override
  String get channelPostDeleted => '帖子已删除';

  @override
  String channelPostDeleteFailed(String error) {
    return '删除帖子失败：$error';
  }

  @override
  String get channelPostDeleteTooltip => '删除帖子';

  @override
  String get channelPostType => '帖子';

  @override
  String get channelPostNewTextPreview => '新文字帖';

  @override
  String get channelPostDefaultTitle => '我发布的帖子';

  @override
  String get channelPostExpandMore => '展开更多';

  @override
  String get channelPostCollapse => '收起';

  @override
  String get channelPostCommentHint => '输入评论...';

  @override
  String get channelPostDetailTitle => '帖子详情';

  @override
  String get channelPostCommentLoadFailed => '评论加载失败';

  @override
  String get channelPostNoMoreComments => '没有更多评论';

  @override
  String get channelPostIdCopied => '已复制帖子 ID';

  @override
  String get channelPostReply => '回复';

  @override
  String get channelPostCollapseComments => '收起评论';

  @override
  String channelPostCommentCount(int count) {
    return '共$count条评论';
  }

  @override
  String channelPostViewComments(String countText) {
    return '查看评论$countText';
  }

  @override
  String get channelPostMissingTitle => '帖子不存在';

  @override
  String get channelPostMissingSubtitle => '该帖子可能已删除，或尚未同步到本机。';

  @override
  String get meMenuTitle => '菜单';

  @override
  String get meMyFavorites => '我的收藏';

  @override
  String get meMyLikes => '我的点赞';

  @override
  String get meMyComments => '我的评论';

  @override
  String get meFavoritesTitle => '收藏';

  @override
  String get meLikesTitle => '赞';

  @override
  String get meCommentsTitle => '评论';

  @override
  String get meHelpFeedbackTitle => '帮助与反馈';

  @override
  String get meHelpFeedbackBody =>
      '官方邮箱：liyananinsh@outlook.com\n\n温馨提示：请在反馈中描述问题发生的页面、操作步骤和设备型号。';

  @override
  String get meHelpFeedbackHeadline => '一起打造更好的\nDirexio';

  @override
  String get meHelpFeedbackPrompt => '发现问题或有好想法？';

  @override
  String meHelpFeedbackContactLine(Object email) {
    return '联系我们：$email';
  }

  @override
  String get meHelpFeedbackNote => '我们会持续根据你的反馈优化产品。';

  @override
  String get meHelpFeedbackOk => '知道了';

  @override
  String get meUidCopied => '已复制 UID';

  @override
  String get meFavoriteDetailTitle => '收藏详情';

  @override
  String get meFavoriteDeleteAction => '删除收藏';

  @override
  String get meFavoriteRemoveTitle => '取消收藏';

  @override
  String get meFavoriteDeleteConfirm => '确认删除该收藏吗？';

  @override
  String get meFavoriteDeleted => '已删除收藏';

  @override
  String meFavoriteDeleteFailed(String error) {
    return '删除收藏失败：$error';
  }

  @override
  String get meFavoritesLoadFailed => '收藏加载失败';

  @override
  String get meFavoritesEmptyTitle => '暂无收藏';

  @override
  String get meFavoritesEmptySubtitle => '长按聊天消息收藏后会显示在这里';

  @override
  String get meLikesLoadFailed => '点赞加载失败';

  @override
  String get meLikesEmptyTitle => '暂无点赞';

  @override
  String get meLikesEmptySubtitle => '你点过赞的频道帖子会显示在这里';

  @override
  String get meLikedPost => '你赞了这条帖子';

  @override
  String meReactedWith(String value) {
    return '你回应了：$value';
  }

  @override
  String get meCommentsLoadFailed => '评论加载失败';

  @override
  String get meCommentsEmptyTitle => '暂无评论';

  @override
  String get meCommentsEmptySubtitle => '你在频道帖子下发表过的评论会显示在这里';

  @override
  String get meCommentFallback => '评论';

  @override
  String meCommentedWith(String body) {
    return '你评论了：$body';
  }

  @override
  String get meChannelPostFallback => '频道帖子';

  @override
  String get meFavoriteMessageFallback => '收藏消息';

  @override
  String get meFavoriteUnknownSender => '未知';

  @override
  String get meFavoriteTypeText => '文字';

  @override
  String get meFavoriteTypeImage => '图片';

  @override
  String get meFavoriteTypeVideo => '视频';

  @override
  String get meFavoriteTypeFile => '文件';

  @override
  String get meFavoriteTypeChatRecord => '聊天记录';

  @override
  String get meFavoriteTypeAudio => '语音';

  @override
  String get meFavoriteTypeLink => '链接';

  @override
  String get meFavoriteTypeMessage => '消息';

  @override
  String get meFavoriteFromDirect => '来自私聊';

  @override
  String meFavoriteFromDirectWithSender(String sender) {
    return '来自与 $sender 的私聊';
  }

  @override
  String get meFavoriteFromGroup => '来自群聊';

  @override
  String meFavoriteFromGroupWithSender(String sender) {
    return '来自群聊 · $sender';
  }

  @override
  String get meFavoriteFromChannel => '来自频道';

  @override
  String meFavoriteFromChannelWithSender(String sender) {
    return '来自频道 · $sender';
  }

  @override
  String get meFavoriteFromAgent => '来自 Agent';

  @override
  String get meFavoriteFromChat => '来自聊天';

  @override
  String meFavoriteFromChatWithSender(String sender) {
    return '来自聊天 · $sender';
  }

  @override
  String get meFavoriteDirectChatRecord => '私聊聊天记录';

  @override
  String meFavoriteDirectChatRecordWithName(String name) {
    return '与 $name 的聊天记录';
  }

  @override
  String get meFavoriteGroupChatRecord => '群聊聊天记录';

  @override
  String meFavoriteGroupChatRecordWithName(String name) {
    return '群聊「$name」的聊天记录';
  }

  @override
  String get meFavoriteChannelChatRecord => '频道聊天记录';

  @override
  String meFavoriteChannelChatRecordWithName(String name) {
    return '频道「$name」的聊天记录';
  }

  @override
  String get meFavoriteAgentChatRecord => '与 Agent 的聊天记录';

  @override
  String meFavoriteDetailBody(String title) {
    return '收藏详情\n$title\n共 1 条消息';
  }

  @override
  String get commonMe => '我';

  @override
  String get commonJustNow => '刚刚';

  @override
  String get agentChatEmptyTitle => '开始我们的聊天吧';
}
