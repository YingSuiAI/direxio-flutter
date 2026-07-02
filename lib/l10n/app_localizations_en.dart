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
  String get homeDeleteChatTitle => 'Delete Chat History';

  @override
  String homeDeleteChatMessage(String name) {
    return 'Delete all chat history for \"$name\"? This cannot be undone.';
  }

  @override
  String homeConversationDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String homeDeleteChatFailed(String error) {
    return 'Failed to delete chat history: $error';
  }

  @override
  String get homeAgentConversationNotSynced =>
      'Agent conversation has not synced yet';

  @override
  String get homeDeleteChatMenu => 'Delete chat';

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
  String get blacklistRemove => 'Remove';

  @override
  String blacklistRemovedMessage(String name) {
    return 'Removed $name';
  }

  @override
  String get blacklistEmpty => 'No blocked contacts';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get changePasswordOldHint => 'Current password';

  @override
  String get changePasswordNewHint => 'New password';

  @override
  String get changePasswordConfirmHint => 'Re-enter new password';

  @override
  String get changePasswordRule => 'Password must be at least 8 characters';

  @override
  String get changePasswordOldTooShort =>
      'Current password must be at least 8 characters';

  @override
  String get changePasswordNewTooShort =>
      'New password must be at least 8 characters';

  @override
  String get changePasswordMismatch => 'The two passwords do not match';

  @override
  String get changePasswordSuccess => 'Password changed';

  @override
  String get changePasswordSubmitting => 'Submitting…';

  @override
  String get changePasswordSubmit => 'Submit changes';

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
  String get settingsDeactivateLogin => 'Delete Account';

  @override
  String get settingsDeactivateLoginConfirmTitle => 'Delete Account';

  @override
  String get settingsDeactivateLoginConfirmMessage =>
      'Within 14 days, logging in once will automatically cancel account deletion.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSend => 'Send';

  @override
  String get commonShare => 'Share';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOffline => 'Offline';

  @override
  String get toolCallDenied => 'Denied';

  @override
  String get toolCallArguments => 'Arguments';

  @override
  String get toolCallWarnings => 'Warnings';

  @override
  String get mcpPermissionTitle => 'MCP Permissions';

  @override
  String get mcpPermissionDescription =>
      'Manage which Agent accounts can call MCP tools.';

  @override
  String get mcpPermissionAuthorizeNewAgent => 'Authorize new Agent';

  @override
  String get mcpPermissionAuthorized => 'Authorized';

  @override
  String get mcpPermissionDisabled => 'Disabled';

  @override
  String get mcpPolicyRevokeAction => 'Revoke';

  @override
  String get mcpPolicyRevokeAccess => 'Revoke access';

  @override
  String get mcpPolicyAuditEmptyTitle => 'No audit records';

  @override
  String get mcpPolicyAuditEmptySubtitle =>
      'Tool call records will appear here';

  @override
  String get mcpPolicyCompleted => 'Completed';

  @override
  String get mcpPolicyWriteBadge => 'WRITE';

  @override
  String get mcpPolicyConfirmBeforeCall => 'Confirm before calling';

  @override
  String get mcpPolicySelectedRooms => 'Selected rooms';

  @override
  String get mcpPolicyExcludedRooms => 'Excluded rooms';

  @override
  String get mcpPolicyAddRoom => 'Add room';

  @override
  String get channelCreatedNotice => 'Channel created';

  @override
  String get channelManageEmptyTitle => 'No channels yet';

  @override
  String get channelManageEmptySubtitle => 'Created channels will appear here';

  @override
  String homeDetailPlaceholderTitle(String tabTitle) {
    return 'Select a $tabTitle item';
  }

  @override
  String get homeDetailPlaceholderChatsSubtitle =>
      'Open a conversation to view messages';

  @override
  String get homeDetailPlaceholderDefaultSubtitle =>
      'Select an item to view details';

  @override
  String get groupDetailMissing => 'Group chat not found';

  @override
  String groupDetailChatInfoTitle(int count) {
    return 'Group Chat Info ($count)';
  }

  @override
  String get groupDetailDissolveTitle => 'Dissolve group chat';

  @override
  String get groupDetailLeaveTitle => 'Leave group chat';

  @override
  String get groupDetailDissolveMessage =>
      'After dissolving, members will no longer be able to use this group chat.';

  @override
  String get groupDetailLeaveMessage =>
      'After leaving, you will no longer receive messages from this group chat.';

  @override
  String get groupDetailDissolveAction => 'Dissolve';

  @override
  String get groupDetailLeaveAction => 'Leave';

  @override
  String groupDetailLeaveOrDissolveFailed(String action, String error) {
    return '$action failed: $error';
  }

  @override
  String get groupDetailInvite => 'Invite';

  @override
  String get avatarAdjustTitle => 'Adjust avatar';

  @override
  String get avatarAdjustHint => 'Pinch to zoom or drag the image';

  @override
  String get avatarAdjustReset => 'Reset';

  @override
  String get avatarAdjustDone => 'Done';

  @override
  String avatarAdjustUpdateFailed(String error) {
    return 'Failed to update avatar: $error';
  }

  @override
  String get avatarAdjustPreviewNotReady => 'Avatar preview is not ready yet';

  @override
  String get avatarAdjustExportFailed => 'Failed to export avatar';

  @override
  String get profileInfoTitle => 'My Info';

  @override
  String get profileInfoAvatarEdit => 'Edit';

  @override
  String get profileInfoMatrixSessionMissing =>
      'Current Matrix session is missing';

  @override
  String profileInfoAvatarUpdateFailed(String error) {
    return 'Failed to update avatar: $error';
  }

  @override
  String get profileInfoNickname => 'Nickname';

  @override
  String get profileInfoDisplayName => 'Username';

  @override
  String get profileInfoGender => 'Gender';

  @override
  String get profileInfoGenderMale => 'Male';

  @override
  String get profileInfoGenderFemale => 'Female';

  @override
  String get profileInfoGenderUpdated => 'Gender updated';

  @override
  String get profileInfoBirthday => 'Birthday';

  @override
  String get profileInfoBirthdayPickerTitle => 'Select birthday';

  @override
  String get profileInfoBirthdayUpdated => 'Birthday updated';

  @override
  String get profileInfoEmail => 'Email';

  @override
  String get profileInfoEmailUpdated => 'Email updated';

  @override
  String get profileInfoUnset => 'Not set';

  @override
  String get profileInfoUidCopied => 'UID copied';

  @override
  String profileInfoEditTitle(String field) {
    return 'Edit $field';
  }

  @override
  String profileInfoInputHint(String field) {
    return 'Enter $field';
  }

  @override
  String get profileInfoDisplayNameEmpty => 'Username cannot be empty';

  @override
  String get profileInfoDisplayNameSystemName =>
      'Set a username that is different from the system account';

  @override
  String get profileInfoDisplayNameUpdated => 'Username updated';

  @override
  String profileInfoFieldUpdateFailed(String field, String error) {
    return 'Failed to update $field: $error';
  }

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
  String get channelManageStatOwner => 'Owner';

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
  String get createChannelTitle => 'Create Channel';

  @override
  String get createChannelNameTitle => 'Channel Name';

  @override
  String get createChannelNameHint => 'Enter';

  @override
  String get createChannelAvatarTitle => 'Upload Channel Avatar';

  @override
  String get createChannelAvatarSubtitle =>
      'Upload an image to use as the channel avatar';

  @override
  String get createChannelTypeTitle => 'Select Channel Type';

  @override
  String get createChannelTypeText => 'Text';

  @override
  String get createChannelTypeTextSubtitle => 'Members can chat freely';

  @override
  String get createChannelTypePosts => 'Posts';

  @override
  String get createChannelTypePostsSubtitle => 'Posts and comments';

  @override
  String get createChannelPermissionsTitle => 'Channel Permissions';

  @override
  String get createChannelPublicTitle => 'Public';

  @override
  String get createChannelPublicSubtitle =>
      'When off, members can only join by invite';

  @override
  String get createChannelApprovalTitle => 'Require Join Approval';

  @override
  String get createChannelApprovalSubtitle =>
      'When on, new members need channel approval';

  @override
  String get createChannelIntroTitle => 'Channel Intro';

  @override
  String get createChannelIntroHint => 'Enter channel intro...';

  @override
  String get createChannelSubmit => 'Create Channel';

  @override
  String get createChannelAvatarUploading =>
      'Channel avatar is uploading. Please wait.';

  @override
  String get createChannelNameRequired => 'Channel name is required';

  @override
  String get createChannelAvatarRequired => 'Upload a channel avatar';

  @override
  String get createChannelIntroRequired => 'Channel intro is required';

  @override
  String createChannelAvatarUploadFailed(String error) {
    return 'Failed to upload channel avatar: $error';
  }

  @override
  String get createChannelCreated => 'Channel created';

  @override
  String createChannelFailed(String error) {
    return 'Failed to create channel: $error';
  }

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
  String get channelManageSpeechOwnerReview => 'Owner review';

  @override
  String get channelManageSpeechMembers => 'Members can post';

  @override
  String get channelManageInviteOwner => 'Owner';

  @override
  String get channelManageInviteMembers => 'Invite Members';

  @override
  String get channelManageInviteMembersValue => 'By ID or link';

  @override
  String get channelManageMembersEmptyTitle => 'No member details yet';

  @override
  String get channelManageModerationEmptyTitle => 'No review details yet';

  @override
  String get channelManageAutoRules => 'Auto Review Rules';

  @override
  String get channelManageEditProfile => 'Edit Profile';

  @override
  String get channelManageManage => 'Manage';

  @override
  String get channelManageManaging => 'Managing';

  @override
  String channelManageChannelSummary(String visibility, String members) {
    return '$visibility channel · $members members';
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
  String get loginGettingStartedGuide => 'Getting Started Guide';

  @override
  String get loginProductOverview => 'Product Overview';

  @override
  String loginLocalMatrixApiPortHint(String recommendedAuthority) {
    return 'For local three-node tests, use $recommendedAuthority';
  }

  @override
  String loginLocalMatrixApiPortError(String recommendedAuthority) {
    return 'For local three-node tests, use $recommendedAuthority; do not enter the 127.0.0.1 Matrix API port.';
  }

  @override
  String get loginGuideIntroPrimary =>
      'Before your first use, prepare a functional AI Agent (such as Codex, OpenClaw, Hermes), along with cloud accounts and a domain name required for deployment.\nSend your Agent the repository address for the Direxio deployment skill:https://github.com/YingSuiAI/direxio-deployer';

  @override
  String get loginGuideIntroSecondary =>
      'so it can automatically complete installation, deployment, domain binding and plugin configuration following the standard workflow.\nOnce deployment succeeds, your Agent will return your IM access URL, initial account and password.\nAfter receiving these details, return to this App and enter the server address and password to sign in.\nOfficial Website: direxio.ai';

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
  String get agreementTerms => 'Terms of Service';

  @override
  String get agreementPrivacy => 'Privacy Policy';

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
  String get initAvatarRequired => 'Please set an avatar';

  @override
  String get initPortalDomainRequired => 'Please enter a Portal domain';

  @override
  String get initDisplayNameRequired => 'Please enter a display name';

  @override
  String get initOwnerTokenRequired =>
      'Please enter a long-term login passphrase';

  @override
  String get initConfirmOwnerTokenRequired =>
      'Please re-enter the long-term login passphrase';

  @override
  String get setupScanTitle => 'Scan to add server';

  @override
  String get setupScanHint => 'Scan the QR code on the Portal setup page';

  @override
  String get setupManualEntry => 'Enter manually';

  @override
  String get setupManualTitle => 'Add Portal manually';

  @override
  String get setupManualPortalLabel => 'Portal URL or QR link';

  @override
  String get setupManualPortalHint => 'p2p-im.com or p2pim://setup?...';

  @override
  String get setupManualCodeLabel => 'One-time setup code';

  @override
  String get setupManualCodeHint => '8 lowercase letters or digits';

  @override
  String get setupManualContinue => 'Continue';

  @override
  String get setupInvalidCode => 'Enter an 8-character setup code';

  @override
  String get setupPasswordTitle => 'Set login passphrase';

  @override
  String get setupPasswordQrCodeWillExpire =>
      'After setup, this QR setup code will expire';

  @override
  String get setupPasswordEnterCodeAndPassword =>
      'Enter this Portal\'s setup code and set a login passphrase';

  @override
  String get setupCodeHint => 'Setup code';

  @override
  String get setupNewPasswordHint => 'New login passphrase';

  @override
  String get setupConfirmNewPasswordHint => 'Re-enter login passphrase';

  @override
  String get setupPasswordSaving => 'Setting up…';

  @override
  String get setupPasswordDone => 'Finish setup';

  @override
  String get setupPasswordMismatch => 'The two passphrases do not match';

  @override
  String get addContactTitle => 'Add Friend';

  @override
  String get addContactEmptyHint =>
      'Enter the other person\'s domain to search';

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
  String get addContactOpenChatMissing =>
      'Failed to open chat: missing conversation information';

  @override
  String get addContactChatSyncing => 'Chat is syncing. Try again later.';

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
  String get contactSetRemark => 'Set Remark';

  @override
  String get contactRecommendFriend => 'Recommend to Friends';

  @override
  String get contactRecommendHim => 'Recommend him to friends';

  @override
  String get contactSearchChat => 'Search Chat';

  @override
  String get contactDeleteFriend => 'Delete Friend';

  @override
  String get contactBlockUserDetail => 'Block User';

  @override
  String get contactHisChannels => 'His Channels';

  @override
  String get contactChannelsLoading => 'Loading channels';

  @override
  String get contactChannelsLoadFailed => 'Failed to load channels';

  @override
  String get contactChannelsEmpty => 'No channels yet';

  @override
  String get contactChannelsUnnamed => 'Unnamed Channel';

  @override
  String get contactChannelsPostTag => 'Post';

  @override
  String get contactChannelsTextTag => 'Text';

  @override
  String get contactAddFriend => 'Add Friend';

  @override
  String get contactSupportManager => 'Support Manager';

  @override
  String get contactRoomMissingSearch =>
      'Missing contact room information. Cannot search chat.';

  @override
  String get contactRoomMissingBlock =>
      'Failed to block user: missing contact room information';

  @override
  String get contactRoomMissingDelete =>
      'Failed to delete friend: missing contact room information';

  @override
  String get contactRoomMissingRemark =>
      'Missing contact room information. Cannot save remark.';

  @override
  String get chatInfoTitle => 'Chat Info';

  @override
  String get chatInfoMissingConversation => 'Conversation not found';

  @override
  String get chatInfoSearchRecords => 'Search Chat';

  @override
  String get roomSearchTitle => 'Search Chat History';

  @override
  String get roomSearchHint => 'Search this chat';

  @override
  String get roomSearchEmptyPrompt => 'Enter keywords to search this chat';

  @override
  String roomSearchNoResults(String query) {
    return 'No messages found for \"$query\"';
  }

  @override
  String get roomSearchMessageFallback => 'Message';

  @override
  String get chatInfoContactMissingRemark =>
      'Missing contact information. Cannot set remark.';

  @override
  String get chatInfoSelfBlockDisabled => 'You cannot block the current user';

  @override
  String get chatInfoSelfReportDisabled => 'You cannot report the current user';

  @override
  String get chatInfoClearHistory => 'Clear Chat History';

  @override
  String get chatInfoClearHistoryConfirm =>
      'Clear all chat history? This cannot be undone.';

  @override
  String get chatInfoClearHistoryAction => 'Clear';

  @override
  String get chatInfoClearHistoryCleared => 'Chat history cleared';

  @override
  String chatInfoClearHistoryFailed(String error) {
    return 'Failed to clear chat history: $error';
  }

  @override
  String get chatInfoUidCopied => 'UID copied';

  @override
  String get chatInfoContactSyncing => 'Syncing contact information';

  @override
  String groupInfoTitle(int count) {
    return 'Chat Info ($count)';
  }

  @override
  String get groupInfoInvite => 'Invite';

  @override
  String get groupInfoRemove => 'Remove';

  @override
  String get groupInfoManagement => 'Group Management';

  @override
  String get groupInfoSearchRecords => 'Search Chat';

  @override
  String get groupInfoPinChat => 'Pin Chat';

  @override
  String get groupInfoMyNickname => 'My Nickname in This Group';

  @override
  String get groupInfoShowMemberNicknames => 'Show Member Nicknames';

  @override
  String get groupInfoReportGroup => 'Report Group';

  @override
  String get groupInfoDissolveGroup => 'Dissolve Group';

  @override
  String get groupInfoLeaveGroup => 'Leave Group';

  @override
  String get groupInfoNoRemovableMembers => 'No removable members';

  @override
  String get groupInfoRemoveMemberTitle => 'Remove Member';

  @override
  String groupInfoRemoveMemberConfirm(String name) {
    return 'Remove $name from this group?';
  }

  @override
  String groupInfoMemberRemoved(String name) {
    return 'Removed $name';
  }

  @override
  String groupInfoRemoveMemberFailed(String error) {
    return 'Failed to remove member: $error';
  }

  @override
  String get groupInfoRemarkTitle => 'Remark';

  @override
  String get groupInfoRemarkHint => 'Enter group remark';

  @override
  String get groupInfoRemarkCleared => 'Group remark cleared';

  @override
  String get groupInfoRemarkUpdated => 'Group remark updated';

  @override
  String get groupInfoNicknameHint => 'Enter group nickname';

  @override
  String get groupInfoNicknameEmpty => 'Group nickname cannot be empty';

  @override
  String get groupInfoCurrentUserMissing => 'Missing current user information';

  @override
  String get groupInfoNicknameUpdated => 'Group nickname updated';

  @override
  String groupInfoNicknameUpdateFailed(String error) {
    return 'Failed to set group nickname: $error';
  }

  @override
  String get groupInfoClearHistoryConfirm =>
      'Clear all chat history in this group? This cannot be undone.';

  @override
  String get groupInfoDissolveConfirm => 'Dissolve this group?';

  @override
  String get groupInfoLeaveConfirm => 'Leave this group?';

  @override
  String get groupInfoDissolveAction => 'Dissolve';

  @override
  String get groupInfoLeaveAction => 'Leave';

  @override
  String groupInfoLeaveFailed(String action, String error) {
    return 'Failed to $action group: $error';
  }

  @override
  String get groupCreateCreated => 'Group chat created';

  @override
  String groupCreateFailed(String error) {
    return 'Create failed: $error';
  }

  @override
  String get groupCreateNameHint => 'Enter a group name';

  @override
  String get groupInviteAddMembersTitle => 'Add group members';

  @override
  String get channelInviteAddMembersTitle => 'Invite channel members';

  @override
  String get groupInviteNoContacts => 'No contacts available to invite';

  @override
  String get groupInviteSend => 'Send Invite';

  @override
  String get groupManageNameTitle => 'Group Name';

  @override
  String get groupManageNameHint => 'Enter group name';

  @override
  String get groupManageNameEmpty => 'Group name cannot be empty';

  @override
  String get groupManageNameUpdated => 'Group name updated';

  @override
  String groupManageNameUpdateFailed(String error) {
    return 'Failed to update group name: $error';
  }

  @override
  String get groupManageAvatarUpdated => 'Group avatar updated';

  @override
  String groupManageAvatarUpdateFailed(String error) {
    return 'Failed to update group avatar: $error';
  }

  @override
  String get groupManageMuteEnabled => 'All-member mute enabled';

  @override
  String get groupManageMuteDisabled => 'All-member mute disabled';

  @override
  String groupManageMuteEnableFailed(String error) {
    return 'Failed to enable all-member mute: $error';
  }

  @override
  String groupManageMuteDisableFailed(String error) {
    return 'Failed to disable all-member mute: $error';
  }

  @override
  String get groupManageInvitePolicyUpdated =>
      'Member invite permission updated';

  @override
  String groupManageInvitePolicyUpdateFailed(String error) {
    return 'Failed to update member invite permission: $error';
  }

  @override
  String get mcpPolicySaved => 'Saved';

  @override
  String get mcpPolicyRevokeTitle => 'Revoke access?';

  @override
  String get mcpPolicyRevokeMessage =>
      'The Agent will immediately lose all MCP permissions.';

  @override
  String get mcpPolicyBlockedKeywordAdd => '+ Add';

  @override
  String get mcpPolicyBlockedKeywordTitle => 'Add Blocked Keyword';

  @override
  String get mcpPolicyBlockedKeywordHint =>
      'Messages matching this word will be masked';

  @override
  String get contactFriendRequestRestored =>
      'Previous conversation restored. You can continue chatting.';

  @override
  String get contactFriendRequestSent =>
      'Friend request sent. Waiting for acceptance.';

  @override
  String get contactDeleteConfirmTitle => 'Delete Friend';

  @override
  String get contactDeleteConfirmBody =>
      'After deletion, this contact will no longer appear and the conversation relationship will be updated.';

  @override
  String contactDeleteConfirmBodyWithName(String name) {
    return 'After deleting $name, the direct chat relationship will be removed for both sides.';
  }

  @override
  String get contactDeleteAction => 'Delete';

  @override
  String get contactDeleted => 'Friend deleted';

  @override
  String contactDeletedName(String name) {
    return 'Deleted $name';
  }

  @override
  String get contactApplied => 'Requested';

  @override
  String contactFollowFailed(String error) {
    return 'Follow failed: $error';
  }

  @override
  String contactUnfollowFailed(String error) {
    return 'Unfollow failed: $error';
  }

  @override
  String contactFriendRequestFailed(String error) {
    return 'Failed to send friend request: $error';
  }

  @override
  String get contactDeleteMissingRoom =>
      'Failed to delete friend: missing contact room information';

  @override
  String contactDeleteFailed(String error) {
    return 'Failed to delete friend: $error';
  }

  @override
  String get contactBlockConfirmTitle => 'Block User';

  @override
  String get contactBlockConfirmBody =>
      'Blocking will remove this contact and conversation relationship.';

  @override
  String get contactBlockAction => 'Block';

  @override
  String get contactBlocked => 'User blocked';

  @override
  String contactBlockFailed(String error) {
    return 'Failed to block user: $error';
  }

  @override
  String get contactReportSubmitted => 'Report submitted';

  @override
  String contactReportSubmitFailed(String error) {
    return 'Failed to submit report: $error';
  }

  @override
  String get reportReasonDialogTitle => 'Select a report reason';

  @override
  String get reportReasonHarassment => 'Harassment / Abuse';

  @override
  String get reportReasonSpam => 'Spam / Advertising';

  @override
  String get reportReasonSexual => 'Sexual / Inappropriate content';

  @override
  String get reportReasonViolence => 'Violence';

  @override
  String get reportReasonFraud => 'Fraud';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportReasonOtherHint => 'Describe the report reason';

  @override
  String get reportReasonPickImages => 'Upload images';

  @override
  String reportReasonImagesSelected(int count) {
    return '$count images selected';
  }

  @override
  String reportReasonPickImageFailed(String error) {
    return 'Failed to pick images: $error';
  }

  @override
  String get reportReasonSubmit => 'Submit';

  @override
  String get contactRemarkEmpty => 'Remark cannot be empty';

  @override
  String contactRemarkUpdateFailed(String error) {
    return 'Failed to update remark: $error';
  }

  @override
  String get contactRemarkUpdated => 'Remark updated';

  @override
  String get contactRemarkHint => 'Enter a remark';

  @override
  String get contactRemarkSave => 'Save';

  @override
  String contactShareText(String name, String userId) {
    return 'Recommended contact: $name\n$userId';
  }

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
  String get groupsListSearchHint => 'Search group chats';

  @override
  String get groupsListSyncing => 'Syncing group chats';

  @override
  String get groupsListEmpty => 'No group chats yet';

  @override
  String get groupsListNoMatches => 'No matching group chats';

  @override
  String get groupsListOwnerBadge => 'Owner';

  @override
  String get groupsListYesterday => 'Yesterday';

  @override
  String get requestsSearchHint => 'Search';

  @override
  String get requestsPendingHidden => 'Pending';

  @override
  String get requestsWaitingPeerAccept => 'Waiting for acceptance';

  @override
  String get requestsRejected => 'Rejected';

  @override
  String get requestsPeerRejected => 'Rejected by the other user';

  @override
  String get requestsAdded => 'Added';

  @override
  String get requestsBecameFriends => 'You are now friends';

  @override
  String get requestsEmptyPending => 'No friend requests';

  @override
  String get requestsEmptyAdded => 'No added contacts';

  @override
  String get requestsRequestAsFriend => 'Requested to add you as a friend';

  @override
  String get requestsMyRequestAsFriend =>
      'Me: requested to add you as a friend';

  @override
  String get requestsIncomingRequestMessage => 'Friend request';

  @override
  String get requestsFriendNoticeTitle => 'Friend request';

  @override
  String get requestsFriendNoticeFallback => 'Friend request notice';

  @override
  String get requestsGroupNoticeTitle => 'Group notice';

  @override
  String get requestsGroupNoticeFallback => 'Invited you to join a group chat';

  @override
  String get requestsChannelNoticeTitle => 'Channel notice';

  @override
  String get requestsChannelNoticeFallback => 'Invited you to join a channel';

  @override
  String get requestsView => 'View';

  @override
  String get requestsAccept => 'Accept';

  @override
  String get requestsReject => 'Reject';

  @override
  String get requestsCannotIdentifySource => 'Cannot identify request source';

  @override
  String get requestsAcceptSuccess => 'Friend request accepted';

  @override
  String get requestsRejectSuccess => 'Friend request rejected';

  @override
  String requestsAcceptFailed(String error) {
    return 'Accept failed: $error';
  }

  @override
  String requestsRejectFailed(String error) {
    return 'Reject failed: $error';
  }

  @override
  String get requestsInvalidDomainInput => 'Enter a valid domain or Matrix ID';

  @override
  String get requestsDomainNotProductUser =>
      'This domain is not a product user';

  @override
  String get requestsCannotAddSelf => 'You cannot add yourself';

  @override
  String requestsAlreadyContact(String name) {
    return '$name is already a contact';
  }

  @override
  String requestsAlreadySent(String name) {
    return 'You already sent a friend request to $name. Waiting for acceptance.';
  }

  @override
  String requestsRestoredConversation(String name) {
    return 'Restored old conversation with $name';
  }

  @override
  String requestsSentTo(String name) {
    return 'Sent friend request to $name';
  }

  @override
  String get createGroupTitle => 'Start Group Chat';

  @override
  String get createGroupMenuTitle => 'Start Group Chat';

  @override
  String get createGroupSetupTitle => 'Create Group Chat';

  @override
  String get createGroupDone => 'Done';

  @override
  String createGroupDoneWithCount(int count) {
    return 'Done($count)';
  }

  @override
  String get createGroupSubmit => 'Create';

  @override
  String get createGroupMembers => 'Group Members';

  @override
  String createGroupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

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
  String get qrScannerSupportUsers => 'User and group QR codes are supported';

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
  String get groupQrTitle => 'Group QR Code';

  @override
  String groupQrId(String roomId) {
    return 'Group ID $roomId';
  }

  @override
  String get groupQrHint => 'Scan this QR code to join the group.';

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
  String get groupChatUnknownMember => 'Unknown member';

  @override
  String groupChatVoiceRecordFailed(String error) {
    return 'Voice recording failed: $error';
  }

  @override
  String get groupChatRecordingTooShort => 'Recording is too short';

  @override
  String get groupChatOriginalMessageUnavailable =>
      'Original message is unavailable';

  @override
  String groupChatOpenFailed(String error) {
    return 'Open failed: $error';
  }

  @override
  String groupChatPlaybackFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String groupChatDownloadSaved(String filename) {
    return 'Saved to Files / Portal App / P2P IM Downloads / $filename';
  }

  @override
  String groupChatDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String groupChatSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String get groupChatCannotSendChannel =>
      'Join the channel before sending messages';

  @override
  String get groupChatCannotSendGroup =>
      'Join the group before sending messages';

  @override
  String get groupChatChannel => 'Channel';

  @override
  String get groupChatGroup => 'Group';

  @override
  String groupChatMissingTitle(String title) {
    return '$title not found';
  }

  @override
  String groupChatRecovering(String title) {
    return 'Restoring $title...';
  }

  @override
  String groupChatSyncTimeout(String title) {
    return '$title sync timed out. Check the network and retry.';
  }

  @override
  String groupChatCannotOpen(String title) {
    return 'This $title cannot be opened right now';
  }

  @override
  String groupChatMemberCount(int count) {
    return '$count members';
  }

  @override
  String get groupChatCalling => 'Group call in progress';

  @override
  String get groupChatVoiceCall => 'Voice call';

  @override
  String get groupChatDetails => 'Details';

  @override
  String get groupChatEmpty => 'No messages yet';

  @override
  String get groupChatMentionTitle => 'Choose who to mention';

  @override
  String get groupChatClose => 'Close';

  @override
  String get groupChatMentionSearchHint => 'Search group members';

  @override
  String get groupChatNoMentionMembers => 'No members to mention';

  @override
  String get groupChatNoMembersFound => 'No members found';

  @override
  String get groupChatImage => 'image';

  @override
  String get groupChatVideo => 'video';

  @override
  String get groupChatFile => 'file';

  @override
  String get messagePreviewSentImage => 'Sent an image';

  @override
  String get messagePreviewReceivedImage => 'Received an image';

  @override
  String get messagePreviewSentVideo => 'Sent a video';

  @override
  String get messagePreviewReceivedVideo => 'Received a video';

  @override
  String get messagePreviewSentFile => 'Sent a file';

  @override
  String get messagePreviewReceivedFile => 'Received a file';

  @override
  String get messagePreviewImageBracket => '[Image]';

  @override
  String get messagePreviewVideoBracket => '[Video]';

  @override
  String get messagePreviewFileBracket => '[File]';

  @override
  String get messagePreviewVoiceBracket => '[Voice]';

  @override
  String get messagePreviewChatRecordBracket => '[Chat history]';

  @override
  String get messagePreviewChannelBracket => '[Channel]';

  @override
  String get messagePreviewChannelShare => 'Channel share';

  @override
  String get messagePreviewGroupInvite => 'Group invitation';

  @override
  String get messagePreviewMessage => 'Message';

  @override
  String get messagePreviewSendFailed => 'Send failed';

  @override
  String get messagePreviewCallRejected => 'Call declined';

  @override
  String get messagePreviewCallMissed => 'Missed call';

  @override
  String get messagePreviewGroupCall => 'Group call';

  @override
  String get messagePreviewCall => 'Call';

  @override
  String get messagePreviewChatRecord => 'Chat history';

  @override
  String get messagePreviewGroupChatRecord => 'Group chat history';

  @override
  String get messagePreviewDirectChatRecord => 'Direct chat history';

  @override
  String get messagePreviewChannelChatRecord => 'Channel chat history';

  @override
  String get messagePreviewAgentChatRecord => 'Agent chat history';

  @override
  String get callReady => 'Ready to call';

  @override
  String get callCalling => 'Calling...';

  @override
  String get callInviteVoice => 'Inviting you to a voice call';

  @override
  String get callInviteVideo => 'Inviting you to a video call';

  @override
  String get callWaitingAnswer => 'Waiting for the other person to answer';

  @override
  String get callConnecting => 'Connecting...';

  @override
  String get callVideoConnected => 'Video call in progress';

  @override
  String get callVoiceConnected => 'Call in progress';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callFailed => 'Call failed';

  @override
  String get callPeerRejected => 'The other person declined';

  @override
  String get callRejected => 'Call declined';

  @override
  String get callPeerHungUp => 'The other person hung up';

  @override
  String get callMissed => 'Missed call';

  @override
  String get callNoPeer => 'Could not identify the call recipient';

  @override
  String get callAlreadyActive => 'A call is already in progress';

  @override
  String get callServiceNotReady => 'Call service is not ready';

  @override
  String get callStarting => 'Starting call';

  @override
  String get callRoomMissing => 'Call room does not exist';

  @override
  String get callStartFailed => 'Failed to start the call. Try again later';

  @override
  String get callOutgoingNetworkFailed =>
      'Call failed. Check your network or node and try again';

  @override
  String get callPeerNoResponse => 'No response. The call has ended';

  @override
  String get callNetworkUnstable => 'Network is unstable';

  @override
  String get callInterrupted => 'Call interrupted';

  @override
  String get callMediaPermissionVideo =>
      'Could not access camera or microphone. Check permissions';

  @override
  String get callMediaPermissionVoice =>
      'Could not access microphone. Check permissions';

  @override
  String get callPeerBusy => 'The other person is in a call';

  @override
  String get callMinimize => 'Minimize';

  @override
  String get callMiniRestore => 'Return to call';

  @override
  String get callCameraOn => 'Turn camera on';

  @override
  String get callCameraOff => 'Turn camera off';

  @override
  String get callCameraOffState => 'Camera off';

  @override
  String get callCameraStarting => 'Camera starting';

  @override
  String get callRemoteCameraUnavailable =>
      'The other person\'s camera is unavailable';

  @override
  String get callWaitingRemoteVideo => 'Waiting for video';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callEarpiece => 'Earpiece';

  @override
  String get callEncrypted => 'End-to-end encrypted';

  @override
  String get callReject => 'Decline';

  @override
  String get callAnswer => 'Answer';

  @override
  String get callMuted => 'Muted';

  @override
  String get callMute => 'Mute';

  @override
  String get callUnmute => 'Unmute';

  @override
  String get callHangup => 'Hang up';

  @override
  String get groupCallTitleVoice => 'Group voice call';

  @override
  String get groupCallTitleVideo => 'Group video call';

  @override
  String get groupCallInviteVoice => 'Inviting you to join a group voice call';

  @override
  String get groupCallInviteVideo => 'Inviting you to join a group video call';

  @override
  String get groupCallJoiningVoice => 'Joining group voice call';

  @override
  String get groupCallJoiningVideo => 'Joining group video call';

  @override
  String get groupCallConnectedVoice => 'Group voice call in progress';

  @override
  String get groupCallConnectedVideo => 'Group video call in progress';

  @override
  String get groupCallEnded => 'Group call ended';

  @override
  String get groupCallFailed => 'Group call failed';

  @override
  String get groupCallNetworkFailed =>
      'Failed to start group call. Check your network or node and try again';

  @override
  String get groupCallRoomMissing => 'Group chat does not exist';

  @override
  String get groupCallUnsupported =>
      'This group does not support group calls yet';

  @override
  String get groupCallCameraUnavailable => 'Camera unavailable';

  @override
  String get groupCallWaitingVideo => 'Waiting for video';

  @override
  String get groupCallWaitingMembersVideo => 'Waiting for group member video';

  @override
  String get groupCallMemberFallback => 'Member';

  @override
  String get groupCallWaitingMembers => 'Waiting for members to join';

  @override
  String groupCallParticipantCount(int count) {
    return '$count people in call';
  }

  @override
  String get groupCallReadyToJoin => 'Ready to join';

  @override
  String get groupCallBack => 'Back';

  @override
  String get groupCallJoin => 'Join';

  @override
  String get groupCallLeave => 'Leave';

  @override
  String get groupCallSelectVideoMembers => 'Select video members';

  @override
  String get groupCallSelectVoiceMembers => 'Select voice members';

  @override
  String get groupCallStartVideo => 'Start video call';

  @override
  String get groupCallStartVoice => 'Start voice call';

  @override
  String get groupCallSelectAtLeastOne => 'Select at least 1 member to invite';

  @override
  String groupCallSelectedMembers(int selected, int total) {
    return 'Selected $selected / $total members';
  }

  @override
  String get groupCallNoInviteMembers => 'No members available to invite';

  @override
  String get chatInputVoice => 'Voice';

  @override
  String get chatInputKeyboard => 'Keyboard';

  @override
  String get chatInputHoldToTalk => 'Hold to talk';

  @override
  String get chatInputReleaseToSend => 'Release to send';

  @override
  String get chatInputReleaseToCancel => 'Release to cancel';

  @override
  String get chatInputReleaseToCancelCompact => 'Release to cancel';

  @override
  String get chatInputReleaseToSendSwipeCancel =>
      'Release to send, swipe up to cancel';

  @override
  String get chatInputMore => 'More';

  @override
  String get chatAttachmentAlbum => 'Album';

  @override
  String get chatAttachmentCamera => 'Camera';

  @override
  String get chatAttachmentVideo => 'Video';

  @override
  String get chatAttachmentLocation => 'Location';

  @override
  String get chatAttachmentContactCard => 'Contact card';

  @override
  String get chatAttachmentFile => 'File';

  @override
  String get chatAttachmentNoImageSelected => 'No image selected';

  @override
  String get chatAttachmentNoPhotoTaken => 'No photo taken';

  @override
  String get chatAttachmentNoFileSelected => 'No file selected';

  @override
  String get chatAttachmentNoVideoSelected => 'No video selected';

  @override
  String get chatMediaPhoto => 'photo';

  @override
  String get chatMediaAudio => 'voice message';

  @override
  String get chatMediaGeneric => 'media';

  @override
  String chatMediaReadFailed(String label) {
    return 'Failed to read $label. Select it again.';
  }

  @override
  String chatMediaUploadFailed(String label) {
    return 'Failed to upload $label. Check the network and try again.';
  }

  @override
  String groupChatLocalMediaMissing(String label) {
    return 'The original local $label is missing. Select the $label again.';
  }

  @override
  String get groupChatCopied => 'Copied';

  @override
  String get groupChatDeleted => 'Deleted';

  @override
  String get groupChatCannotFavoriteSending =>
      'Messages being sent cannot be favorited';

  @override
  String get groupChatActionAvailableAfterSent =>
      'This action is available after the message is sent';

  @override
  String get groupChatNoRecallPermission =>
      'You do not have permission to recall this message';

  @override
  String get groupChatRecallTitle => 'Recall message';

  @override
  String get groupChatRecallBody =>
      'After recall, group members will no longer see this message.';

  @override
  String get groupChatCancel => 'Cancel';

  @override
  String get groupChatRecall => 'Recall';

  @override
  String get groupChatRecalled => 'Message recalled';

  @override
  String groupChatRecallFailed(String error) {
    return 'Failed to recall message: $error';
  }

  @override
  String groupChatDeleteFailed(String error) {
    return 'Failed to delete message: $error';
  }

  @override
  String get groupChatFavoriting => 'Saving to my node…';

  @override
  String get groupChatFavorited => 'Saved';

  @override
  String groupChatFavoriteFailed(String error) {
    return 'Favorite failed: $error';
  }

  @override
  String get groupChatForwardedRecord => 'Chat record forwarded';

  @override
  String groupChatForwardFailed(String error) {
    return 'Forward failed: $error';
  }

  @override
  String get groupChatCopy => 'Copy';

  @override
  String get groupChatForward => 'Forward';

  @override
  String get groupChatFavorite => 'Favorite';

  @override
  String get groupChatDelete => 'Delete';

  @override
  String get groupChatMultiSelect => 'Select';

  @override
  String get groupChatQuote => 'Quote';

  @override
  String get groupChatSelectMessage => 'Select message';

  @override
  String get groupChatCancelSelectMessage => 'Deselect message';

  @override
  String get chatAiSuggestions => 'AI suggestions';

  @override
  String get chatRecordForwardTitle => 'Forward Chat History';

  @override
  String get chatVideoCannotPlay => 'This video cannot be played';

  @override
  String get redPacketMineDetailAction => 'View sent details';

  @override
  String get redPacketDetailAction => 'View details';

  @override
  String get redPacketMineDetailTitle => 'Sent Red Packet';

  @override
  String get redPacketDetailTitle => 'Red Packet Details';

  @override
  String get groupChatMe => 'Me';

  @override
  String get groupChatMessageFallback => 'Message';

  @override
  String chatReplyTo(String sender) {
    return 'Reply to $sender';
  }

  @override
  String get groupChatQuotedMessage => 'Quoted message';

  @override
  String get groupChatRetryFile => 'Resend file';

  @override
  String get groupChatRetryMessage => 'Resend message';

  @override
  String get groupChatDownloading => 'Downloading';

  @override
  String get groupChatDownloaded => 'Downloaded';

  @override
  String get groupChatDownloadFile => 'Download file';

  @override
  String get groupChatRemovedCannotSend =>
      'You cannot send messages in a group you left';

  @override
  String get chatPeerAcceptBeforeSend =>
      'You can send messages after the other person accepts the friend request';

  @override
  String get contactHomeMissing => 'Contact not found';

  @override
  String get chatPeerDeletedContact =>
      'The other person deleted the contact relationship. Message not delivered.';

  @override
  String get chatRecallBody =>
      'After recall, the other person will no longer see this message.';

  @override
  String get chatImageSavedToAlbum => 'Original image saved to Photos';

  @override
  String get chatGroupSyncingRetryLater =>
      'Group chat is syncing. Try again later.';

  @override
  String get chatGroupInviteExpired =>
      'You were not invited or the invitation has expired';

  @override
  String chatJoinGroupFailed(String error) {
    return 'Failed to join group: $error';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonUser => 'User';

  @override
  String get sessionExpiredTitle => 'Signed in on another device';

  @override
  String get sessionExpiredMessage =>
      'This account was signed in on another device. Tap OK, then enter your password manually to sign in again.';

  @override
  String get chatRecordForwarded => 'Chat record forwarded';

  @override
  String chatRecordForwardFailed(String error) {
    return 'Forward failed: $error';
  }

  @override
  String chatRecordOpenFailed(String error) {
    return 'Failed to open: $error';
  }

  @override
  String chatRecordSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String chatRecordMessageCount(int count) {
    return '$count messages';
  }

  @override
  String get chatRecordEmptyDetails => 'No message details';

  @override
  String get chatVideoSavedToAlbum => 'Original video saved to album';

  @override
  String chatSaveFailed(String error) {
    return 'Save failed: $error';
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
  String get channelEmptyTitle => 'No channels yet';

  @override
  String get channelEmptySubtitle =>
      'Channels you join or create will appear here.';

  @override
  String get channelSyncingTitle => 'Syncing channels';

  @override
  String get channelSyncingSubtitle => 'Please wait';

  @override
  String get channelConversationQuoted => 'Quoted';

  @override
  String get channelConversationForwardPending =>
      'Forwarding will support real channel messages soon';

  @override
  String get channelConversationMultiSelectPending =>
      'Multi-select will support real channel messages soon';

  @override
  String get channelMyChannelsTitle => 'My Channels';

  @override
  String get channelJoinedSection => 'Joined';

  @override
  String get channelCreatedSection => 'Created';

  @override
  String get channelCreatedEmptyTitle => 'No channels created yet';

  @override
  String get channelJoinedEmptyTitle => 'No joined channels yet';

  @override
  String get channelCreatedEmptySubtitle =>
      'Channels you create will appear here.';

  @override
  String get channelJoinedEmptySubtitle =>
      'Channels you join will appear here.';

  @override
  String get channelOpenSyncing => 'Channel is syncing. Try again later.';

  @override
  String get channelDissolved => 'Channel has been dissolved';

  @override
  String get channelKindText => 'Text';

  @override
  String get channelKindPost => 'Post';

  @override
  String get channelAvatarFallback => 'C';

  @override
  String get channelMenuPin => 'Pin';

  @override
  String get channelMenuUnpin => 'Unpin';

  @override
  String channelMenuPinned(String name) {
    return 'Pinned \"$name\"';
  }

  @override
  String channelMenuUnpinned(String name) {
    return 'Unpinned \"$name\"';
  }

  @override
  String get channelMenuHide => 'Hide';

  @override
  String channelMenuHidden(String name) {
    return 'Hidden \"$name\"';
  }

  @override
  String get channelMenuDelete => 'Delete channel';

  @override
  String channelMenuDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get channelTimeMonday => 'Mon';

  @override
  String get channelTimeTuesday => 'Tue';

  @override
  String get channelTimeWednesday => 'Wed';

  @override
  String get channelTimeThursday => 'Thu';

  @override
  String get channelTimeFriday => 'Fri';

  @override
  String get channelTimeSaturday => 'Sat';

  @override
  String get channelTimeSunday => 'Sun';

  @override
  String get channelInfoTitle => 'Channel Info';

  @override
  String get channelInfoDetailAction => 'Channel details';

  @override
  String get channelInfoShareAction => 'Share channel';

  @override
  String get channelInfoReportAction => 'Report channel';

  @override
  String get channelInfoLeaveAction => 'Leave channel';

  @override
  String get channelInfoDissolveAction => 'Dissolve channel';

  @override
  String get channelInfoNoRemovableMembers => 'No removable members';

  @override
  String get channelInfoRemoveMembersTitle => 'Remove channel members';

  @override
  String channelInfoConfirmRemove(String name) {
    return 'Remove $name?';
  }

  @override
  String get channelInfoMemberRemoved => 'Member removed';

  @override
  String channelInfoRemoveFailed(String error) {
    return 'Failed to remove: $error';
  }

  @override
  String get channelInfoMuteAll => 'Mute all members';

  @override
  String get channelInfoMuteEnabled => 'All-member mute enabled';

  @override
  String get channelInfoMuteDisabled => 'All-member mute disabled';

  @override
  String channelInfoMuteEnableFailed(String error) {
    return 'Failed to enable all-member mute: $error';
  }

  @override
  String channelInfoMuteDisableFailed(String error) {
    return 'Failed to disable all-member mute: $error';
  }

  @override
  String get channelInfoReportMissingRoom =>
      'Report failed: missing channel room ID';

  @override
  String get channelInfoReportSubmitted => 'Report submitted';

  @override
  String channelInfoReportFailed(String error) {
    return 'Report failed: $error';
  }

  @override
  String get channelInfoShared => 'Channel shared';

  @override
  String channelInfoShareFailed(String error) {
    return 'Failed to share channel: $error';
  }

  @override
  String get channelInfoLeaveConfirm => 'Leave this channel?';

  @override
  String get channelInfoLeft => 'Left channel';

  @override
  String channelInfoLeaveFailed(String error) {
    return 'Failed to leave channel: $error';
  }

  @override
  String get channelInfoDissolveConfirm => 'Dissolve this channel?';

  @override
  String get channelInfoDissolved => 'Channel dissolved';

  @override
  String channelInfoDissolveFailed(String error) {
    return 'Failed to dissolve channel: $error';
  }

  @override
  String get channelDetailIntroTitle => 'Channel intro';

  @override
  String get channelDetailTitle => 'Channel details';

  @override
  String get channelDetailCopiedId => 'Channel ID copied';

  @override
  String get channelDetailNoIntro => 'No channel intro yet';

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
  String get channelShareRequested => 'Requested to join';

  @override
  String get channelShareTextType => 'Text';

  @override
  String get channelShareTargetTitle => 'Share channel to';

  @override
  String get channelReviewTitle => 'Channel Review';

  @override
  String get channelReviewLoadFailedTitle => 'Failed to load reviews';

  @override
  String get channelReviewLoadFailedSubtitle => 'Try again later';

  @override
  String get channelReviewEmptyTitle => 'No join requests';

  @override
  String get channelReviewEmptySubtitle =>
      'New channel join requests will appear here.';

  @override
  String get channelReviewUnnamedChannel => 'Untitled channel';

  @override
  String get channelReviewApprove => 'Approve';

  @override
  String get channelReviewReject => 'Reject';

  @override
  String get channelReviewStatusPending => 'Pending';

  @override
  String get channelReviewStatusApproved => 'Approved';

  @override
  String get channelReviewStatusJoining => 'Joining';

  @override
  String get channelReviewStatusJoined => 'Joined';

  @override
  String get channelReviewStatusJoinFailed => 'Join failed';

  @override
  String get channelReviewStatusRejected => 'Rejected';

  @override
  String channelReviewApproveFailed(String error) {
    return 'Failed to approve: $error';
  }

  @override
  String channelReviewRejectFailed(String error) {
    return 'Failed to reject: $error';
  }

  @override
  String get channelReviewTimeNow => 'Just now';

  @override
  String get channelReviewTimeYesterday => 'Yesterday';

  @override
  String get channelSearchHint => 'Search channels...';

  @override
  String get channelSearchTitle => 'Search channels';

  @override
  String get channelSearchPrompt => 'Enter a channel ID to find a channel';

  @override
  String get channelSearchFailed => 'Search failed. Try again later.';

  @override
  String get channelSearchNetworkHint =>
      'Check the network or target node address';

  @override
  String get channelSearchNoResults => 'No channels found';

  @override
  String get channelSearchPrivateHint =>
      'Private channels do not appear in search results. Join them through an invite or share card.';

  @override
  String get channelSearchSyncing => 'Channel is syncing. Try again later.';

  @override
  String get channelSearchUnnamed => 'Untitled channel';

  @override
  String get channelSearchPublicChannel => 'Public channel';

  @override
  String get channelSearchPublicApproval =>
      'Public channel · Approval required';

  @override
  String get globalSearchTitle => 'Search';

  @override
  String get globalSearchHint => 'Search';

  @override
  String globalSearchNoResults(String query) {
    return 'No content found for \"$query\"';
  }

  @override
  String get globalSearchMessageFallback => 'Message';

  @override
  String get globalSearchMessageLabel => 'Message';

  @override
  String get globalSearchContactLabel => 'Contact';

  @override
  String get globalSearchGroupLabel => 'Group chat';

  @override
  String get globalSearchChannelLabel => 'Channel';

  @override
  String get globalSearchChannelDetailPending =>
      'Channel details are not available yet';

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
  String get channelPostNewTextPreview => 'New text post';

  @override
  String get channelPostNewImagePreview => 'New image post';

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
      'Official email: liyananinsh@outlook.com\n\nTip: please include the page, steps to reproduce, and device model in your feedback.';

  @override
  String get meHelpFeedbackHeadline => 'Build a Better\nDirexio Together';

  @override
  String get meHelpFeedbackPrompt => 'Found an issue or have a great idea?';

  @override
  String meHelpFeedbackContactLine(Object email) {
    return 'Contact Us : $email';
  }

  @override
  String get meHelpFeedbackNote =>
      'We will keep optimizing based on your feedback.';

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
  String get meFavoriteImagePreviewUrlMissing =>
      'Favorite image URL is empty and cannot be previewed';

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

  @override
  String get agentChatEmptyTitle => 'Start our chat';

  @override
  String get agentChatOfflineReply =>
      'Agent is currently offline. Please wait patiently.';
}
