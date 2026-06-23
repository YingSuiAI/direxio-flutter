// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Direxio';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageDialogTitle => 'Language';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabChannels => 'Channels';

  @override
  String get tabMe => 'Me';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsFollowSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsFavorites => 'Favorites';

  @override
  String get settingsPrivacySecurity => 'Privacy & Security';

  @override
  String get settingsBlacklist => 'Blocked Contacts';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get settingsMessagesNotifications => 'Messages & Notifications';

  @override
  String get settingsDoNotDisturb => 'Do Not Disturb';

  @override
  String get settingsMessageSound => 'New Message Sound';

  @override
  String get settingsMessageVibration => 'New Message Vibration';

  @override
  String get settingsOther => 'Other';

  @override
  String get settingsAboutUs => 'About Us';

  @override
  String get settingsClearChats => 'Clear Chat History';

  @override
  String get settingsClearChatsClearing => 'Clearing...';

  @override
  String get settingsClearChatsConfirmMessage =>
      'This will clear local chat history, unread recovery, and media thumbnail cache. Messages on the server will not be deleted.';

  @override
  String get settingsClearChatsSuccess => 'Chat history cleared';

  @override
  String get settingsClearChatsFailure =>
      'Failed to clear chat history. Try again later.';

  @override
  String get settingsLogout => 'Log Out';

  @override
  String get settingsLogoutConfirmTitle => 'Log Out';

  @override
  String get settingsLogoutConfirmMessage =>
      'Are you sure you want to log out?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonShare => 'Share';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutEmail => 'Email';

  @override
  String get aboutVersionUpdates => 'Version';

  @override
  String get channelManageTitle => 'Channel Management';

  @override
  String get channelManageProfileTitle => 'Channel Profile';

  @override
  String get channelManageMembersTitle => 'Members & Roles';

  @override
  String get channelManageModerationTitle => 'Content Review';

  @override
  String get channelManageTabOverview => 'My Channels';

  @override
  String get channelManageTabProfile => 'Profile';

  @override
  String get channelManageTabMembers => 'Roles';

  @override
  String get channelManageTabModeration => 'Review';

  @override
  String get channelManageStatSubscribers => 'Subscribers';

  @override
  String get channelManageStatTodayMessages => 'Messages Today';

  @override
  String get channelManageStatPending => 'Pending';

  @override
  String get channelManageStatAdmins => 'Admins';

  @override
  String get channelManageStatNewToday => 'New Today';

  @override
  String get channelManageStatMuted => 'Muted';

  @override
  String get channelManageStatReports => 'Reports';

  @override
  String get channelManageStatAutoApproved => 'Auto Approved';

  @override
  String get channelManageMyChannels => 'My Channels';

  @override
  String get channelManageCreateChannel => 'Create Channel';

  @override
  String get channelManageCreateChannelValue => 'Name, avatar, bio';

  @override
  String get channelManageInviteLinks => 'Invite Links';

  @override
  String channelManageInviteLinksValue(int count) {
    return '$count active';
  }

  @override
  String get channelManagePermissions => 'Channel Permissions';

  @override
  String get channelManageVisibility => 'Visibility';

  @override
  String get channelManageSpeechPermission => 'Posting Permission';

  @override
  String get channelManageInvitePermission => 'Invite Permission';

  @override
  String get channelManageMessageEncryption => 'Message Encryption';

  @override
  String get channelManageEnabled => 'Enabled';

  @override
  String get channelManageDisabled => 'Disabled';

  @override
  String get channelManageDisableChannel => 'Disable Channel';

  @override
  String get channelManageVisibilityPublic => 'Public';

  @override
  String get channelManageVisibilityPrivate => 'Private';

  @override
  String get channelManageSpeechAdminReview => 'Admin review';

  @override
  String get channelManageSpeechMembers => 'Members can post';

  @override
  String get channelManageInviteAdmin => 'Admin';

  @override
  String get channelManageInviteAdmins => 'Invite Admins';

  @override
  String get channelManageInviteAdminsValue => 'By ID or link';

  @override
  String get channelManageOwnerOnline => 'Owner · Online';

  @override
  String get channelManageAdminModeration => 'Admin · Moderation';

  @override
  String get channelManageAdminOperations => 'Admin · Operations';

  @override
  String get channelManageBotRiskControl => 'Bot · Risk control';

  @override
  String get channelManageReviewSpeechTitle => 'New member posting request';

  @override
  String get channelManageReviewSpeechBody =>
      'User @ray requested to post a node sync note in the announcements channel.';

  @override
  String get channelManageReviewSpeechTag => 'Post';

  @override
  String get channelManageReviewLinkTitle => 'Link risk warning';

  @override
  String get channelManageReviewLinkBody =>
      'An external link was detected and needs admin approval before display.';

  @override
  String get channelManageReviewLinkTag => 'Link';

  @override
  String get channelManageReviewReportTitle => 'Reported message';

  @override
  String get channelManageReviewReportBody =>
      '2 members reported this message for repeated advertising.';

  @override
  String get channelManageReviewReportTag => 'Report';

  @override
  String get channelManageAutoRules => 'Auto Review Rules';

  @override
  String get channelManageAutoRulesValue => 'Keywords / links / rate';

  @override
  String get channelManageEditProfile => 'Edit Profile';

  @override
  String get channelManageManage => 'Manage';

  @override
  String get channelManageManaging => 'Managing';

  @override
  String get channelManageApprove => 'Approve';

  @override
  String get channelManageReject => 'Reject';

  @override
  String get channelManageDefaultChannelName => 'P2P Matrix Announcements';

  @override
  String get channelManageDefaultChannelDescription =>
      'Project announcements, node status, and releases';

  @override
  String channelManageChannelSummary(
      String visibility, String members, int messages) {
    return '$visibility channel · $members members · $messages today';
  }

  @override
  String channelManageComingSoon(String label) {
    return '$label is not connected yet';
  }

  @override
  String get loginTitle => 'Portal IM';

  @override
  String get loginSubtitle =>
      'Use your Portal domain and password to enter decentralized messaging';

  @override
  String get loginDomainHint => 'your-domain';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginButton => 'Log In';

  @override
  String get loginButtonLoading => 'Logging in…';

  @override
  String get loginTermsOpenFailed =>
      'Unable to open the Terms and Privacy Policy';

  @override
  String get loginAgreementRequiredTitle => 'Please review and agree';

  @override
  String get loginAgreementRequiredMessage =>
      'You need to agree to the Terms and Privacy Policy before logging in.';

  @override
  String get loginAgreementConfirmAndLogin => 'Agree and Log In';

  @override
  String get agreementPrefix => 'I have read and agree to ';

  @override
  String get agreementTermsPrivacy => 'Terms & Privacy Policy';

  @override
  String get initPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get initPasswordMismatch => 'The two passwords do not match';

  @override
  String get initPortalDomainHint => 'Portal domain';

  @override
  String get initDisplayNameHint => 'Display name';

  @override
  String get initOwnerTokenHint => 'Long-term login passphrase';

  @override
  String get initPasswordHint => 'Password';

  @override
  String get initConfirmOwnerTokenHint => 'Re-enter long-term login passphrase';

  @override
  String get initConfirmPasswordHint => 'Re-enter password';

  @override
  String get initPasswordRule => 'At least 8 characters';

  @override
  String get initButton => 'Confirm';

  @override
  String get initButtonLoading => 'Initializing…';

  @override
  String get initExistingAccountLogin => 'Already have an account? Log in';

  @override
  String get addContactTitle => 'Add Friend';

  @override
  String get addContactEmptyHint => 'Enter a nickname or Portal URL to search';

  @override
  String get addContactDomainNotProductUser =>
      'This domain is not a product user';

  @override
  String get addContactMessageAfterAdding =>
      'Add this friend before sending messages';

  @override
  String get addContactVoiceAfterAdding =>
      'Add this friend before starting an audio call';

  @override
  String get addContactVideoAfterAdding =>
      'Add this friend before starting a video call';

  @override
  String get addContactVerificationTitle => 'Friend Verification';

  @override
  String get addContactVerificationMessageTitle => 'Send friend request';

  @override
  String get addContactVerificationSend => 'Send Request';

  @override
  String get addContactRequestSent =>
      'Friend request sent. Waiting for acceptance.';

  @override
  String get addContactCannotAddSelf => 'You cannot add yourself';

  @override
  String addContactRequestFailed(String error) {
    return 'Failed to send friend request: $error';
  }

  @override
  String get contactSendMessage => 'Message';

  @override
  String get contactVoiceCall => 'Audio Call';

  @override
  String get contactVideoCall => 'Video Call';

  @override
  String get contactMuteMessages => 'Mute Messages';

  @override
  String get contactBlockUser => 'Block User';

  @override
  String get contactReportUser => 'Report User';

  @override
  String get contactReportTodo => 'Report feature is not connected yet';

  @override
  String get contactFriendRequested => 'Requested';

  @override
  String get contactApplyFriend => 'Add Friend';

  @override
  String get contactsSearchHint => 'ID / Nickname / Email';

  @override
  String get contactsNewFriends => 'New Friends';

  @override
  String get contactsNewGroup => 'New Group Chat';

  @override
  String get contactsMyGroups => 'My Groups';

  @override
  String get contactsGroups => 'Groups';

  @override
  String get contactsFollows => 'Following';

  @override
  String get createGroupTitle => 'Start Group Chat';

  @override
  String get createGroupDone => 'Done';

  @override
  String get createGroupEmptyTitle => 'No friends to invite';

  @override
  String get createGroupEmptySubtitle =>
      'Add friends before starting a group chat';

  @override
  String get createGroupNoResultsTitle => 'No friends found';

  @override
  String get createGroupNoResultsSubtitle =>
      'Try another ID, nickname, or email';

  @override
  String get createGroupDefaultName => 'Group Chat';

  @override
  String createGroupSingleName(String name) {
    return '$name\'s Group Chat';
  }

  @override
  String createGroupMultipleName(String names) {
    return '$names\'s Group Chat';
  }

  @override
  String contactsCount(int count) {
    return 'Contacts ($count)';
  }

  @override
  String get qrInvalidFormat => 'Invalid QR code format';

  @override
  String get qrInvalidUser => 'Invalid user QR code';

  @override
  String get qrInvalidGroup => 'Invalid group QR code';

  @override
  String get qrUnsupportedGroup => 'This group QR code is not supported yet';

  @override
  String get qrScannerInstruction =>
      'Place the QR code inside the frame to scan automatically';

  @override
  String get qrScannerSupportUsers => 'User QR codes are supported';

  @override
  String get meQrTitle => 'My QR Code';

  @override
  String get meQrHint => 'Scan this QR code to add me as a friend.';

  @override
  String get meQrSaveToAlbum => 'Save to Photos';

  @override
  String get meQrSaving => 'Saving...';

  @override
  String get meQrSaveSuccess => 'Saved to Photos';

  @override
  String get meQrSaveFailed => 'Failed to save. Check Photos permission.';

  @override
  String get meQrSaveTodo => 'Save to Photos is not connected yet';

  @override
  String get meQrUnconnectedDomain => 'No connected domain';

  @override
  String get groupInviteTitle => 'Group invitation';

  @override
  String groupInviteJoining(String groupName) {
    return 'Joining \"$groupName\"';
  }

  @override
  String groupInviteBody(String inviter, String groupName) {
    return '$inviter invited you to join \"$groupName\"';
  }

  @override
  String get groupInviteFallbackInviter => 'They';

  @override
  String get groupInviteJoinButton => 'Join Group';

  @override
  String get groupInviteJoiningButton => 'Joining…';

  @override
  String get groupInviteAlreadyJoined => 'You are already in this group';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get sessionExpiredTitle => 'Signed in on another device';

  @override
  String get sessionExpiredMessage => 'Please sign in again';

  @override
  String get chatRecordForwarded => 'Chat record forwarded';

  @override
  String chatRecordForwardFailed(String error) {
    return 'Forward failed: $error';
  }

  @override
  String get channelFallbackTitle => 'Channel';

  @override
  String get channelMissingTitle => 'Channel not found';

  @override
  String get channelMissingSubtitle =>
      'This channel may be private, deleted, or temporarily unreachable.';

  @override
  String get channelNoPublicContentTitle => 'No public content yet';

  @override
  String get channelNoPublicContentSubtitle =>
      'Join the channel to see future posts.';

  @override
  String channelJoinFailed(String error) {
    return 'Failed to join channel: $error';
  }

  @override
  String get channelJoinJoined => 'Joined';

  @override
  String get channelJoinPending => 'Pending review';

  @override
  String get channelJoinSyncing => 'Syncing';

  @override
  String get channelJoinRetry => 'Join again';

  @override
  String get channelJoinApply => 'Request to join';

  @override
  String get channelJoinAction => 'Join channel';

  @override
  String get channelJoinProcessing => 'Processing';

  @override
  String get channelPostEmptyTitle => 'No channel posts yet';

  @override
  String get channelPostEmptySubtitle =>
      'Posts will appear here after publishing.';

  @override
  String get channelPostPublish => 'Post';

  @override
  String get channelPostPublishing => 'Posting';

  @override
  String get channelPostPlaceholder => 'Write a post...';

  @override
  String channelPostPublishFailed(String error) {
    return 'Failed to publish: $error';
  }

  @override
  String channelPostImageUploadFailed(String error) {
    return 'Image upload failed: $error';
  }

  @override
  String get channelPostDeleted => 'Post deleted';

  @override
  String channelPostDeleteFailed(String error) {
    return 'Failed to delete post: $error';
  }

  @override
  String get channelPostDeleteTooltip => 'Delete post';

  @override
  String get channelPostType => 'Post';

  @override
  String get channelPostDefaultTitle => 'My post';

  @override
  String get channelPostExpandMore => 'Expand';

  @override
  String get channelPostCollapse => 'Collapse';

  @override
  String get channelPostCommentHint => 'Write a comment...';

  @override
  String get channelPostDetailTitle => 'Post Details';

  @override
  String get channelPostCommentLoadFailed => 'Failed to load comments';

  @override
  String get channelPostNoMoreComments => 'No more comments';

  @override
  String get channelPostIdCopied => 'Post ID copied';

  @override
  String get channelPostReply => 'Reply';

  @override
  String get channelPostCollapseComments => 'Hide comments';

  @override
  String channelPostCommentCount(int count) {
    return '$count comments';
  }

  @override
  String channelPostViewComments(String countText) {
    return 'View comments$countText';
  }

  @override
  String get channelPostMissingTitle => 'Post not found';

  @override
  String get channelPostMissingSubtitle =>
      'This post may have been deleted or has not synced to this device.';

  @override
  String get meMenuTitle => 'Menu';

  @override
  String get meMyFavorites => 'My Favorites';

  @override
  String get meMyLikes => 'My Likes';

  @override
  String get meMyComments => 'My Comments';

  @override
  String get meFavoritesTitle => 'Favorites';

  @override
  String get meLikesTitle => 'Likes';

  @override
  String get meCommentsTitle => 'Comments';

  @override
  String get meHelpFeedbackTitle => 'Help & Feedback';

  @override
  String get meHelpFeedbackBody =>
      'Official email: support@direxio.ai\n\nTip: please include the page, steps to reproduce, and device model in your feedback.';

  @override
  String get meHelpFeedbackOk => 'Got it';

  @override
  String get meUidCopied => 'UID copied';

  @override
  String get meFavoriteDetailTitle => 'Favorite Details';

  @override
  String get meFavoriteDeleteAction => 'Delete Favorite';

  @override
  String get meFavoriteRemoveTitle => 'Remove Favorite';

  @override
  String get meFavoriteDeleteConfirm => 'Delete this favorite?';

  @override
  String get meFavoriteDeleted => 'Favorite deleted';

  @override
  String meFavoriteDeleteFailed(String error) {
    return 'Failed to delete favorite: $error';
  }

  @override
  String get meFavoritesLoadFailed => 'Failed to load favorites';

  @override
  String get meFavoritesEmptyTitle => 'No favorites yet';

  @override
  String get meFavoritesEmptySubtitle =>
      'Long-press chat messages to save them here.';

  @override
  String get meLikesLoadFailed => 'Failed to load likes';

  @override
  String get meLikesEmptyTitle => 'No likes yet';

  @override
  String get meLikesEmptySubtitle =>
      'Channel posts you liked will appear here.';

  @override
  String get meLikedPost => 'You liked this post';

  @override
  String meReactedWith(String value) {
    return 'You reacted: $value';
  }

  @override
  String get meCommentsLoadFailed => 'Failed to load comments';

  @override
  String get meCommentsEmptyTitle => 'No comments yet';

  @override
  String get meCommentsEmptySubtitle =>
      'Comments you leave under channel posts will appear here.';

  @override
  String get meCommentFallback => 'Comment';

  @override
  String meCommentedWith(String body) {
    return 'You commented: $body';
  }

  @override
  String get meChannelPostFallback => 'Channel post';

  @override
  String get meFavoriteMessageFallback => 'Favorite message';

  @override
  String get meFavoriteUnknownSender => 'Unknown';

  @override
  String get meFavoriteTypeText => 'Text';

  @override
  String get meFavoriteTypeImage => 'Image';

  @override
  String get meFavoriteTypeVideo => 'Video';

  @override
  String get meFavoriteTypeFile => 'File';

  @override
  String get meFavoriteTypeChatRecord => 'Chat record';

  @override
  String get meFavoriteTypeAudio => 'Voice';

  @override
  String get meFavoriteTypeLink => 'Link';

  @override
  String get meFavoriteTypeMessage => 'Message';

  @override
  String get meFavoriteFromDirect => 'From direct chat';

  @override
  String meFavoriteFromDirectWithSender(String sender) {
    return 'From direct chat with $sender';
  }

  @override
  String get meFavoriteFromGroup => 'From group chat';

  @override
  String meFavoriteFromGroupWithSender(String sender) {
    return 'From group chat · $sender';
  }

  @override
  String get meFavoriteFromChannel => 'From channel';

  @override
  String meFavoriteFromChannelWithSender(String sender) {
    return 'From channel · $sender';
  }

  @override
  String get meFavoriteFromAgent => 'From Agent';

  @override
  String get meFavoriteFromChat => 'From chat';

  @override
  String meFavoriteFromChatWithSender(String sender) {
    return 'From chat · $sender';
  }

  @override
  String get meFavoriteDirectChatRecord => 'Direct chat record';

  @override
  String meFavoriteDirectChatRecordWithName(String name) {
    return 'Chat record with $name';
  }

  @override
  String get meFavoriteGroupChatRecord => 'Group chat record';

  @override
  String meFavoriteGroupChatRecordWithName(String name) {
    return 'Group chat record \"$name\"';
  }

  @override
  String get meFavoriteChannelChatRecord => 'Channel chat record';

  @override
  String meFavoriteChannelChatRecordWithName(String name) {
    return 'Channel chat record \"$name\"';
  }

  @override
  String get meFavoriteAgentChatRecord => 'Chat record with Agent';

  @override
  String meFavoriteDetailBody(String title) {
    return 'Favorite details\n$title\n1 message';
  }

  @override
  String get commonMe => 'Me';

  @override
  String get commonJustNow => 'Just now';
}
