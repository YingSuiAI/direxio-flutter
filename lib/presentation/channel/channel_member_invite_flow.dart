import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_record_forwarding.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../widgets/portal_avatar.dart';
import 'channel_info_data.dart';
import 'channel_share.dart';

Future<void> showInviteChannelMembersFlow(
  BuildContext context,
  WidgetRef ref, {
  required ChannelInfoData channel,
  required Set<String> existingMemberMxids,
}) async {
  final channelId = channel.id.trim();
  final roomId = channel.roomId.trim();
  if (channelId.isEmpty && roomId.isEmpty) return;

  final candidates = channelMemberInviteCandidates(
    ref.read(asSyncCacheProvider),
    existingMemberMxids,
  );
  final matrixClient = ref.read(matrixClientProvider);
  final selected = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => _InviteChannelMembersDialog(
      contacts: candidates,
      client: matrixClient,
    ),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  try {
    final selectedContacts = [
      for (final contact in candidates)
        if (selected.contains(contact.userId.trim())) contact,
    ];
    final sendableContacts = selectedContacts
        .where((contact) => contact.roomId.trim().isNotEmpty)
        .toList(growable: false);
    final skippedCount = selectedContacts.length - sendableContacts.length;
    final asClient = ref.read(asClientProvider);
    var sentCount = 0;
    var failedCount = 0;
    for (final contact in sendableContacts) {
      try {
        final directRoomId = contact.roomId.trim();
        final directRoom = matrixClient.getRoomById(directRoomId);
        if (directRoom == null) {
          throw StateError('目标私聊未同步到本地');
        }
        final grant = await asClient.createChannelInviteGrant(
          channelId: channelId,
          roomId: roomId,
          shareRoomId: directRoomId,
          reason: 'channel_member_invite',
        );
        final grantId = grant.grantId.trim();
        if (grantId.isEmpty) {
          throw StateError('频道邀请授权缺少 grant_id');
        }
        final payload = channelSharePayloadWithInviteGrant(
          _channelInvitePayload(channel, grant),
          grantId: grantId,
          shareRoomId: grant.shareRoomId.trim().isEmpty
              ? directRoomId
              : grant.shareRoomId.trim(),
        );
        await directRoom.sendEvent({
          'msgtype': MessageTypes.Text,
          'body': payload.body,
          'message_type': channelShareMessageType,
          chatRecordMatrixMarkerKey: channelShareMessageType,
          channelShareMatrixPayloadKey: payload.asDraft.toJson(),
        });
        sentCount++;
      } on Object catch (error) {
        if (error is AsClientException && error.statusCode == 403) {
          rethrow;
        }
        failedCount++;
      }
    }
    if (sentCount > 0) {
      unawaited(matrixClient.oneShotSync());
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _channelInviteResultMessage(
            sentCount: sentCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
          ),
        ),
      ),
    );
  } on Object catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_channelInviteFailureMessage(e))),
    );
  }
}

List<AsSyncContact> channelMemberInviteCandidates(
  AsSyncCacheState syncCache,
  Set<String> existingMemberMxids,
) {
  final existing = existingMemberMxids
      .map((mxid) => mxid.trim())
      .where((mxid) => mxid.isNotEmpty)
      .toSet();
  final seen = <String>{};
  final out = <AsSyncContact>[];
  final mergedMxids = {
    for (final contact in syncCache.contacts)
      if (contact.userId.trim().isNotEmpty) contact.userId.trim(),
  };
  final rawContacts = <AsSyncContact>[
    ...syncCache.contacts,
    for (final contact
        in syncCache.bootstrap?.contacts ?? const <AsSyncContact>[])
      if (!mergedMxids.contains(contact.userId.trim())) contact,
  ];
  for (final contact in rawContacts) {
    final mxid = contact.userId.trim();
    if (mxid.isEmpty ||
        contact.status.trim() != 'accepted' ||
        existing.contains(mxid) ||
        !seen.add(mxid)) {
      continue;
    }
    out.add(contact);
  }
  return List.unmodifiable(out);
}

