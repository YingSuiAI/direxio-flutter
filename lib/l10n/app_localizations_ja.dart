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
  String get homeDeleteChatTitle => 'チャット履歴を削除';

  @override
  String homeDeleteChatMessage(String name) {
    return '「$name」のすべてのチャット履歴を削除しますか？この操作は元に戻せません。';
  }

  @override
  String homeConversationDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String homeDeleteChatFailed(String error) {
    return 'チャット履歴の削除に失敗しました: $error';
  }

  @override
  String get homeAgentConversationNotSynced => 'Agent 会話はまだ同期されていません';

  @override
  String get homeDeleteChatMenu => 'チャットを削除';

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
  String get blacklistRemove => '削除';

  @override
  String blacklistRemovedMessage(String name) {
    return '$nameを削除しました';
  }

  @override
  String get blacklistEmpty => 'ブロックした連絡先はありません';

  @override
  String get settingsChangePassword => 'パスワードを変更';

  @override
  String get changePasswordOldHint => '現在のパスワード';

  @override
  String get changePasswordNewHint => '新しいパスワード';

  @override
  String get changePasswordConfirmHint => '新しいパスワードを再入力';

  @override
  String get changePasswordRule => 'パスワードは8文字以上にしてください';

  @override
  String get changePasswordOldTooShort => '現在のパスワードは8文字以上にしてください';

  @override
  String get changePasswordNewTooShort => '新しいパスワードは8文字以上にしてください';

  @override
  String get changePasswordMismatch => '2回入力したパスワードが一致しません';

  @override
  String get changePasswordSuccess => 'パスワードを変更しました';

  @override
  String get changePasswordSubmitting => '送信中…';

  @override
  String get changePasswordSubmit => '変更を送信';

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
  String get settingsDeactivateLogin => 'アカウントを削除';

  @override
  String get settingsDeactivateLoginConfirmTitle => 'アカウントを削除';

  @override
  String get settingsDeactivateLoginConfirmMessage =>
      '14日以内に一度ログインすると、アカウント削除は自動的にキャンセルされます。';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonBack => '戻る';

  @override
  String get commonAdd => '追加';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonSave => '保存';

  @override
  String get commonSearch => '検索';

  @override
  String get commonSend => '送信';

  @override
  String get commonShare => '共有';

  @override
  String get commonOnline => 'オンライン';

  @override
  String get commonOffline => 'オフライン';

  @override
  String get toolCallDenied => '拒否されました';

  @override
  String get toolCallArguments => '引数';

  @override
  String get toolCallWarnings => '警告';

  @override
  String get mcpPermissionTitle => 'MCP権限';

  @override
  String get mcpPermissionDescription => 'MCPツールを呼び出せるAgentアカウントを管理します。';

  @override
  String get mcpPermissionAuthorizeNewAgent => '新しいAgentを許可';

  @override
  String get mcpPermissionAuthorized => '許可済み';

  @override
  String get mcpPermissionDisabled => '無効';

  @override
  String get mcpPolicyRevokeAction => '取り消す';

  @override
  String get mcpPolicyRevokeAccess => 'アクセスを取り消す';

  @override
  String get mcpPolicyAuditEmptyTitle => '監査記録はありません';

  @override
  String get mcpPolicyAuditEmptySubtitle => 'ツール呼び出し記録はここに表示されます';

  @override
  String get mcpPolicyCompleted => '完了';

  @override
  String get mcpPolicyWriteBadge => '書込';

  @override
  String get mcpPolicyConfirmBeforeCall => '呼び出し前に確認';

  @override
  String get mcpPolicySelectedRooms => '選択したルーム';

  @override
  String get mcpPolicyExcludedRooms => '除外したルーム';

  @override
  String get mcpPolicyAddRoom => 'ルームを追加';

  @override
  String get channelCreatedNotice => 'チャンネルを作成しました';

  @override
  String get channelManageEmptyTitle => 'チャンネルはまだありません';

  @override
  String get channelManageEmptySubtitle => '作成したチャンネルはここに表示されます';

  @override
  String homeDetailPlaceholderTitle(String tabTitle) {
    return '$tabTitleの項目を選択してください';
  }

  @override
  String get homeDetailPlaceholderChatsSubtitle => '会話を開くとメッセージを表示できます';

  @override
  String get homeDetailPlaceholderDefaultSubtitle => '項目を選択すると詳細を表示できます';

  @override
  String get groupDetailMissing => 'グループチャットが見つかりません';

  @override
  String groupDetailChatInfoTitle(int count) {
    return 'グループチャット情報（$count）';
  }

  @override
  String get groupDetailDissolveTitle => 'グループチャットを解散';

  @override
  String get groupDetailLeaveTitle => 'グループチャットを退出';

  @override
  String get groupDetailDissolveMessage => '解散すると、メンバーはこのグループチャットを利用できなくなります。';

  @override
  String get groupDetailLeaveMessage => '退出すると、このグループチャットのメッセージを受信しなくなります。';

  @override
  String get groupDetailDissolveAction => '解散';

  @override
  String get groupDetailLeaveAction => '退出';

  @override
  String groupDetailLeaveOrDissolveFailed(String action, String error) {
    return '$actionに失敗しました：$error';
  }

  @override
  String get groupDetailInvite => '招待';

  @override
  String get avatarAdjustTitle => 'アバターを調整';

  @override
  String get avatarAdjustHint => 'ピンチで拡大、ドラッグで移動';

  @override
  String get avatarAdjustReset => 'リセット';

  @override
  String get avatarAdjustDone => '完了';

  @override
  String avatarAdjustUpdateFailed(String error) {
    return 'アバターの更新に失敗しました: $error';
  }

  @override
  String get avatarAdjustPreviewNotReady => 'アバターのプレビューはまだ準備できていません';

  @override
  String get avatarAdjustExportFailed => 'アバターの書き出しに失敗しました';

  @override
  String get profileInfoTitle => '自分の情報';

  @override
  String get profileInfoAvatarEdit => '編集';

  @override
  String get profileInfoMatrixSessionMissing => '現在の Matrix ログイン状態が見つかりません';

  @override
  String profileInfoAvatarUpdateFailed(String error) {
    return 'アバターの更新に失敗しました: $error';
  }

  @override
  String get profileInfoNickname => 'ニックネーム';

  @override
  String get profileInfoDisplayName => 'ユーザー名';

  @override
  String get profileInfoGender => '性別';

  @override
  String get profileInfoGenderMale => '男性';

  @override
  String get profileInfoGenderFemale => '女性';

  @override
  String get profileInfoGenderUpdated => '性別を更新しました';

  @override
  String get profileInfoBirthday => '誕生日';

  @override
  String get profileInfoBirthdayPickerTitle => '誕生日を選択';

  @override
  String get profileInfoBirthdayUpdated => '誕生日を更新しました';

  @override
  String get profileInfoEmail => 'メール';

  @override
  String get profileInfoEmailUpdated => 'メールを更新しました';

  @override
  String get profileInfoUnset => '未設定';

  @override
  String get profileInfoUidCopied => 'UID をコピーしました';

  @override
  String profileInfoEditTitle(String field) {
    return '$fieldを編集';
  }

  @override
  String profileInfoInputHint(String field) {
    return '$fieldを入力';
  }

  @override
  String get profileInfoDisplayNameEmpty => 'ユーザー名を入力してください';

  @override
  String get profileInfoDisplayNameSystemName => 'システムアカウントとは異なるユーザー名を設定してください';

  @override
  String get profileInfoDisplayNameUpdated => 'ユーザー名を更新しました';

  @override
  String profileInfoFieldUpdateFailed(String field, String error) {
    return '$fieldの更新に失敗しました: $error';
  }

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
  String get channelManageStatOwner => '所有者';

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
  String get createChannelTitle => 'チャンネルを作成';

  @override
  String get createChannelNameTitle => 'チャンネル名';

  @override
  String get createChannelNameHint => '入力してください';

  @override
  String get createChannelAvatarTitle => 'チャンネルアバターをアップロード';

  @override
  String get createChannelAvatarSubtitle => 'チャンネル表示用の画像をアップロードできます';

  @override
  String get createChannelTypeTitle => 'チャンネルタイプを選択';

  @override
  String get createChannelTypeText => 'テキスト';

  @override
  String get createChannelTypeTextSubtitle => 'メンバーが自由に発言';

  @override
  String get createChannelTypePosts => '投稿';

  @override
  String get createChannelTypePostsSubtitle => '投稿とコメント';

  @override
  String get createChannelPermissionsTitle => 'チャンネル権限';

  @override
  String get createChannelPublicTitle => '公開する';

  @override
  String get createChannelPublicSubtitle => 'オフの場合は招待からのみ参加できます';

  @override
  String get createChannelApprovalTitle => '参加に承認が必要';

  @override
  String get createChannelApprovalSubtitle => 'オンの場合、新メンバーの参加前に承認が必要です';

  @override
  String get createChannelIntroTitle => 'チャンネル紹介';

  @override
  String get createChannelIntroHint => 'チャンネル紹介を入力...';

  @override
  String get createChannelSubmit => 'チャンネルを作成';

  @override
  String get createChannelAvatarUploading => 'チャンネルアバターをアップロード中です。お待ちください';

  @override
  String get createChannelNameRequired => 'チャンネル名は必須です';

  @override
  String get createChannelAvatarRequired => 'チャンネルアバターをアップロードしてください';

  @override
  String get createChannelIntroRequired => 'チャンネル紹介は必須です';

  @override
  String createChannelAvatarUploadFailed(String error) {
    return 'チャンネルアバターのアップロードに失敗しました: $error';
  }

  @override
  String get createChannelCreated => 'チャンネルを作成しました';

  @override
  String createChannelFailed(String error) {
    return 'チャンネルの作成に失敗しました: $error';
  }

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
  String get channelManageSpeechOwnerReview => '所有者審査';

  @override
  String get channelManageSpeechMembers => 'メンバーが投稿可能';

  @override
  String get channelManageInviteOwner => '所有者';

  @override
  String get channelManageInviteMembers => 'メンバーを招待';

  @override
  String get channelManageInviteMembersValue => 'ID またはリンクで招待';

  @override
  String get channelManageOwnerOnline => '所有者 · オンライン';

  @override
  String get channelManageMemberModeration => 'メンバー · 審査';

  @override
  String get channelManageMemberOperations => 'メンバー · 運営';

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
  String get channelManageReviewLinkBody => '外部リンクが検出されました。表示前に所有者の確認が必要です。';

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
  String get loginGettingStartedGuide => 'はじめに';

  @override
  String get loginProductOverview => '製品概要';

  @override
  String loginLocalMatrixApiPortHint(String recommendedAuthority) {
    return 'ローカル3ノードテストでは $recommendedAuthority を使用してください';
  }

  @override
  String loginLocalMatrixApiPortError(String recommendedAuthority) {
    return 'ローカル3ノードテストでは $recommendedAuthority を使用してください。127.0.0.1 の Matrix API ポートは入力しないでください。';
  }

  @override
  String get loginGuideIntroPrimary =>
      '初回利用前に、利用可能な AI Agent（Codex、OpenClaw、Hermes など）と、デプロイに必要なクラウドアカウントおよびドメイン名を準備してください。\nDirexio デプロイスキルのリポジトリアドレスを Agent に送信します：https://github.com/YingSuiAI/direxio-deployer';

  @override
  String get loginGuideIntroSecondary =>
      'Agent は標準ワークフローに沿って、インストール、デプロイ、ドメイン紐付け、プラグイン設定を自動で完了します。\nデプロイが成功すると、Agent は IM アクセス URL、初期アカウント、パスワードを返します。\nこれらを受け取ったら、この App に戻ってサーバーアドレスとパスワードを入力してログインしてください。\n公式サイト：direxio.ai';

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
  String get agreementTerms => '利用規約';

  @override
  String get agreementPrivacy => 'プライバシーポリシー';

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
  String get addContactOpenChatMissing => 'チャットを開けませんでした: 会話情報がありません';

  @override
  String get addContactChatSyncing => 'チャットを同期中です。しばらくしてから再試行してください。';

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
  String get contactSetRemark => '備考を設定';

  @override
  String get contactRecommendFriend => '友だちにすすめる';

  @override
  String get contactRecommendHim => 'この人を友だちにすすめる';

  @override
  String get contactSearchChat => 'チャットを検索';

  @override
  String get contactDeleteFriend => '友だちを削除';

  @override
  String get contactBlockUserDetail => 'ユーザーをブロック';

  @override
  String get contactHisChannels => '彼のチャンネル';

  @override
  String get contactChannelsLoading => 'チャンネルを読み込み中';

  @override
  String get contactChannelsLoadFailed => 'チャンネルを読み込めませんでした';

  @override
  String get contactChannelsEmpty => 'チャンネルはまだありません';

  @override
  String get contactChannelsUnnamed => '名称未設定のチャンネル';

  @override
  String get contactChannelsPostTag => '投稿';

  @override
  String get contactChannelsTextTag => 'テキスト';

  @override
  String get contactAddFriend => '友だちを追加';

  @override
  String get contactSupportManager => 'サポートマネージャー';

  @override
  String get contactRoomMissingSearch => '連絡先のルーム情報がないため、チャットを検索できません';

  @override
  String get contactRoomMissingBlock => 'ユーザーのブロックに失敗しました: 連絡先のルーム情報がありません';

  @override
  String get contactRoomMissingDelete => '友だちの削除に失敗しました: 連絡先のルーム情報がありません';

  @override
  String get contactRoomMissingRemark => '連絡先のルーム情報がないため、備考を保存できません';

  @override
  String get chatInfoTitle => 'チャット情報';

  @override
  String get chatInfoMissingConversation => '会話が見つかりません';

  @override
  String get chatInfoSearchRecords => 'チャット履歴を検索';

  @override
  String get roomSearchTitle => 'チャット履歴を検索';

  @override
  String get roomSearchHint => 'このチャットを検索';

  @override
  String get roomSearchEmptyPrompt => 'キーワードを入力してこのチャットを検索';

  @override
  String roomSearchNoResults(String query) {
    return '「$query」を含むメッセージは見つかりません';
  }

  @override
  String get roomSearchMessageFallback => 'メッセージ';

  @override
  String get chatInfoContactMissingRemark => '連絡先情報がないため、備考を設定できません';

  @override
  String get chatInfoSelfBlockDisabled => '現在のユーザーはブロックできません';

  @override
  String get chatInfoSelfReportDisabled => '現在のユーザーは報告できません';

  @override
  String get chatInfoClearHistory => 'チャット履歴を消去';

  @override
  String get chatInfoClearHistoryConfirm => 'すべてのチャット履歴を消去しますか？この操作は元に戻せません。';

  @override
  String get chatInfoClearHistoryAction => '消去';

  @override
  String get chatInfoClearHistoryCleared => 'チャット履歴を消去しました';

  @override
  String chatInfoClearHistoryFailed(String error) {
    return 'チャット履歴の消去に失敗しました: $error';
  }

  @override
  String get chatInfoUidCopied => 'UID をコピーしました';

  @override
  String get chatInfoContactSyncing => '連絡先情報を同期中';

  @override
  String groupInfoTitle(int count) {
    return 'チャット情報（$count）';
  }

  @override
  String get groupInfoInvite => '招待';

  @override
  String get groupInfoRemove => '削除';

  @override
  String get groupInfoManagement => 'グループ管理';

  @override
  String get groupInfoSearchRecords => 'チャットを検索';

  @override
  String get groupInfoPinChat => 'チャットをピン留め';

  @override
  String get groupInfoMyNickname => 'このグループでのニックネーム';

  @override
  String get groupInfoShowMemberNicknames => 'メンバーのニックネームを表示';

  @override
  String get groupInfoReportGroup => 'グループを報告';

  @override
  String get groupInfoDissolveGroup => 'グループを解散';

  @override
  String get groupInfoLeaveGroup => 'グループを退出';

  @override
  String get groupInfoNoRemovableMembers => '削除できるメンバーはいません';

  @override
  String get groupInfoRemoveMemberTitle => 'メンバーを削除';

  @override
  String groupInfoRemoveMemberConfirm(String name) {
    return '$nameをグループから削除しますか？';
  }

  @override
  String groupInfoMemberRemoved(String name) {
    return '$nameを削除しました';
  }

  @override
  String groupInfoRemoveMemberFailed(String error) {
    return 'メンバーの削除に失敗しました: $error';
  }

  @override
  String get groupInfoRemarkTitle => '備考';

  @override
  String get groupInfoRemarkHint => 'グループの備考を入力';

  @override
  String get groupInfoRemarkCleared => 'グループの備考を消去しました';

  @override
  String get groupInfoRemarkUpdated => 'グループの備考を更新しました';

  @override
  String get groupInfoNicknameHint => 'グループでのニックネームを入力';

  @override
  String get groupInfoNicknameEmpty => 'グループでのニックネームは空にできません';

  @override
  String get groupInfoCurrentUserMissing => '現在のユーザー情報がありません';

  @override
  String get groupInfoNicknameUpdated => 'グループでのニックネームを更新しました';

  @override
  String groupInfoNicknameUpdateFailed(String error) {
    return 'グループでのニックネーム設定に失敗しました: $error';
  }

  @override
  String get groupInfoClearHistoryConfirm =>
      'このグループのすべてのチャット履歴を消去しますか？この操作は元に戻せません。';

  @override
  String get groupInfoDissolveConfirm => 'このグループを解散しますか？';

  @override
  String get groupInfoLeaveConfirm => 'このグループを退出しますか？';

  @override
  String get groupInfoDissolveAction => '解散';

  @override
  String get groupInfoLeaveAction => '退出';

  @override
  String groupInfoLeaveFailed(String action, String error) {
    return 'グループの$actionに失敗しました: $error';
  }

  @override
  String get groupCreateCreated => 'グループチャットを作成しました';

  @override
  String groupCreateFailed(String error) {
    return '作成に失敗しました: $error';
  }

  @override
  String get groupCreateNameHint => 'グループ名を入力';

  @override
  String get groupInviteAddMembersTitle => 'グループメンバーを追加';

  @override
  String get channelInviteAddMembersTitle => 'チャンネルメンバーを招待';

  @override
  String get groupInviteNoContacts => '招待できる連絡先はありません';

  @override
  String get groupInviteSend => '招待を送信';

  @override
  String get groupManageNameTitle => 'グループ名';

  @override
  String get groupManageNameHint => 'グループ名を入力';

  @override
  String get groupManageNameEmpty => 'グループ名を入力してください';

  @override
  String get groupManageNameUpdated => 'グループ名を更新しました';

  @override
  String groupManageNameUpdateFailed(String error) {
    return 'グループ名の更新に失敗しました: $error';
  }

  @override
  String get groupManageAvatarUpdated => 'グループアバターを更新しました';

  @override
  String groupManageAvatarUpdateFailed(String error) {
    return 'グループアバターの更新に失敗しました: $error';
  }

  @override
  String get groupManageMuteEnabled => '全員ミュートを有効にしました';

  @override
  String get groupManageMuteDisabled => '全員ミュートを解除しました';

  @override
  String groupManageMuteEnableFailed(String error) {
    return '全員ミュートの有効化に失敗しました: $error';
  }

  @override
  String groupManageMuteDisableFailed(String error) {
    return '全員ミュートの解除に失敗しました: $error';
  }

  @override
  String get groupManageInvitePolicyUpdated => 'メンバー招待権限を更新しました';

  @override
  String groupManageInvitePolicyUpdateFailed(String error) {
    return 'メンバー招待権限の更新に失敗しました: $error';
  }

  @override
  String get mcpPolicySaved => '保存しました';

  @override
  String get mcpPolicyRevokeTitle => '権限を取り消しますか？';

  @override
  String get mcpPolicyRevokeMessage => 'Agent はすべての MCP 権限をただちに失います。';

  @override
  String get mcpPolicyBlockedKeywordAdd => '+ 追加';

  @override
  String get mcpPolicyBlockedKeywordTitle => 'ブロックキーワードを追加';

  @override
  String get mcpPolicyBlockedKeywordHint => 'この単語に一致するメッセージはマスクされます';

  @override
  String get contactFriendRequestRestored => '以前の会話を復元しました。続けてチャットできます。';

  @override
  String get contactFriendRequestSent => '友だち申請を送信しました。承認を待っています。';

  @override
  String get contactDeleteConfirmTitle => '友だちを削除';

  @override
  String get contactDeleteConfirmBody =>
      '削除すると、この連絡先は表示されなくなり、会話の関係も同期して更新されます。';

  @override
  String contactDeleteConfirmBodyWithName(String name) {
    return '$nameを削除すると、双方のダイレクトチャット関係が解除されます。';
  }

  @override
  String get contactDeleteAction => '削除';

  @override
  String get contactDeleted => '友だちを削除しました';

  @override
  String contactDeletedName(String name) {
    return '$nameを削除しました';
  }

  @override
  String get contactApplied => '申請済み';

  @override
  String contactFollowFailed(String error) {
    return 'フォローに失敗しました: $error';
  }

  @override
  String contactUnfollowFailed(String error) {
    return 'フォロー解除に失敗しました: $error';
  }

  @override
  String contactFriendRequestFailed(String error) {
    return '友だちリクエストの送信に失敗しました: $error';
  }

  @override
  String get contactDeleteMissingRoom => '友だちの削除に失敗しました: 連絡先ルーム情報がありません';

  @override
  String contactDeleteFailed(String error) {
    return '友だちの削除に失敗しました: $error';
  }

  @override
  String get contactBlockConfirmTitle => 'ユーザーをブロック';

  @override
  String get contactBlockConfirmBody => 'ブロックすると、この連絡先と会話の関係が削除されます。';

  @override
  String get contactBlockAction => 'ブロック';

  @override
  String get contactBlocked => 'ユーザーをブロックしました';

  @override
  String contactBlockFailed(String error) {
    return 'ユーザーのブロックに失敗しました: $error';
  }

  @override
  String get contactReportSubmitted => '報告を送信しました';

  @override
  String contactReportSubmitFailed(String error) {
    return '報告の送信に失敗しました: $error';
  }

  @override
  String get reportReasonDialogTitle => '報告理由を選択';

  @override
  String get reportReasonHarassment => '嫌がらせ / 暴言';

  @override
  String get reportReasonSpam => 'スパム / 広告';

  @override
  String get reportReasonSexual => '性的 / 不適切な内容';

  @override
  String get reportReasonViolence => '暴力的な内容';

  @override
  String get reportReasonFraud => '詐欺';

  @override
  String get reportReasonOther => 'その他';

  @override
  String get reportReasonOtherHint => '報告理由を入力してください';

  @override
  String get reportReasonPickImages => '画像をアップロード';

  @override
  String reportReasonImagesSelected(int count) {
    return '$count 枚の画像を選択済み';
  }

  @override
  String reportReasonPickImageFailed(String error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String get reportReasonSubmit => '送信';

  @override
  String get contactRemarkEmpty => '備考は空にできません';

  @override
  String contactRemarkUpdateFailed(String error) {
    return '備考の更新に失敗しました: $error';
  }

  @override
  String get contactRemarkUpdated => '備考を更新しました';

  @override
  String get contactRemarkHint => '備考名を入力';

  @override
  String get contactRemarkSave => '保存';

  @override
  String contactShareText(String name, String userId) {
    return 'おすすめの連絡先：$name\n$userId';
  }

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
  String get groupsListSearchHint => 'グループチャットを検索';

  @override
  String get groupsListSyncing => 'グループチャットを同期中';

  @override
  String get groupsListEmpty => 'グループチャットはまだありません';

  @override
  String get groupsListNoMatches => '一致するグループチャットはありません';

  @override
  String get groupsListOwnerBadge => 'オーナー';

  @override
  String get groupsListYesterday => '昨日';

  @override
  String get requestsSearchHint => '検索';

  @override
  String get requestsPendingHidden => '承認待ち';

  @override
  String get requestsWaitingPeerAccept => '相手の承認待ち';

  @override
  String get requestsRejected => '拒否済み';

  @override
  String get requestsPeerRejected => '相手が拒否しました';

  @override
  String get requestsAdded => '追加済み';

  @override
  String get requestsBecameFriends => '友だちになりました';

  @override
  String get requestsEmptyPending => '友だち申請はありません';

  @override
  String get requestsEmptyAdded => '追加済みの連絡先はありません';

  @override
  String get requestsRequestAsFriend => 'あなたを友だちに追加しようとしています';

  @override
  String get requestsMyRequestAsFriend => '自分: あなたを友だちに追加しようとしています';

  @override
  String get requestsIncomingRequestMessage => '友だち申請';

  @override
  String get requestsFriendNoticeTitle => '友だち申請';

  @override
  String get requestsFriendNoticeFallback => '友だち申請通知';

  @override
  String get requestsGroupNoticeTitle => 'グループ通知';

  @override
  String get requestsGroupNoticeFallback => 'グループチャットに招待されました';

  @override
  String get requestsChannelNoticeTitle => 'チャンネル通知';

  @override
  String get requestsChannelNoticeFallback => 'チャンネルに招待されました';

  @override
  String get requestsView => '表示';

  @override
  String get requestsAccept => '承認';

  @override
  String get requestsReject => '拒否';

  @override
  String get requestsCannotIdentifySource => '申請元を識別できません';

  @override
  String get requestsAcceptSuccess => '友だち申請を承認しました';

  @override
  String get requestsRejectSuccess => '友だち申請を拒否しました';

  @override
  String requestsAcceptFailed(String error) {
    return '承認に失敗しました: $error';
  }

  @override
  String requestsRejectFailed(String error) {
    return '拒否に失敗しました: $error';
  }

  @override
  String get requestsInvalidDomainInput => '有効なドメインまたはMatrix IDを入力してください';

  @override
  String get requestsDomainNotProductUser => 'このドメインは製品ユーザーではありません';

  @override
  String get requestsCannotAddSelf => '自分自身は追加できません';

  @override
  String requestsAlreadyContact(String name) {
    return '$name はすでに連絡先です';
  }

  @override
  String requestsAlreadySent(String name) {
    return '$name に友だち申請を送信済みです。承認を待っています。';
  }

  @override
  String requestsRestoredConversation(String name) {
    return '$name との以前の会話を復元しました';
  }

  @override
  String requestsSentTo(String name) {
    return '$name に友だち申請を送信しました';
  }

  @override
  String get createGroupTitle => 'グループチャットを開始';

  @override
  String get createGroupMenuTitle => 'グループチャットを開始';

  @override
  String get createGroupSetupTitle => 'グループチャットを作成';

  @override
  String get createGroupDone => '完了';

  @override
  String createGroupDoneWithCount(int count) {
    return '完了($count)';
  }

  @override
  String get createGroupSubmit => '作成';

  @override
  String get createGroupMembers => 'グループメンバー';

  @override
  String createGroupMemberCount(int count) {
    return '$count人';
  }

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
  String get groupChatUnknownMember => '不明なメンバー';

  @override
  String groupChatVoiceRecordFailed(String error) {
    return '音声録音に失敗しました：$error';
  }

  @override
  String get groupChatRecordingTooShort => '録音時間が短すぎます';

  @override
  String get groupChatOriginalMessageUnavailable => '元のメッセージは表示できません';

  @override
  String groupChatOpenFailed(String error) {
    return '開けませんでした：$error';
  }

  @override
  String groupChatPlaybackFailed(String error) {
    return '再生に失敗しました：$error';
  }

  @override
  String groupChatDownloadSaved(String filename) {
    return 'Files / Portal App / P2P IM Downloads / $filename に保存しました';
  }

  @override
  String groupChatDownloadFailed(String error) {
    return 'ダウンロードに失敗しました：$error';
  }

  @override
  String groupChatSendFailed(String error) {
    return '送信に失敗しました：$error';
  }

  @override
  String get groupChatCannotSendChannel => 'チャンネルに参加するとメッセージを送信できます';

  @override
  String get groupChatCannotSendGroup => 'グループに参加するとメッセージを送信できます';

  @override
  String get groupChatChannel => 'チャンネル';

  @override
  String get groupChatGroup => 'グループ';

  @override
  String groupChatMissingTitle(String title) {
    return '$titleが見つかりません';
  }

  @override
  String groupChatRecovering(String title) {
    return '$titleを復元しています...';
  }

  @override
  String groupChatSyncTimeout(String title) {
    return '$titleの同期がタイムアウトしました。ネットワークを確認して再試行してください';
  }

  @override
  String groupChatCannotOpen(String title) {
    return 'この$titleは現在開けません';
  }

  @override
  String groupChatMemberCount(int count) {
    return '$count 人のメンバー';
  }

  @override
  String get groupChatCalling => 'グループ通話中';

  @override
  String get groupChatVoiceCall => '音声通話';

  @override
  String get groupChatDetails => '詳細';

  @override
  String get groupChatEmpty => 'メッセージはまだありません';

  @override
  String get groupChatMentionTitle => 'メンションする相手を選択';

  @override
  String get groupChatClose => '閉じる';

  @override
  String get groupChatMentionSearchHint => 'グループメンバーを検索';

  @override
  String get groupChatNoMentionMembers => 'メンションできるメンバーはいません';

  @override
  String get groupChatNoMembersFound => 'メンバーが見つかりません';

  @override
  String get groupChatImage => '画像';

  @override
  String get groupChatVideo => '動画';

  @override
  String get groupChatFile => 'ファイル';

  @override
  String get messagePreviewSentImage => '画像を送信しました';

  @override
  String get messagePreviewReceivedImage => '画像を受信しました';

  @override
  String get messagePreviewSentVideo => '動画を送信しました';

  @override
  String get messagePreviewReceivedVideo => '動画を受信しました';

  @override
  String get messagePreviewSentFile => 'ファイルを送信しました';

  @override
  String get messagePreviewReceivedFile => 'ファイルを受信しました';

  @override
  String get messagePreviewImageBracket => '[画像]';

  @override
  String get messagePreviewVideoBracket => '[動画]';

  @override
  String get messagePreviewFileBracket => '[ファイル]';

  @override
  String get messagePreviewVoiceBracket => '[音声]';

  @override
  String get messagePreviewChatRecordBracket => '[チャット履歴]';

  @override
  String get messagePreviewChannelBracket => '[チャンネル]';

  @override
  String get messagePreviewChannelShare => 'チャンネル共有';

  @override
  String get messagePreviewGroupInvite => 'グループ招待';

  @override
  String get messagePreviewMessage => 'メッセージ';

  @override
  String get messagePreviewSendFailed => '送信に失敗しました';

  @override
  String get messagePreviewCallRejected => '通話を拒否しました';

  @override
  String get messagePreviewCallMissed => '不在着信';

  @override
  String get messagePreviewGroupCall => 'グループ通話';

  @override
  String get messagePreviewCall => '通話';

  @override
  String get messagePreviewChatRecord => 'チャット履歴';

  @override
  String get messagePreviewGroupChatRecord => 'グループチャット履歴';

  @override
  String get messagePreviewDirectChatRecord => '個人チャット履歴';

  @override
  String get messagePreviewChannelChatRecord => 'チャンネルチャット履歴';

  @override
  String get messagePreviewAgentChatRecord => 'Agent チャット履歴';

  @override
  String get callReady => '通話の準備中';

  @override
  String get callCalling => '発信中...';

  @override
  String get callInviteVoice => '音声通話に招待しています';

  @override
  String get callInviteVideo => 'ビデオ通話に招待しています';

  @override
  String get callWaitingAnswer => '相手の応答を待っています';

  @override
  String get callConnecting => '接続中...';

  @override
  String get callVideoConnected => 'ビデオ通話中';

  @override
  String get callVoiceConnected => '通話中';

  @override
  String get callEnded => '通話が終了しました';

  @override
  String get callFailed => '通話に失敗しました';

  @override
  String get callPeerRejected => '相手が拒否しました';

  @override
  String get callRejected => '通話を拒否しました';

  @override
  String get callPeerHungUp => '相手が切断しました';

  @override
  String get callMissed => '不在着信';

  @override
  String get callNoPeer => '通話相手を特定できません';

  @override
  String get callAlreadyActive => '通話がすでに進行中です';

  @override
  String get callServiceNotReady => '通話サービスの準備ができていません';

  @override
  String get callStarting => '通話を開始しています';

  @override
  String get callRoomMissing => '通話ルームが存在しません';

  @override
  String get callStartFailed => '通話の開始に失敗しました。後でもう一度お試しください';

  @override
  String get callOutgoingNetworkFailed => '発信に失敗しました。ネットワークまたはノードを確認してください';

  @override
  String get callPeerNoResponse => '相手が応答しません。通話を終了しました';

  @override
  String get callNetworkUnstable => 'ネットワークが不安定です';

  @override
  String get callInterrupted => '通話が中断されました';

  @override
  String get callMediaPermissionVideo => 'カメラまたはマイクを使用できません。権限を確認してください';

  @override
  String get callMediaPermissionVoice => 'マイクを使用できません。権限を確認してください';

  @override
  String get callPeerBusy => '相手は通話中です';

  @override
  String get callCameraOn => 'カメラをオン';

  @override
  String get callCameraOff => 'カメラをオフ';

  @override
  String get callCameraOffState => 'カメラはオフです';

  @override
  String get callCameraStarting => 'カメラを起動中';

  @override
  String get callRemoteCameraUnavailable => '相手のカメラは使用できません';

  @override
  String get callWaitingRemoteVideo => '映像を待っています';

  @override
  String get callSpeaker => 'スピーカー';

  @override
  String get callEarpiece => '受話口';

  @override
  String get callEncrypted => 'エンドツーエンド暗号化';

  @override
  String get callReject => '拒否';

  @override
  String get callAnswer => '応答';

  @override
  String get callMuted => 'ミュート中';

  @override
  String get callMute => 'ミュート';

  @override
  String get callUnmute => 'ミュート解除';

  @override
  String get callHangup => '切断';

  @override
  String get groupCallTitleVoice => 'グループ音声通話';

  @override
  String get groupCallTitleVideo => 'グループビデオ通話';

  @override
  String get groupCallInviteVoice => 'グループ音声通話に招待しています';

  @override
  String get groupCallInviteVideo => 'グループビデオ通話に招待しています';

  @override
  String get groupCallJoiningVoice => 'グループ音声通話に参加中';

  @override
  String get groupCallJoiningVideo => 'グループビデオ通話に参加中';

  @override
  String get groupCallConnectedVoice => 'グループ音声通話中';

  @override
  String get groupCallConnectedVideo => 'グループビデオ通話中';

  @override
  String get groupCallEnded => 'グループ通話が終了しました';

  @override
  String get groupCallFailed => 'グループ通話に失敗しました';

  @override
  String get groupCallNetworkFailed => 'グループ通話の開始に失敗しました。ネットワークまたはノードを確認してください';

  @override
  String get groupCallRoomMissing => 'グループチャットが存在しません';

  @override
  String get groupCallUnsupported => 'このグループはまだグループ通話に対応していません';

  @override
  String get groupCallCameraUnavailable => 'カメラは使用できません';

  @override
  String get groupCallWaitingVideo => '映像を待っています';

  @override
  String get groupCallWaitingMembersVideo => 'グループメンバーの映像を待っています';

  @override
  String get groupCallMemberFallback => 'メンバー';

  @override
  String get groupCallWaitingMembers => 'メンバーの参加を待っています';

  @override
  String groupCallParticipantCount(int count) {
    return '$count人が通話中';
  }

  @override
  String get groupCallReadyToJoin => '参加準備中';

  @override
  String get groupCallBack => '戻る';

  @override
  String get groupCallJoin => '参加';

  @override
  String get groupCallLeave => '退出';

  @override
  String get groupCallSelectVideoMembers => 'ビデオメンバーを選択';

  @override
  String get groupCallSelectVoiceMembers => '音声メンバーを選択';

  @override
  String get groupCallStartVideo => 'ビデオ通話を開始';

  @override
  String get groupCallStartVoice => '音声通話を開始';

  @override
  String get groupCallSelectAtLeastOne => '招待するメンバーを1人以上選択してください';

  @override
  String groupCallSelectedMembers(int selected, int total) {
    return '$selected / $total 人を選択済み';
  }

  @override
  String get groupCallNoInviteMembers => '招待できるメンバーはいません';

  @override
  String get chatInputVoice => '音声';

  @override
  String get chatInputKeyboard => 'キーボード';

  @override
  String get chatInputHoldToTalk => '長押しして話す';

  @override
  String get chatInputReleaseToSend => '離して送信';

  @override
  String get chatInputReleaseToCancel => '離してキャンセル';

  @override
  String get chatInputReleaseToCancelCompact => '離してキャンセル';

  @override
  String get chatInputReleaseToSendSwipeCancel => '離して送信、上にスワイプでキャンセル';

  @override
  String get chatInputMore => 'その他';

  @override
  String get chatAttachmentAlbum => 'アルバム';

  @override
  String get chatAttachmentCamera => '撮影';

  @override
  String get chatAttachmentVideo => '動画';

  @override
  String get chatAttachmentLocation => '位置情報';

  @override
  String get chatAttachmentContactCard => '連絡先カード';

  @override
  String get chatAttachmentFile => 'ファイル';

  @override
  String get chatAttachmentNoImageSelected => '画像が選択されていません';

  @override
  String get chatAttachmentNoPhotoTaken => '写真が撮影されていません';

  @override
  String get chatAttachmentNoFileSelected => 'ファイルが選択されていません';

  @override
  String get chatAttachmentNoVideoSelected => '動画が選択されていません';

  @override
  String get chatMediaPhoto => '写真';

  @override
  String get chatMediaAudio => '音声メッセージ';

  @override
  String get chatMediaGeneric => 'メディア';

  @override
  String chatMediaReadFailed(String label) {
    return '$labelの読み取りに失敗しました。選択し直してください';
  }

  @override
  String chatMediaUploadFailed(String label) {
    return '$labelのアップロードに失敗しました。ネットワークを確認して再試行してください';
  }

  @override
  String groupChatLocalMediaMissing(String label) {
    return 'ローカルの元$labelが見つかりません。$labelを選択し直してください';
  }

  @override
  String get groupChatCopied => 'コピーしました';

  @override
  String get groupChatDeleted => '削除しました';

  @override
  String get groupChatCannotFavoriteSending => '送信中のメッセージはお気に入りに追加できません';

  @override
  String get groupChatActionAvailableAfterSent => 'この操作はメッセージ送信後に使用できます';

  @override
  String get groupChatNoRecallPermission => 'このメッセージを取り消す権限がありません';

  @override
  String get groupChatRecallTitle => 'メッセージを取り消す';

  @override
  String get groupChatRecallBody => '取り消すと、グループメンバーもこのメッセージを見られなくなります。';

  @override
  String get groupChatCancel => 'キャンセル';

  @override
  String get groupChatRecall => '取り消す';

  @override
  String get groupChatRecalled => 'メッセージを取り消しました';

  @override
  String groupChatRecallFailed(String error) {
    return 'メッセージの取り消しに失敗しました：$error';
  }

  @override
  String groupChatDeleteFailed(String error) {
    return 'メッセージの削除に失敗しました：$error';
  }

  @override
  String get groupChatFavoriting => '自分のノードに保存しています…';

  @override
  String get groupChatFavorited => '保存しました';

  @override
  String groupChatFavoriteFailed(String error) {
    return 'お気に入りに追加できませんでした：$error';
  }

  @override
  String get groupChatForwardedRecord => 'チャット履歴を転送しました';

  @override
  String groupChatForwardFailed(String error) {
    return '転送に失敗しました：$error';
  }

  @override
  String get groupChatCopy => 'コピー';

  @override
  String get groupChatForward => '転送';

  @override
  String get groupChatFavorite => 'お気に入り';

  @override
  String get groupChatDelete => '削除';

  @override
  String get groupChatMultiSelect => '複数選択';

  @override
  String get groupChatQuote => '引用';

  @override
  String get groupChatSelectMessage => 'メッセージを選択';

  @override
  String get groupChatCancelSelectMessage => 'メッセージの選択を解除';

  @override
  String get chatAiSuggestions => 'AI の提案';

  @override
  String get chatRecordForwardTitle => 'チャット履歴を転送';

  @override
  String get chatVideoCannotPlay => 'この動画は再生できません';

  @override
  String get redPacketMineDetailAction => '送信詳細を見る';

  @override
  String get redPacketDetailAction => '詳細を見る';

  @override
  String get redPacketMineDetailTitle => '送信したレッドパケット';

  @override
  String get redPacketDetailTitle => 'レッドパケット詳細';

  @override
  String get groupChatMe => '自分';

  @override
  String get groupChatMessageFallback => 'メッセージ';

  @override
  String chatReplyTo(String sender) {
    return '$senderに返信';
  }

  @override
  String get groupChatQuotedMessage => '引用メッセージ';

  @override
  String get groupChatRetryFile => 'ファイルを再送信';

  @override
  String get groupChatRetryMessage => 'メッセージを再送信';

  @override
  String get groupChatDownloading => 'ダウンロード中';

  @override
  String get groupChatDownloaded => 'ダウンロード済み';

  @override
  String get groupChatDownloadFile => 'ファイルをダウンロード';

  @override
  String get groupChatRemovedCannotSend => '退出済みのグループではメッセージを送信できません';

  @override
  String get chatPeerAcceptBeforeSend => '相手が友だちリクエストを承認するとメッセージを送信できます';

  @override
  String get contactHomeMissing => '連絡先が見つかりません';

  @override
  String get chatPeerDeletedContact => '相手が連絡先関係を削除したため、メッセージは配信されませんでした。';

  @override
  String get chatRecallBody => '取り消すと、相手もこのメッセージを見られなくなります。';

  @override
  String get chatImageSavedToAlbum => '元の画像を写真に保存しました';

  @override
  String get chatGroupSyncingRetryLater => 'グループチャットを同期中です。しばらくしてから再試行してください。';

  @override
  String get chatGroupInviteExpired => '招待されていないか、招待の有効期限が切れています';

  @override
  String chatJoinGroupFailed(String error) {
    return 'グループへの参加に失敗しました: $error';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonUser => 'ユーザー';

  @override
  String get sessionExpiredTitle => '別の端末でログインされました';

  @override
  String get sessionExpiredMessage =>
      'このアカウントは別の端末でログインされました。OKをタップしてから、パスワードを手動で入力して再ログインしてください。';

  @override
  String get chatRecordForwarded => 'チャット履歴を転送しました';

  @override
  String chatRecordForwardFailed(String error) {
    return '転送に失敗しました：$error';
  }

  @override
  String chatRecordOpenFailed(String error) {
    return '開けませんでした：$error';
  }

  @override
  String chatRecordSelectedCount(int count) {
    return '$count件選択済み';
  }

  @override
  String chatRecordMessageCount(int count) {
    return '$count件のメッセージ';
  }

  @override
  String get chatRecordEmptyDetails => 'メッセージ詳細はありません';

  @override
  String get chatVideoSavedToAlbum => '元の動画をアルバムに保存しました';

  @override
  String chatSaveFailed(String error) {
    return '保存に失敗しました：$error';
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
  String get channelSyncingTitle => 'チャンネルを同期中';

  @override
  String get channelSyncingSubtitle => 'しばらくお待ちください';

  @override
  String get channelConversationQuoted => '引用しました';

  @override
  String get channelConversationForwardPending => '転送機能はまもなく実チャンネルメッセージに対応します';

  @override
  String get channelConversationMultiSelectPending =>
      '複数選択機能はまもなく実チャンネルメッセージに対応します';

  @override
  String get channelMyChannelsTitle => '自分のチャンネル';

  @override
  String get channelJoinedSection => '参加済み';

  @override
  String get channelCreatedSection => '作成済み';

  @override
  String get channelCreatedEmptyTitle => '作成したチャンネルはまだありません';

  @override
  String get channelJoinedEmptyTitle => '参加中のチャンネルはまだありません';

  @override
  String get channelCreatedEmptySubtitle => '作成したチャンネルがここに表示されます。';

  @override
  String get channelJoinedEmptySubtitle => '参加したチャンネルがここに表示されます。';

  @override
  String get channelOpenSyncing => 'チャンネルを同期中です。しばらくしてから再試行してください';

  @override
  String get channelDissolved => 'チャンネルは解散済みです';

  @override
  String get channelKindText => 'テキスト';

  @override
  String get channelKindPost => '投稿';

  @override
  String get channelAvatarFallback => 'チ';

  @override
  String get channelMenuPin => 'ピン留め';

  @override
  String get channelMenuUnpin => 'ピン留めを解除';

  @override
  String channelMenuPinned(String name) {
    return '「$name」をピン留めしました';
  }

  @override
  String channelMenuUnpinned(String name) {
    return '「$name」のピン留めを解除しました';
  }

  @override
  String get channelMenuHide => '非表示';

  @override
  String channelMenuHidden(String name) {
    return '「$name」を非表示にしました';
  }

  @override
  String get channelMenuDelete => 'チャンネルを削除';

  @override
  String channelMenuDeleted(String name) {
    return '「$name」を削除しました';
  }

  @override
  String get channelTimeMonday => '月';

  @override
  String get channelTimeTuesday => '火';

  @override
  String get channelTimeWednesday => '水';

  @override
  String get channelTimeThursday => '木';

  @override
  String get channelTimeFriday => '金';

  @override
  String get channelTimeSaturday => '土';

  @override
  String get channelTimeSunday => '日';

  @override
  String get channelInfoTitle => 'チャンネル情報';

  @override
  String get channelInfoDetailAction => 'チャンネル詳細';

  @override
  String get channelInfoShareAction => 'チャンネルを共有';

  @override
  String get channelInfoReportAction => 'チャンネルを報告';

  @override
  String get channelInfoLeaveAction => 'チャンネルを退出';

  @override
  String get channelInfoDissolveAction => 'チャンネルを解散';

  @override
  String get channelInfoNoRemovableMembers => '削除できるメンバーはいません';

  @override
  String get channelInfoRemoveMembersTitle => 'チャンネルメンバーを削除';

  @override
  String channelInfoConfirmRemove(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get channelInfoMemberRemoved => 'メンバーを削除しました';

  @override
  String channelInfoRemoveFailed(String error) {
    return '削除に失敗しました：$error';
  }

  @override
  String get channelInfoMuteAll => '全員をミュート';

  @override
  String get channelInfoMuteEnabled => '全員ミュートを有効にしました';

  @override
  String get channelInfoMuteDisabled => '全員ミュートを解除しました';

  @override
  String channelInfoMuteEnableFailed(String error) {
    return '全員ミュートの有効化に失敗しました：$error';
  }

  @override
  String channelInfoMuteDisableFailed(String error) {
    return '全員ミュートの解除に失敗しました：$error';
  }

  @override
  String get channelInfoReportMissingRoom => '報告に失敗しました：チャンネルルームIDがありません';

  @override
  String get channelInfoReportSubmitted => '報告を送信しました';

  @override
  String channelInfoReportFailed(String error) {
    return '報告に失敗しました：$error';
  }

  @override
  String get channelInfoShared => 'チャンネルを共有しました';

  @override
  String channelInfoShareFailed(String error) {
    return 'チャンネルの共有に失敗しました：$error';
  }

  @override
  String get channelInfoLeaveConfirm => 'このチャンネルを退出しますか？';

  @override
  String get channelInfoLeft => 'チャンネルを退出しました';

  @override
  String channelInfoLeaveFailed(String error) {
    return 'チャンネルの退出に失敗しました：$error';
  }

  @override
  String get channelInfoDissolveConfirm => 'このチャンネルを解散しますか？';

  @override
  String get channelInfoDissolved => 'チャンネルを解散しました';

  @override
  String channelInfoDissolveFailed(String error) {
    return 'チャンネルの解散に失敗しました：$error';
  }

  @override
  String get channelDetailIntroTitle => 'チャンネル紹介';

  @override
  String get channelDetailTitle => 'チャンネル詳細';

  @override
  String get channelDetailCopiedId => 'チャンネルIDをコピーしました';

  @override
  String get channelDetailNoIntro => 'チャンネル紹介はまだありません';

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
  String get channelShareRequested => '参加申請済み';

  @override
  String get channelShareTextType => 'テキスト';

  @override
  String get channelShareTargetTitle => 'チャンネルの共有先';

  @override
  String get channelReviewTitle => 'チャンネル審査';

  @override
  String get channelReviewLoadFailedTitle => '審査の読み込みに失敗しました';

  @override
  String get channelReviewLoadFailedSubtitle => 'しばらくしてから再試行してください';

  @override
  String get channelReviewEmptyTitle => '参加申請はありません';

  @override
  String get channelReviewEmptySubtitle => '新しいチャンネル参加申請がここに表示されます。';

  @override
  String get channelReviewUnnamedChannel => '名称未設定のチャンネル';

  @override
  String get channelReviewApprove => '承認';

  @override
  String get channelReviewReject => '拒否';

  @override
  String get channelReviewStatusPending => '審査待ち';

  @override
  String get channelReviewStatusApproved => '承認済み';

  @override
  String get channelReviewStatusJoining => '参加中';

  @override
  String get channelReviewStatusJoined => '参加済み';

  @override
  String get channelReviewStatusJoinFailed => '参加失敗';

  @override
  String get channelReviewStatusRejected => '拒否済み';

  @override
  String channelReviewApproveFailed(String error) {
    return '承認に失敗しました：$error';
  }

  @override
  String channelReviewRejectFailed(String error) {
    return '拒否に失敗しました：$error';
  }

  @override
  String get channelReviewTimeNow => 'たった今';

  @override
  String get channelReviewTimeYesterday => '昨日';

  @override
  String get channelSearchHint => 'チャンネルを検索...';

  @override
  String get channelSearchTitle => 'チャンネル検索';

  @override
  String get channelSearchPrompt => 'チャンネルIDを入力して検索';

  @override
  String get channelSearchFailed => '検索に失敗しました。しばらくしてから再試行してください';

  @override
  String get channelSearchNetworkHint => 'ネットワークまたは対象ノードのアドレスを確認してください';

  @override
  String get channelSearchNoResults => 'チャンネルが見つかりません';

  @override
  String get channelSearchPrivateHint =>
      '非公開チャンネルは検索結果に表示されません。招待または共有カードから参加してください。';

  @override
  String get channelSearchSyncing => 'チャンネルを同期中です。しばらくしてから再試行してください';

  @override
  String get channelSearchUnnamed => '名称未設定のチャンネル';

  @override
  String get channelSearchPublicChannel => '公開チャンネル';

  @override
  String get channelSearchPublicApproval => '公開チャンネル · 参加には承認が必要';

  @override
  String get globalSearchTitle => '検索';

  @override
  String get globalSearchHint => '検索';

  @override
  String globalSearchNoResults(String query) {
    return '「$query」を含む内容は見つかりません';
  }

  @override
  String get globalSearchMessageFallback => 'メッセージ';

  @override
  String get globalSearchMessageLabel => 'メッセージ';

  @override
  String get globalSearchContactLabel => '連絡先';

  @override
  String get globalSearchGroupLabel => 'グループチャット';

  @override
  String get globalSearchChannelLabel => 'チャンネル';

  @override
  String get globalSearchChannelDetailPending => 'チャンネル詳細はまだ利用できません';

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
  String get channelPostNewTextPreview => '新しいテキスト投稿';

  @override
  String get channelPostNewImagePreview => '新しい画像投稿';

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
      '公式メール：liyananinsh@outlook.com\n\nヒント：フィードバックには問題が発生したページ、操作手順、端末モデルを記載してください。';

  @override
  String get meHelpFeedbackHeadline => 'より良い\nDirexio を一緒に';

  @override
  String get meHelpFeedbackPrompt => '問題や良いアイデアがありますか？';

  @override
  String meHelpFeedbackContactLine(Object email) {
    return 'お問い合わせ：$email';
  }

  @override
  String get meHelpFeedbackNote => 'いただいたフィードバックをもとに改善を続けます。';

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
  String get meFavoriteImagePreviewUrlMissing => 'お気に入り画像のURLが空のためプレビューできません';

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

  @override
  String get agentChatEmptyTitle => 'チャットを始めましょう';

  @override
  String get agentChatOfflineReply => '現在Agentはオフラインです。しばらくお待ちください';
}
