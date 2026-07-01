import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/save_image_to_gallery.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/center_toast.dart';

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
    final avatarUrl = profileAvatarHttpUrl(profile, client);
    final l10n = AppLocalizations.of(context);
    final domain = _domainFromMxid(userId, l10n);
    final payload = buildMeQrPayload(
      userId: userId,
      domain: domain,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    final uid = _meUidUrl(client, userId);
    final topInset = MediaQuery.of(context).padding.top;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? t.bg : t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _QrHeader(
              topInset: topInset,
              title: AppLocalizations.of(context).meQrTitle,
            ),
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

class GroupQrPage extends ConsumerWidget {
  const GroupQrPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final room = client.getRoomById(roomId);
    final syncCache = ref.watch(asSyncCacheProvider);
    final displayName = _groupQrDisplayName(
      roomId: roomId,
      room: room,
      syncCache: syncCache,
    );
    final avatarUrl = _groupQrAvatarUrl(
      client: client,
      roomId: roomId,
      room: room,
      syncCache: syncCache,
    );
    final payload = buildGroupQrPayload(
      roomId: roomId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    debugPrint(
      'group-qr payload=${_rawQrPayloadPreview(payload)} '
      'roomId=$roomId hasName=${displayName.trim().isNotEmpty} '
      'hasAvatar=${avatarUrl?.trim().isNotEmpty == true}',
    );
    final topInset = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? t.bg : t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _QrHeader(
              topInset: topInset,
              title: AppLocalizations.of(context).groupQrTitle,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                child: _GroupQrCard(
                  displayName: displayName,
                  roomId: roomId,
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

@visibleForTesting
String buildMeQrPayload({
  required String userId,
  required String domain,
  required String displayName,
  String? avatarUrl,
}) {
  return Uri(
    scheme: 'p2pim',
    host: 'add-contact',
    queryParameters: {
      'mxid': userId,
      'domain': domain,
      'name': displayName,
      if (avatarUrl?.trim().isNotEmpty == true) 'avatar_url': avatarUrl!.trim(),
    },
  ).toString();
}

@visibleForTesting
String buildGroupQrPayload({
  required String roomId,
  String? displayName,
  String? avatarUrl,
}) {
  return Uri(
    scheme: 'p2pim',
    host: 'group',
    queryParameters: {
      'room_id': roomId,
      if (displayName?.trim().isNotEmpty == true) 'name': displayName!.trim(),
      if (avatarUrl?.trim().isNotEmpty == true) 'avatar_url': avatarUrl!.trim(),
    },
  ).toString();
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({
    required this.topInset,
    required this.title,
  });

  final double topInset;
  final String title;

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
              title,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: isDark ? 0.18 : 0.12),
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

class _GroupQrCard extends StatelessWidget {
  const _GroupQrCard({
    required this.displayName,
    required this.roomId,
    required this.payload,
  });

  final String displayName;
  final String roomId;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: t.surface,
      shadowColor: t.text.withValues(alpha: isDark ? 0.28 : 0.08),
      elevation: isDark ? 2 : 0,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              AppLocalizations.of(context).groupQrId(roomId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
            const SizedBox(height: 24),
            _QrCodeWithLogo(
              payload: payload,
              boxKey: const ValueKey('group_qr_display_qr_box'),
              qrKey: const ValueKey('group_qr_display_qr_image'),
              showContainerChrome: true,
              qrSize: 172,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              showLogo: false,
              semanticsLabel: payload,
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).groupQrHint,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 14, color: t.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatefulWidget {
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
  final String? avatarUrl;
  final String payload;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  bool _saving = false;
  bool _sharing = false;
  final _shareExportKey = GlobalKey();

  Future<Uint8List> _renderShareCardPng() async {
    final pixelRatio = View.of(context).devicePixelRatio;
    var boundary = _shareExportKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      boundary = _shareExportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
    }
    if (boundary == null) {
      throw const SaveImageToGalleryException('Failed to find QR share card.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final bytes = data?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw const SaveImageToGalleryException(
          'Failed to render QR share card.');
    }
    return bytes;
  }

  Future<void> _shareCard() async {
    if (_sharing) return;
    _sharing = true;
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await _renderShareCardPng();
      if (mounted) setState(() {});
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'p2p_im_qr_${_safeFileName(widget.uid)}.png',
        ),
      ]);
    } catch (err) {
      if (kDebugMode) debugPrint('share QR card failed: $err');
      if (!mounted) return;
      showTopSnackBar(
        context,
        SnackBar(content: Text(l10n.meQrSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveToAlbum() async {
    if (_saving) return;
    _saving = true;
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await _renderShareCardPng();
      if (mounted) setState(() {});
      await savePngImageToGallery(
        bytes: bytes,
        fileName: 'p2p_im_qr_${_safeFileName(widget.uid)}.png',
      );
      if (!mounted) return;
      showTopSnackBar(
        context,
        SnackBar(content: Text(l10n.meQrSaveSuccess)),
      );
    } catch (err) {
      if (kDebugMode) debugPrint('save QR card failed: $err');
      if (!mounted) return;
      showTopSnackBar(
        context,
        SnackBar(content: Text(l10n.meQrSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: RepaintBoundary(
            key: _shareExportKey,
            child: _QrShareExportCard(
              displayName: widget.displayName,
              uid: widget.uid,
              userId: widget.userId,
              avatarUrl: widget.avatarUrl,
              payload: widget.payload,
            ),
          ),
        ),
        Material(
          color: t.surface,
          shadowColor: t.text.withValues(alpha: isDark ? 0.28 : 0.08),
          elevation: isDark ? 2 : 0,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PortalAvatar(
                      seed: widget.userId,
                      size: 60,
                      imageUrl: widget.avatarUrl,
                      shape: AvatarShape.squircle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName,
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
                            'UID ${widget.uid}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(size: 14, color: t.textMute),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('me_qr_share_action'),
                      tooltip: AppLocalizations.of(context).commonShare,
                      onPressed: _sharing ? null : _shareCard,
                      icon: Icon(Symbols.ios_share, size: 24, color: t.text),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _QrCodeWithLogo(
                  payload: widget.payload,
                  boxKey: const ValueKey('me_qr_display_qr_box'),
                  qrKey: const ValueKey('me_qr_display_qr_image'),
                  showContainerChrome: true,
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).meQrHint,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const ValueKey('me_qr_save_action'),
                    onPressed: _saving ? null : _saveToAlbum,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _saving
                          ? AppLocalizations.of(context).meQrSaving
                          : AppLocalizations.of(context).meQrSaveToAlbum,
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
        ),
      ],
    );
  }
}

class _QrShareExportCard extends StatelessWidget {
  const _QrShareExportCard({
    required this.displayName,
    required this.uid,
    required this.userId,
    required this.avatarUrl,
    required this.payload,
  });

  final String displayName;
  final String uid;
  final String userId;
  final String? avatarUrl;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      key: const ValueKey('me_qr_share_export_card'),
      color: Colors.transparent,
      child: SizedBox(
        width: 343,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  ],
                ),
                const SizedBox(height: 24),
                _QrCodeWithLogo(
                  payload: payload,
                  boxKey: const ValueKey('me_qr_export_qr_box'),
                  qrKey: const ValueKey('me_qr_export_qr_image'),
                  showContainerChrome: false,
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).meQrHint,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrCodeWithLogo extends StatelessWidget {
  const _QrCodeWithLogo({
    required this.payload,
    required this.boxKey,
    required this.qrKey,
    required this.showContainerChrome,
    this.qrSize = 126,
    this.errorCorrectionLevel = QrErrorCorrectLevel.L,
    this.showLogo = true,
    this.semanticsLabel = 'qr code',
  });

  final String payload;
  final Key boxKey;
  final Key qrKey;
  final bool showContainerChrome;
  final double qrSize;
  final int errorCorrectionLevel;
  final bool showLogo;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxColor = showContainerChrome && isDark
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.white;
    final box = SizedBox(
      key: boxKey,
      width: 196,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            key: qrKey,
            data: payload,
            semanticsLabel: semanticsLabel,
            version: QrVersions.auto,
            errorCorrectionLevel: errorCorrectionLevel,
            size: qrSize,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
          if (showLogo)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Image(
                    image: AssetImage('assets/images/logo.png'),
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: showContainerChrome
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: box,
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

String _meUidUrl(Client client, String displayId) {
  final domain = _serverNameFromMxid(displayId) ?? _clientServerName(client);
  final normalized = domain.trim().replaceFirst(RegExp(r'^https?://'), '');
  if (normalized.isEmpty) return displayId;
  return 'https://$normalized';
}

String? _serverNameFromMxid(String mxid) {
  final index = mxid.indexOf(':');
  if (index < 0 || index == mxid.length - 1) return null;
  return mxid.substring(index + 1);
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final fromMxid = _serverNameFromMxid(userId);
  if (fromMxid != null && fromMxid.isNotEmpty) return fromMxid;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

String _domainFromMxid(String mxid, AppLocalizations l10n) {
  final colon = mxid.indexOf(':');
  if (colon == -1 || colon == mxid.length - 1) {
    return l10n.meQrUnconnectedDomain;
  }
  return mxid.substring(colon + 1);
}

String _safeFileName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return sanitized.isEmpty ? 'me' : sanitized;
}

String _rawQrPayloadPreview(String payload) {
  if (payload.length <= 160) return payload;
  return '${payload.substring(0, 160)}...';
}

String _groupQrDisplayName({
  required String roomId,
  required Room? room,
  required AsSyncCacheState syncCache,
}) {
  final productName = _productGroupNameForQr(syncCache, roomId);
  if (productName.isNotEmpty) return productName;
  final roomName = safeRoomDisplayName(room).trim();
  if (roomName.isNotEmpty && roomName != roomId.trim()) return roomName;
  return roomId;
}

String _productGroupNameForQr(AsSyncCacheState syncCache, String roomId) {
  final target = roomId.trim();
  if (target.isEmpty) return '';
  for (final group
      in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
    if (group.roomId.trim() == target) return group.name.trim();
  }
  return '';
}

String? _groupQrAvatarUrl({
  required Client client,
  required String roomId,
  required Room? room,
  required AsSyncCacheState syncCache,
}) {
  final productAvatar = _productGroupAvatarForQr(syncCache, roomId);
  final productAvatarUrl = avatarHttpUrl(client, productAvatar);
  if (productAvatarUrl != null) return productAvatarUrl;
  if (room != null) return roomAvatarHttpUrl(room);
  return null;
}

String _productGroupAvatarForQr(AsSyncCacheState syncCache, String roomId) {
  final target = roomId.trim();
  if (target.isEmpty) return '';
  for (final group
      in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
    if (group.roomId.trim() == target) return group.avatarUrl.trim();
  }
  return '';
}
