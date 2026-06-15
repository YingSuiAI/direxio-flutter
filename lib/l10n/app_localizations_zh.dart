// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TokLink';

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
  String get tabChats => 'Chats';

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
  String get loginTitle => 'Portal IM';

  @override
  String get loginSubtitle => '使用你的 Portal 域名和密码进入去中心化通讯空间';

  @override
  String get loginDomainHint => 'https://你的域名';

  @override
  String get loginPasswordHint => '登录密码';

  @override
  String get loginButton => '登录';

  @override
  String get loginButtonLoading => '登录中…';

  @override
  String get addContactTitle => '添加好友';

  @override
  String get addContactEmptyHint => '输入对方昵称或 Portal URL 查找';

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
