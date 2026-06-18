// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'P2P-IM';

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
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsFavorites => 'お気に入り';

  @override
  String get settingsPrivacySecurity => 'プライバシーとセキュリティ';

  @override
  String get settingsBlacklist => '連絡先ブラックリスト';

  @override
  String get settingsChangePassword => 'パスワードを変更';

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
  String get settingsClearChatsClearing => '消去中...';

  @override
  String get settingsClearChatsConfirmMessage =>
      'この端末のチャット履歴、未読復元、メディアサムネイルのキャッシュを消去します。サーバー上のメッセージは削除されません。';

  @override
  String get settingsClearChatsSuccess => 'チャット履歴を消去しました';

  @override
  String get settingsClearChatsFailure =>
      'チャット履歴の消去に失敗しました。しばらくしてからもう一度お試しください。';

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
  String get aboutWebsite => '公式サイト';

  @override
  String get aboutEmail => 'メール';

  @override
  String get aboutVersionUpdates => 'バージョン';

  @override
  String get channelManageTitle => 'チャンネル管理';

  @override
  String get channelManageProfileTitle => 'チャンネル情報';

  @override
  String get channelManageMembersTitle => 'メンバーと役割';

  @override
  String get channelManageModerationTitle => 'コンテンツ審査';

  @override
  String get channelManageTabOverview => '自分のチャンネル';

  @override
  String get channelManageTabProfile => '情報権限';

  @override
  String get channelManageTabMembers => 'メンバー役割';

  @override
  String get channelManageTabModeration => '審査';

  @override
  String get channelManageStatSubscribers => '登録者数';

  @override
  String get channelManageStatTodayMessages => '今日のメッセージ';

  @override
  String get channelManageStatPending => '審査待ち';

  @override
  String get channelManageStatAdmins => '管理者';

  @override
  String get channelManageStatNewToday => '今日の新規';

  @override
  String get channelManageStatMuted => 'ミュート中';

  @override
  String get channelManageStatReports => '報告';

  @override
  String get channelManageStatAutoApproved => '自動承認';

  @override
  String get channelManageMyChannels => '自分のチャンネル';

  @override
  String get channelManageCreateChannel => '新しいチャンネルを作成';

  @override
  String get channelManageCreateChannelValue => '名前、アバター、紹介';

  @override
  String get channelManageInviteLinks => '招待リンク';

  @override
  String channelManageInviteLinksValue(int count) {
    return '$count 件有効';
  }

  @override
  String get channelManagePermissions => 'チャンネル権限';

  @override
  String get channelManageVisibility => '公開範囲';

  @override
  String get channelManageSpeechPermission => '投稿権限';

  @override
  String get channelManageInvitePermission => '招待権限';

  @override
  String get channelManageMessageEncryption => 'メッセージ暗号化';

  @override
  String get channelManageEnabled => '有効';

  @override
  String get channelManageDisabled => '無効';

  @override
  String get channelManageDisableChannel => 'チャンネルを無効化';

  @override
  String get channelManageVisibilityPublic => '公開';

  @override
  String get channelManageVisibilityPrivate => '非公開';

  @override
  String get channelManageSpeechAdminReview => '管理者審査';

  @override
  String get channelManageSpeechMembers => 'メンバーが投稿可能';

  @override
  String get channelManageInviteAdmin => '管理者';

  @override
  String get channelManageInviteAdmins => '管理者を招待';

  @override
  String get channelManageInviteAdminsValue => 'ID またはリンクで招待';

  @override
  String get channelManageOwnerOnline => '所有者 · オンライン';

  @override
  String get channelManageAdminModeration => '管理者 · 審査';

  @override
  String get channelManageAdminOperations => '管理者 · 運営';

  @override
  String get channelManageBotRiskControl => 'Bot · リスク管理';

  @override
  String get channelManageReviewSpeechTitle => '新メンバーの投稿申請';

  @override
  String get channelManageReviewSpeechBody =>
      'ユーザー @ray が告知チャンネルにノード同期メモの投稿を申請しました。';

  @override
  String get channelManageReviewSpeechTag => '投稿';

  @override
  String get channelManageReviewLinkTitle => 'リンクリスク警告';

  @override
  String get channelManageReviewLinkBody => '外部リンクが検出されました。表示前に管理者の確認が必要です。';

  @override
  String get channelManageReviewLinkTag => 'リンク';

  @override
  String get channelManageReviewReportTitle => '報告されたメッセージ';

  @override
  String get channelManageReviewReportBody => '2 人のメンバーがこのメッセージを重複広告として報告しました。';

  @override
  String get channelManageReviewReportTag => '報告';

  @override
  String get channelManageAutoRules => '自動審査ルール';

  @override
  String get channelManageAutoRulesValue => 'キーワード / リンク / 頻度';

  @override
  String get channelManageEditProfile => '情報を編集';

  @override
  String get channelManageManage => '管理';

  @override
  String get channelManageManaging => '管理中';

  @override
  String get channelManageApprove => '承認';

  @override
  String get channelManageReject => '拒否';

  @override
  String get channelManageDefaultChannelName => 'P2P Matrix お知らせ';

  @override
  String get channelManageDefaultChannelDescription => 'プロジェクト告知、ノード状態、リリース情報';

  @override
  String channelManageChannelSummary(
      String visibility, String members, int messages) {
    return '$visibilityチャンネル · $members 人 · 今日 $messages 件';
  }

  @override
  String channelManageComingSoon(String label) {
    return '$label機能はまだ接続されていません';
  }

  @override
  String get loginTitle => 'Portal IM';

  @override
  String get loginSubtitle => 'Portal ドメインとパスワードで分散型メッセージに入ります';

  @override
  String get loginDomainHint => 'あなたのドメイン';

  @override
  String get loginPasswordHint => 'パスワード';

  @override
  String get loginButton => 'ログイン';

  @override
  String get loginButtonLoading => 'ログイン中…';

  @override
  String get loginTermsOpenFailed => '利用規約とプライバシーポリシーを開けません';

  @override
  String get agreementPrefix => '確認して同意します';

  @override
  String get agreementTermsPrivacy => '利用規約・プライバシーポリシー';

  @override
  String get initPasswordTooShort => 'パスワードは8文字以上にしてください';

  @override
  String get initPasswordMismatch => '2回入力したパスワードが一致しません';

  @override
  String get initPortalDomainHint => 'Portal ドメイン';

  @override
  String get initDisplayNameHint => '表示名';

  @override
  String get initOwnerTokenHint => '長期ログインパスフレーズ';

  @override
  String get initPasswordHint => 'パスワード';

  @override
  String get initConfirmOwnerTokenHint => '長期ログインパスフレーズを再入力';

  @override
  String get initConfirmPasswordHint => 'パスワードを再入力';

  @override
  String get initPasswordRule => '8文字以上';

  @override
  String get initButton => '確認';

  @override
  String get initButtonLoading => '初期化中…';

  @override
  String get initExistingAccountLogin => 'すでにアカウントをお持ちですか？ログイン';

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
  String get addContactVerificationTitle => '友だち確認';

  @override
  String get addContactVerificationMessageTitle => '友だち申請を送信';

  @override
  String get addContactVerificationSend => '申請を送信';

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
  String get contactsSearchHint => 'ID / ニックネーム / メール';

  @override
  String get contactsNewFriends => '新しい友だち';

  @override
  String get contactsNewGroup => '新しいグループチャット';

  @override
  String get contactsMyGroups => '自分のグループ';

  @override
  String get contactsGroups => 'グループチャット';

  @override
  String get contactsFollows => 'フォロー';

  @override
  String get createGroupTitle => 'グループチャットを開始';

  @override
  String get createGroupDone => '完了';

  @override
  String get createGroupEmptyTitle => '招待できる友だちがいません';

  @override
  String get createGroupEmptySubtitle => '友だちを追加してからグループチャットを開始してください';

  @override
  String get createGroupNoResultsTitle => '友だちが見つかりません';

  @override
  String get createGroupNoResultsSubtitle => '別のID、ニックネーム、メールで試してください';

  @override
  String get createGroupDefaultName => 'グループチャット';

  @override
  String createGroupSingleName(String name) {
    return '$nameのグループチャット';
  }

  @override
  String createGroupMultipleName(String names) {
    return '$namesたちのグループチャット';
  }

  @override
  String contactsCount(int count) {
    return '連絡先 ($count)';
  }

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
  String get meQrSaving => '保存中...';

  @override
  String get meQrSaveSuccess => '写真に保存しました';

  @override
  String get meQrSaveFailed => '保存に失敗しました。写真の権限を確認してください。';

  @override
  String get meQrSaveTodo => '写真への保存機能はまだ接続されていません';

  @override
  String get meQrUnconnectedDomain => '接続済みドメインなし';

  @override
  String get groupInviteTitle => 'グループチャットへの招待';

  @override
  String groupInviteJoining(String groupName) {
    return '「$groupName」に参加中';
  }

  @override
  String groupInviteBody(String inviter, String groupName) {
    return '$inviterが「$groupName」に招待しました';
  }

  @override
  String get groupInviteFallbackInviter => '相手';

  @override
  String get groupInviteJoinButton => '参加';

  @override
  String get groupInviteJoiningButton => '参加中…';

  @override
  String get groupInviteAlreadyJoined => 'すでにこのグループに参加しています';
}
