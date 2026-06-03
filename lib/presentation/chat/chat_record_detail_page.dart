import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_media_cache_provider.dart';
import '../utils/chat_file_actions.dart';
import '../widgets/async_image_preview.dart';
import 'chat_glass_background.dart';
import 'chat_message_cards.dart';
import 'chat_record_forwarding.dart';

const _chatRecordFileActionsChannel = MethodChannel('p2p_im/file_actions');

final chatRecordNativePreviewerProvider = Provider<ChatRecordNativePreviewer>(
  (ref) => ChatRecordNativePreviewer(),
);

class ChatRecordNativePreviewer {
  final Map<String, Future<File>> _files = {};

  Future<void> open(WidgetRef ref, ChatRecordItem item) async {
    final file = await _materializedFile(ref, item);
    await _chatRecordFileActionsChannel.invokeMethod<void>(
      'previewFile',
      {'path': file.path},
    );
  }

  Future<File> _materializedFile(WidgetRef ref, ChatRecordItem item) async {
    final key = '${item.mediaUrl}|${_chatRecordFileName(item)}';
    final cached = _files[key];
    if (cached != null) {
      final file = await cached;
      if (await file.exists()) return file;
      _files.remove(key);
    }

    final uri = _mxcUri(item.mediaUrl);
    if (uri == null) throw StateError('媒体地址无效');
    final future = _downloadMxcBytes(ref, uri).then(
      (bytes) => writeChatActionFile(
        directory: Directory('${Directory.systemTemp.path}/p2p-im-open'),
        fileName: _chatRecordFileName(item),
        bytes: bytes,
      ),
    );
    _files[key] = future;
    future.then<void>(
      (_) {},
      onError: (_, __) {
        _files.remove(key);
      },
    );
    return future;
  }
}

class ChatRecordDetailPage extends ConsumerWidget {
  const ChatRecordDetailPage({
    super.key,
    required this.payload,
    this.pageTitle = '聊天记录',
  });

