import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/auth_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';

class MeQrPage extends ConsumerWidget {
  const MeQrPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final personalProfile = ref.watch(personalProfileProvider);
    final userId = client.userID ?? '@me:portal.agent-p2p.io';
    final localpart = _localpartFromMxid(userId);
    final profileName = profile?.displayName?.trim();
    final draftName = personalProfile.displayName?.trim();
    final displayName = draftName?.isNotEmpty == true
        ? draftName!
        : profileName?.isNotEmpty == true
            ? profileName!
            : localpart;
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? MockAvatars.me;
    final domain = _domainFromMxid(userId);
    final payload = Uri(
      scheme: 'p2pim',
      host: 'add-contact',
      queryParameters: {'mxid': userId, 'domain': domain},
    ).toString();
    final uid = localpart.isEmpty ? userId : localpart;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _QrHeader(topInset: topInset),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                child: _QrCard(
                  displayName: displayName,
                  uid: uid,
                  userId: userId,
                  avatarUrl: avatarUrl,
                  payload: payload,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: topInset + 62,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _QrGlassButton(
                icon: Symbols.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Text(
              '我的二维码',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrGlassButton extends StatelessWidget {
  const _QrGlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 24, color: t.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.displayName,
    required this.uid,
    required this.userId,
    required this.avatarUrl,
    required this.payload,
  });

  final String displayName;
  final String uid;
  final String userId;
  final String avatarUrl;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PortalAvatar(
                  seed: userId,
                  size: 60,
                  imageUrl: avatarUrl,
                  shape: AvatarShape.squircle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UID $uid',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 14, color: t.textMute),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '分享',
                  onPressed: () => Share.share(payload),
                  icon: Icon(Symbols.ios_share, size: 24, color: t.text),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 150,
                backgroundColor: t.surface,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '扫一扫上面的二维码图案，加我为好友。',
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存到相册功能待接入')),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '保存到相册',
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: t.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localpartFromMxid(String mxid) {
  final trimmed = mxid.trim();
  if (trimmed.startsWith('@')) {
    final end = trimmed.indexOf(':');
    if (end > 1) return trimmed.substring(1, end);
    return trimmed.substring(1);
  }
  return trimmed;
}

String _domainFromMxid(String mxid) {
  final colon = mxid.indexOf(':');
  if (colon == -1 || colon == mxid.length - 1) return '未连接域名';
  return mxid.substring(colon + 1);
}
