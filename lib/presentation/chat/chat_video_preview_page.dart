import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

typedef VideoPreviewAction = Future<void> Function();

Future<void> openChatVideoPreview(
  BuildContext context, {
  required File file,
  String title = '视频',
  VideoPreviewAction? onSaveToAlbum,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ChatVideoPreviewPage(
        file: file,
        title: title,
        onSaveToAlbum: onSaveToAlbum,
      ),
    ),
  );
}

class ChatVideoPreviewPage extends StatefulWidget {
  const ChatVideoPreviewPage({
    super.key,
    required this.file,
    required this.title,
    this.onSaveToAlbum,
  });

  final File file;
  final String title;
  final VideoPreviewAction? onSaveToAlbum;

  @override
  State<ChatVideoPreviewPage> createState() => _ChatVideoPreviewPageState();
}

class _ChatVideoPreviewPageState extends State<ChatVideoPreviewPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _initialize = _controller.initialize().then((_) async {
      if (!mounted) return;
      setState(() {});
      await _controller.play();
    });
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  Future<void> _saveToAlbum() async {
    final action = widget.onSaveToAlbum;
    if (action == null || _saving) return;
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存原视频到相册')),
      );
    } on Object catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$err')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<void>(
                future: _initialize,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snapshot.hasError || !_controller.value.isInitialized) {
                    return _VideoPreviewError(error: snapshot.error);
                  }
                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayback,
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: _VideoPreviewHeader(
                title: widget.title,
                saving: _saving,
                saved: _saved,
                onSaveToAlbum:
                    widget.onSaveToAlbum == null ? null : _saveToAlbum,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _VideoControls(
                controller: _controller,
                onTogglePlayback: _togglePlayback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewHeader extends StatelessWidget {
  const _VideoPreviewHeader({
    required this.title,
    required this.saving,
    required this.saved,
    this.onSaveToAlbum,
  });

  final String title;
  final bool saving;
  final bool saved;
  final VoidCallback? onSaveToAlbum;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.close, color: Colors.white, size: 26),
          tooltip: '关闭',
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: onSaveToAlbum == null
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: saving ? null : onSaveToAlbum,
                  tooltip: saved ? '原视频已保存' : '保存原视频到相册',
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          saved ? Symbols.check : Symbols.download,
                          color: Colors.white,
                          size: 26,
                        ),
                ),
        ),
      ],
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.onTogglePlayback,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (!value.isInitialized) return const SizedBox.shrink();
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onTogglePlayback,
              icon: Icon(
                value.isPlaying ? Symbols.pause : Symbols.play_arrow,
                color: Colors.white,
                size: 28,
              ),
              tooltip: value.isPlaying ? '暂停' : '播放',
            ),
            Text(
              _formatVideoDuration(position),
              style: AppTheme.sans(size: 12, color: Colors.white),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: duration.inMilliseconds
                      .toDouble()
                      .clamp(1, double.maxFinite),
                  value: position.inMilliseconds
                      .toDouble()
                      .clamp(0, duration.inMilliseconds.toDouble()),
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withValues(alpha: 0.28),
                  onChanged: (value) {
                    controller.seekTo(Duration(milliseconds: value.round()));
                  },
                ),
              ),
            ),
            Text(
              _formatVideoDuration(duration),
              style: AppTheme.sans(size: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewError extends StatelessWidget {
  const _VideoPreviewError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.error, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(
              '视频无法播放',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: AppTheme.sans(size: 12, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatVideoDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
