// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Direxio';

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
  String get settingsDeactivateLogin => 'ログインを無効化';

  @override
  String get settingsDeactivateLoginConfirmTitle => 'ログインを無効化';

  @override
  String get settingsDeactivateLoginConfirmMessage =>
      '14日以内に一度ログインすると、無効化は自動的にキャンセルされます。';

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
  String get loginAgreementRequiredTitle => '確認して同意してください';

  @override
  String get loginAgreementRequiredMessage =>
      'ログインする前に利用規約とプライバシーポリシーへの同意が必要です。';

  @override
  String get loginAgreementConfirmAndLogin => '同意してログイン';

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
  String get initAvatarRequired => 'アバターを設定してください';

  @override
  String get initPortalDomainRequired => 'Portal ドメインを入力してください';

  @override
  String get initDisplayNameRequired => '表示名を入力してください';

  @override
  String get initOwnerTokenRequired => '長期ログインパスフレーズを入力してください';

  @override
  String get initConfirmOwnerTokenRequired => '長期ログインパスフレーズをもう一度入力してください';

  @override
  String get setupScanTitle => 'スキャンしてサーバーを追加';

  @override
  String get setupScanHint => 'Portal 設定ページの QR コードをスキャンしてください';

  @override
  String get setupManualEntry => '手動入力';

  @override
  String get setupManualTitle => 'Portal を手動で追加';

  @override
  String get setupManualPortalLabel => 'Portal URL または QR リンク';

  @override
  String get setupManualPortalHint => 'p2p-im.com または p2pim://setup?...';

  @override
  String get setupManualCodeLabel => '一回限りの設定コード';

  @override
  String get setupManualCodeHint => '8文字の小文字または数字';

  @override
  String get setupManualContinue => '続ける';

  @override
  String get setupInvalidCode => '8文字の設定コードを入力してください';

  @override
  String get setupPasswordTitle => 'ログインパスフレーズを設定';

  @override
  String get setupPasswordQrCodeWillExpire => '設定後、この QR 設定コードは無効になります';

  @override
  String get setupPasswordEnterCodeAndPassword =>
      'この Portal の設定コードを入力し、ログインパスフレーズを設定してください';

  @override
  String get setupCodeHint => '設定コード';

  @override
  String get setupNewPasswordHint => '新しいログインパスフレーズ';

  @override
  String get setupConfirmNewPasswordHint => 'ログインパスフレーズを再入力';

  @override
  String get setupPasswordSaving => '設定中…';

  @override
  String get setupPasswordDone => '設定を完了';

  @override
  String get setupPasswordMismatch => '2回入力したパスフレーズが一致しません';

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
  String get addContactCannotAddSelf => '自分を追加することはできません';

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

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => '再試行';

  @override
  String get sessionExpiredTitle => '別の端末でログインされました';

  @override
  String get sessionExpiredMessage => 'もう一度ログインしてください';

  @override
  String get chatRecordForwarded => 'チャット履歴を転送しました';

  @override
  String chatRecordForwardFailed(String error) {
    return '転送に失敗しました：$error';
  }

  @override
  String get channelFallbackTitle => 'チャンネル';

  @override
  String get channelMissingTitle => 'チャンネルが見つかりません';

  @override
  String get channelMissingSubtitle =>
      'このチャンネルは非公開、削除済み、または一時的に到達できない可能性があります。';

  @override
  String get channelNoPublicContentTitle => '公開コンテンツはまだありません';

  @override
  String get channelNoPublicContentSubtitle => 'チャンネルに参加すると今後の投稿を確認できます。';

  @override
  String get channelEmptyTitle => 'チャンネルはまだありません';

  @override
  String get channelEmptySubtitle => '参加または作成したチャンネルがここに表示されます。';

  @override
  String channelJoinFailed(String error) {
    return 'チャンネルへの参加に失敗しました：$error';
  }

  @override
  String get channelJoinJoined => '参加済み';

  @override
  String get channelJoinPending => '審査待ち';

  @override
  String get channelJoinSyncing => '同期中';

  @override
  String get channelJoinRetry => '再参加';

  @override
  String get channelJoinApply => '参加申請';

  @override
  String get channelJoinAction => 'チャンネルに参加';

  @override
  String get channelJoinProcessing => '処理中';

  @override
  String get channelPostEmptyTitle => 'チャンネル投稿はまだありません';

  @override
  String get channelPostEmptySubtitle => '投稿するとここに表示されます。';

  @override
  String get channelPostPublish => '投稿';

  @override
  String get channelPostPublishing => '投稿中';

  @override
  String get channelPostPlaceholder => '投稿を書く...';

  @override
  String channelPostPublishFailed(String error) {
    return '投稿に失敗しました：$error';
  }

  @override
  String channelPostImageUploadFailed(String error) {
    return '画像のアップロードに失敗しました：$error';
  }

  @override
  String get channelPostDeleted => '投稿を削除しました';

  @override
  String channelPostDeleteFailed(String error) {
    return '投稿の削除に失敗しました：$error';
  }

  @override
  String get channelPostDeleteTooltip => '投稿を削除';

  @override
  String get channelPostType => '投稿';

  @override
  String get channelPostDefaultTitle => '自分の投稿';

  @override
  String get channelPostExpandMore => 'もっと見る';

  @override
  String get channelPostCollapse => '閉じる';

  @override
  String get channelPostCommentHint => 'コメントを入力...';

  @override
  String get channelPostDetailTitle => '投稿詳細';

  @override
  String get channelPostCommentLoadFailed => 'コメントの読み込みに失敗しました';

  @override
  String get channelPostNoMoreComments => 'これ以上コメントはありません';

  @override
  String get channelPostIdCopied => '投稿 ID をコピーしました';

  @override
  String get channelPostReply => '返信';

  @override
  String get channelPostCollapseComments => 'コメントを閉じる';

  @override
  String channelPostCommentCount(int count) {
    return 'コメント $count 件';
  }

  @override
  String channelPostViewComments(String countText) {
    return 'コメントを見る$countText';
  }

  @override
  String get channelPostMissingTitle => '投稿が見つかりません';

  @override
  String get channelPostMissingSubtitle =>
      'この投稿は削除されたか、この端末にまだ同期されていない可能性があります。';

  @override
  String get meMenuTitle => 'メニュー';

  @override
  String get meMyFavorites => '自分のお気に入り';

  @override
  String get meMyLikes => '自分のいいね';

  @override
  String get meMyComments => '自分のコメント';

  @override
  String get meFavoritesTitle => 'お気に入り';

  @override
  String get meLikesTitle => 'いいね';

  @override
  String get meCommentsTitle => 'コメント';

  @override
  String get meHelpFeedbackTitle => 'ヘルプとフィードバック';

  @override
  String get meHelpFeedbackBody =>
      '公式メール：support@direxio.ai\n\nヒント：フィードバックには問題が発生したページ、操作手順、端末モデルを記載してください。';

  @override
  String get meHelpFeedbackOk => '了解';

  @override
  String get meUidCopied => 'UID をコピーしました';

  @override
  String get meFavoriteDetailTitle => 'お気に入り詳細';

  @override
  String get meFavoriteDeleteAction => 'お気に入りを削除';

  @override
  String get meFavoriteRemoveTitle => 'お気に入りを解除';

  @override
  String get meFavoriteDeleteConfirm => 'このお気に入りを削除しますか？';

  @override
  String get meFavoriteDeleted => 'お気に入りを削除しました';

  @override
  String meFavoriteDeleteFailed(String error) {
    return 'お気に入りの削除に失敗しました：$error';
  }

  @override
  String get meFavoritesLoadFailed => 'お気に入りの読み込みに失敗しました';

  @override
  String get meFavoritesEmptyTitle => 'お気に入りはまだありません';

  @override
  String get meFavoritesEmptySubtitle => 'チャットメッセージを長押しして保存するとここに表示されます';

  @override
  String get meLikesLoadFailed => 'いいねの読み込みに失敗しました';

  @override
  String get meLikesEmptyTitle => 'いいねはまだありません';

  @override
  String get meLikesEmptySubtitle => 'いいねしたチャンネル投稿がここに表示されます';

  @override
  String get meLikedPost => 'この投稿にいいねしました';

  @override
  String meReactedWith(String value) {
    return 'リアクションしました：$value';
  }

  @override
  String get meCommentsLoadFailed => 'コメントの読み込みに失敗しました';

  @override
  String get meCommentsEmptyTitle => 'コメントはまだありません';

  @override
  String get meCommentsEmptySubtitle => 'チャンネル投稿に書いたコメントがここに表示されます';

  @override
  String get meCommentFallback => 'コメント';

  @override
  String meCommentedWith(String body) {
    return 'コメントしました：$body';
  }

  @override
  String get meChannelPostFallback => 'チャンネル投稿';

  @override
  String get meFavoriteMessageFallback => 'お気に入りメッセージ';

  @override
  String get meFavoriteUnknownSender => '不明';

  @override
  String get meFavoriteTypeText => 'テキスト';

  @override
  String get meFavoriteTypeImage => '画像';

  @override
  String get meFavoriteTypeVideo => '動画';

  @override
  String get meFavoriteTypeFile => 'ファイル';

  @override
  String get meFavoriteTypeChatRecord => 'チャット履歴';

  @override
  String get meFavoriteTypeAudio => '音声';

  @override
  String get meFavoriteTypeLink => 'リンク';

  @override
  String get meFavoriteTypeMessage => 'メッセージ';

  @override
  String get meFavoriteFromDirect => '個別チャットから';

  @override
  String meFavoriteFromDirectWithSender(String sender) {
    return '$sender との個別チャットから';
  }

  @override
  String get meFavoriteFromGroup => 'グループチャットから';

  @override
  String meFavoriteFromGroupWithSender(String sender) {
    return 'グループチャットから · $sender';
  }

  @override
  String get meFavoriteFromChannel => 'チャンネルから';

  @override
  String meFavoriteFromChannelWithSender(String sender) {
    return 'チャンネルから · $sender';
  }

  @override
  String get meFavoriteFromAgent => 'Agent から';

  @override
  String get meFavoriteFromChat => 'チャットから';

  @override
  String meFavoriteFromChatWithSender(String sender) {
    return 'チャットから · $sender';
  }

  @override
  String get meFavoriteDirectChatRecord => '個別チャット履歴';

  @override
  String meFavoriteDirectChatRecordWithName(String name) {
    return '$name とのチャット履歴';
  }

  @override
  String get meFavoriteGroupChatRecord => 'グループチャット履歴';

  @override
  String meFavoriteGroupChatRecordWithName(String name) {
    return 'グループ「$name」のチャット履歴';
  }

  @override
  String get meFavoriteChannelChatRecord => 'チャンネルチャット履歴';

  @override
  String meFavoriteChannelChatRecordWithName(String name) {
    return 'チャンネル「$name」のチャット履歴';
  }

  @override
  String get meFavoriteAgentChatRecord => 'Agent とのチャット履歴';

  @override
  String meFavoriteDetailBody(String title) {
    return 'お気に入り詳細\n$title\n1件のメッセージ';
  }

  @override
  String get commonMe => '自分';

  @override
  String get commonJustNow => 'たった今';
}