ChannelSharePayload _channelInvitePayload(
  ChannelInfoData channel,
  AsChannelInviteGrant grant,
) {
  final grantChannel = grant.channel;
  return channelSharePayloadFromChannel(
    channelId:
        _firstNonEmpty(channel.id, grant.channelId, grantChannel?.channelId),
    roomId: _firstNonEmpty(channel.roomId, grant.roomId, grantChannel?.roomId),
    homeDomain: _firstNonEmpty(channel.domain, grantChannel?.homeDomain),
    name: _firstNonEmpty(channel.name, grantChannel?.name, '频道'),
    description: _firstNonEmpty(channel.description, grantChannel?.description),
    avatarUrl: _firstNonEmpty(channel.avatarUrl, grantChannel?.avatarUrl),
    visibility: _firstNonEmpty(
      channel.visibility,
      grantChannel?.visibility,
      asChannelVisibilityPublic,
    ),
    joinPolicy: _firstNonEmpty(
      channel.joinPolicy,
      grantChannel?.joinPolicy,
      asChannelJoinPolicyOpen,
    ),
    commentsEnabled: channel.commentsEnabled,
    channelType: _firstNonEmpty(
      channel.channelType,
      grantChannel?.channelType,
      asChannelTypeChat,
    ),
    tags:
        channel.tags.isNotEmpty ? channel.tags : grantChannel?.tags ?? const [],
    memberCount: channel.memberCount >= 0
        ? channel.memberCount
        : grantChannel?.memberCount ?? -1,
  );
}

String _firstNonEmpty(String? first, [String? second, String? third]) {
  for (final value in [first, second, third]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _channelInviteResultMessage({
  required int sentCount,
  required int skippedCount,
  required int failedCount,
}) {
  if (sentCount == 0 && skippedCount == 0 && failedCount == 0) {
    return '所选联系人已在频道中';
  }
  final parts = <String>['已发送 $sentCount 个频道邀请卡片'];
  if (skippedCount > 0) parts.add('$skippedCount 个联系人缺少私聊，已跳过');
  if (failedCount > 0) parts.add('$failedCount 个发送失败');
  return parts.join('，');
}

String _channelInviteFailureMessage(Object error) {
  if (error is AsClientException && error.statusCode == 403) {
    return '只有频道主可邀请成员';
  }
  return '发送频道邀请失败: $error';
}

class _InviteChannelMembersDialog extends StatefulWidget {
  const _InviteChannelMembersDialog({
    required this.contacts,
    required this.client,
  });

  final List<AsSyncContact> contacts;
  final Client client;

  @override
  State<_InviteChannelMembersDialog> createState() =>
      _InviteChannelMembersDialogState();
}

class _InviteChannelMembersDialogState
    extends State<_InviteChannelMembersDialog> {
  final Set<String> _selectedMxids = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return AlertDialog(
      title: Text(
        l10n?.channelInviteAddMembersTitle ?? 'Invite channel members',
        style: AppTheme.sans(
          size: 17,
          weight: FontWeight.w600,
          color: t.text,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.contacts.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n?.groupInviteNoContacts ?? '暂无可邀请联系人',
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = widget.contacts[index];
                    final mxid = contact.userId.trim();
                    final selected = _selectedMxids.contains(mxid);
                    final name = contactDisplayNameFromIdentity(
                      mxid: mxid,
                      displayName: contact.displayName,
                      domain: contact.domain,
                    );
                    return _InviteChannelContactRow(
                      name: name,
                      subtitle: contact.domain.trim(),
                      avatarUrl: avatarHttpUrl(
                        widget.client,
                        contact.avatarUrl,
                      ),
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedMxids.remove(mxid);
                        } else {
                          _selectedMxids.add(mxid);
                        }
                      }),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? '取消'),
        ),
        TextButton(
          onPressed: _selectedMxids.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _selectedMxids.toList(growable: false),
                  ),
          child: Text(l10n?.groupInviteSend ?? '发送邀请'),
        ),
      ],
    );
  }
}

class _InviteChannelContactRow extends StatelessWidget {
  const _InviteChannelContactRow({
    required this.name,
    required this.selected,
    required this.onTap,
    this.subtitle = '',
    this.avatarUrl,
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              PortalAvatar(
                seed: name,
                size: 32,
                imageUrl: avatarUrl,
                shape: AvatarShape.squircle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: subtitle.isEmpty ? 52 : 58,
                  padding: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.surfaceHigh,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 15,
                                weight: FontWeight.w500,
                                color: t.text,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 12,
                                  color: t.textMute,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _InviteChannelCheck(selected: selected),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteChannelCheck extends StatelessWidget {
  const _InviteChannelCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.accent : Colors.transparent,
        border: Border.all(
          color: selected ? t.accent : t.border,
          width: 1,
        ),
      ),
      child: selected ? Icon(Symbols.check, size: 12, color: t.onAccent) : null,
    );
  }
}