  final ChatRecordPayload payload;
  final String pageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final items = chatRecordItems(payload);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: t.text,
        centerTitle: true,
        title: Text(
          pageTitle,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.text,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                bottom: BorderSide(color: t.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payload.title,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${payload.itemCount} 条消息',
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
              ],
            ),
          ),
          Expanded(
            child: ChatGlassBackground(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '这条聊天记录没有可展示的明细',
                        style: AppTheme.sans(size: 14, color: t.textMute),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ChatRecordMessageRow(
                        item: items[index],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRecordMessageRow extends ConsumerWidget {
  const _ChatRecordMessageRow({required this.item});

  final ChatRecordItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final isMe = item.isMe;
    final avatarSeed = item.senderName.trim().isNotEmpty
        ? item.senderName.trim()
        : item.senderId.trim();
    final bubble = _ChatRecordBubble(item: item);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _ChatRecordAvatar(seed: avatarSeed),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  bubble,
                  const SizedBox(height: 4),
                  Text(
                    _timeLabel(item.originServerTs),
                    style: AppTheme.sans(size: 11, color: t.textMute),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRecordBubble extends StatelessWidget {
  const _ChatRecordBubble({required this.item});

  final ChatRecordItem item;

  @override
  Widget build(BuildContext context) {
    final nested = chatRecordPayloadFromContent(item.content);
    if (nested != null) {
      return _ChatRecordNestedBubble(item: item, payload: nested);
    }
    final type = item.messageType;
    if (type == MessageTypes.Image) {
      return _ChatRecordMediaBubble(item: item, icon: Symbols.image);
    }
    if (type == MessageTypes.Video) {
      return _ChatRecordMediaBubble(
        item: item,
        icon: Symbols.movie,
        overlay: const _ChatRecordPlayOverlay(),
      );
    }
    if (type == MessageTypes.File || type == MessageTypes.Audio) {
      return _ChatRecordFileBubble(item: item);
    }
    return _ChatRecordTextBubble(item: item);
  }
}

class _ChatRecordNestedBubble extends StatelessWidget {
  const _ChatRecordNestedBubble({
    required this.item,
    required this.payload,
  });

  final ChatRecordItem item;
  final ChatRecordPayload payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isMe = item.isMe;
    final textColor = isMe ? t.onAccent : t.text;
    final mutedColor = isMe ? t.onAccent.withValues(alpha: 0.72) : t.textMute;
    final iconColor = isMe ? t.onAccent : t.accent;
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    return ChatBubbleFrame(
      child: Material(
        color: bubbleColor,
        borderRadius: _bubbleRadius(isMe),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatRecordDetailPage(payload: payload),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isMe ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Symbols.forum, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '共 ${payload.itemCount} 条消息',
                        style: AppTheme.sans(size: 12, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Symbols.chevron_right, color: mutedColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatRecordTextBubble extends StatelessWidget {
  const _ChatRecordTextBubble({required this.item});

  final ChatRecordItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isMe = item.isMe;
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    return ChatBubbleFrame(
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: _bubbleRadius(isMe),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          item.body,
          style: AppTheme.sans(
            size: 17,
            color: isMe ? t.onAccent : t.text,
          ),
        ),
      ),
    );
  }
}

class _ChatRecordMediaBubble extends ConsumerWidget {
  const _ChatRecordMediaBubble({
    required this.item,
    required this.icon,
    this.overlay,
  });

  final ChatRecordItem item;
  final IconData icon;
  final Widget? overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatMediaBubbleFrame(
      width: 208,
      height: 160,
      child: Material(
        color: Colors.transparent,
        borderRadius: _bubbleRadius(item.isMe),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_openChatRecordMedia(context, ref, item)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ChatRecordMediaImage(item: item, fallbackIcon: icon),
              if (overlay != null) Center(child: overlay!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatRecordMediaImage extends ConsumerWidget {
  const _ChatRecordMediaImage({
    required this.item,
    required this.fallbackIcon,
  });

  final ChatRecordItem item;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final raw = item.thumbnailUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(t),
      );
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isScheme('mxc')) return _fallback(t);
    return FutureBuilder<Uint8List>(
      future: _downloadMxcBytes(ref, uri),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        if (snapshot.hasError) return _fallback(t);
        return Container(
          color: t.surfaceHigh,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
        );
      },
    );
  }

  Widget _fallback(PortalTokens t) {
    return Container(
      color: t.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: t.textMute, size: 32),
    );
  }
}

class _ChatRecordFileBubble extends ConsumerWidget {
  const _ChatRecordFileBubble({required this.item});

  final ChatRecordItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    return ChatBubbleFrame(
      child: Material(
        color: t.surface,
        borderRadius: _bubbleRadius(item.isMe),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_openChatRecordMedia(context, ref, item)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              borderRadius: _bubbleRadius(item.isMe),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: t.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(Symbols.description, size: 22, color: t.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 13,
                          color: t.text,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fileMeta(item),
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openChatRecordMedia(
  BuildContext context,
  WidgetRef ref,
  ChatRecordItem item,
) async {
  try {
    if (item.messageType == MessageTypes.Image) {
      await _openChatRecordImage(context, ref, item);
      return;
    }
    await ref.read(chatRecordNativePreviewerProvider).open(ref, item);
  } on Object catch (err) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开失败：$err')),
    );
  }
}

Future<void> _openChatRecordImage(
  BuildContext context,
  WidgetRef ref,
  ChatRecordItem item,
) {
  final fullLoader = _imageProviderLoader(ref, item.mediaUrl) ??
      _imageProviderLoader(ref, item.thumbnailUrl);
  if (fullLoader == null) throw StateError('图片地址无效');
  final previewLoader = _imageProviderLoader(ref, item.thumbnailUrl);
  return showAsyncImagePreview(
    context,
    loadPreviewProvider: previewLoader,
    loadProvider: fullLoader,
    meta: _chatRecordMediaMeta(item),
  );
}

ImageProviderLoader? _imageProviderLoader(WidgetRef ref, String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return () async => NetworkImage(value);
  }
  final uri = _mxcUri(value);
  if (uri == null) return null;
  return () async => MemoryImage(await _downloadMxcBytes(ref, uri));
}

Uri? _mxcUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.isScheme('mxc')) return null;
  return uri;
}

String _chatRecordFileName(ChatRecordItem item) {
  final filename = item.filename.trim();
  if (filename.isNotEmpty) return filename;
  final body = item.body.trim();
  return body.isEmpty ? 'file' : body;
}

String _chatRecordMediaMeta(ChatRecordItem item) {
  final sender = item.senderName.trim().isEmpty ? '聊天记录' : item.senderName;
  final time = _timeLabel(item.originServerTs);
  return time.isEmpty ? sender : '$sender · $time';
}

class _ChatRecordAvatar extends StatelessWidget {
  const _ChatRecordAvatar({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final letter = seed.trim().isNotEmpty
        ? seed.trim().characters.first.toUpperCase()
        : '?';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: t.accentCool.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTheme.sans(
          size: 14,
          color: t.text,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatRecordPlayOverlay extends StatelessWidget {
  const _ChatRecordPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        shape: BoxShape.circle,
      ),
      child: const Icon(Symbols.play_arrow, color: Colors.white, size: 30),
    );
  }
}

BorderRadius _bubbleRadius(bool _) => chatMessageBubbleRadius;

String _timeLabel(int originServerTs) {
  if (originServerTs <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(originServerTs).toLocal();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _fileMeta(ChatRecordItem item) {
  final parts = <String>[];
  if (item.mimeType.isNotEmpty) parts.add(item.mimeType);
  if (item.size > 0) parts.add(_formatBytes(item.size));
  return parts.isEmpty ? '文件' : parts.join(' · ');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

Future<Uint8List> _downloadMxcBytes(WidgetRef ref, Uri mxc) async {
  final client = ref.read(matrixClientProvider);
  return ref.read(matrixMediaBytesCacheProvider).read(client, mxc);
}
