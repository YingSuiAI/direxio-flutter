import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/home_hidden_conversations_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/center_toast.dart';
import '../widgets/portal_avatar.dart';

class AddContactDetailPage extends ConsumerStatefulWidget {
  const AddContactDetailPage({
    super.key,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  @override
  ConsumerState<AddContactDetailPage> createState() =>
      _AddContactDetailPageState();
}

class _AddContactDetailPageState extends ConsumerState<AddContactDetailPage> {
  void _openVerification() {
    final query = Uri(
      queryParameters: {
        if (widget.displayName?.trim().isNotEmpty == true)
          'name': widget.displayName!.trim(),
        if (widget.avatarUrl?.trim().isNotEmpty == true)
          'avatar': widget.avatarUrl!.trim(),
      },
    ).query;
    context.push(
      '/add-contact/verify/${Uri.encodeComponent(widget.userId)}'
      '${query.isEmpty ? '' : '?$query'}',
    );
  }

  void _openAcceptedChat(AsConversation conversation) {
    final roomId = conversation.roomId.trim();
    final route = productConversationRoute(conversation);
    if (roomId.isEmpty || route == null) {
      _toast(context, '打开聊天失败: 缺少会话信息');
      return;
    }
    showHomeConversation(ref, roomId);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final acceptedContact =
        ref.watch(asSyncCacheProvider).acceptedContactForUserId(widget.userId);
    final productConversations =
        ref.watch(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final acceptedConversation = acceptedContact == null
        ? null
        : productDirectConversationForPeer(
            productConversations,
            peerMxid: widget.userId,
            roomId: acceptedContact.roomId,
          );
    final isAcceptedContact = acceptedContact != null;
    final client = ref.watch(matrixClientProvider);
    final profile = _profileForAddContact(
      widget.userId,
      _firstNonEmpty(acceptedContact?.displayName, widget.displayName),
      avatarUrl: _firstNonEmpty(
        avatarHttpUrl(client, acceptedContact?.avatarUrl),
        avatarHttpUrl(client, widget.avatarUrl),
      ),
    );
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _DetailGlassBackButton(onTap: () => context.pop()),
              ),
              const SizedBox(height: 24),
              _ProfileHeader(profile: profile),
              const SizedBox(height: 24),
              _DetailNavigationRow(
                label: '他的频道',
                onTap: () => context.push(
                  '/contact-channels/${Uri.encodeComponent(widget.userId)}',
                ),
              ),
              const SizedBox(height: 14),
              _AddFriendRow(
                label: isAcceptedContact ? '发消息' : '添加好友',
                onTap: isAcceptedContact
                    ? acceptedConversation == null
                        ? () => _toast(context, '聊天会话同步中，请稍后重试')
                        : () => _openAcceptedChat(acceptedConversation)
                    : _openVerification,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddContactProfile {
  const _AddContactProfile({
    required this.name,
    required this.uid,
    this.avatarUrl,
  });

  final String name;
  final String uid;
  final String? avatarUrl;
}

_AddContactProfile _profileForAddContact(
  String userId,
  String? displayName, {
  String? avatarUrl,
}) {
  final domain = domainFromMxid(userId);
  final name = contactDisplayNameFromIdentity(
    mxid: userId,
    displayName: displayName ?? '',
    domain: domain,
    fallback: displayName ?? userId,
  );
  return _AddContactProfile(
    name: name,
    uid: userId.trim(),
    avatarUrl: avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null,
  );
}

String _firstNonEmpty(String? first, String? second) {
  final firstValue = first?.trim() ?? '';
  if (firstValue.isNotEmpty) return firstValue;
  return second?.trim() ?? '';
}

class _DetailGlassBackButton extends StatelessWidget {
  const _DetailGlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: t.surface.withValues(alpha: 0.65),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Symbols.arrow_back, size: 24, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final _AddContactProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        PortalAvatar(
          seed: _avatarFallbackSeed(profile.name, profile.uid),
          imageUrl: profile.avatarUrl,
          size: 60,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _copyAddContactUid(context, profile.uid),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        profile.uid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Symbols.content_copy,
                      size: 14,
                      color: t.textMute,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _copyAddContactUid(BuildContext context, String uid) async {
  await Clipboard.setData(ClipboardData(text: uid));
  if (!context.mounted) return;
  _toast(context, '已复制 UID');
}

String _avatarFallbackSeed(String displayName, String fallback) {
  final name = displayName.trim();
  if (name.isNotEmpty) return name;
  return fallback;
}

class _DetailNavigationRow extends StatelessWidget {
  const _DetailNavigationRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: t.text,
                  ).copyWith(letterSpacing: -0.4),
                ),
                const Spacer(),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: t.text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFriendRow extends StatelessWidget {
  const _AddFriendRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w500,
                color: t.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  showCenterToast(context, message);
}
