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
  String get channelSearchHint => '搜索频道...';

  @override
  String get channelSearchTitle => '搜索频道';

  @override
  String get channelSearchPrompt => '输入频道ID查找频道';

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
      '官方邮箱：support@direxio.ai\n\n温馨提示：请在反馈中描述问题发生的页面、操作步骤和设备型号。';

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
