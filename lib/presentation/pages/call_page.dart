/// 通话页 —— 对齐 Agent P2P 设计稿 s-call。
/// 当前为 UI 占位：控制按钮无真实通话逻辑（WebRTC / Matrix VoIP 待后端就绪后接）。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../mock/mock_data.dart';

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  Timer? _timer;
  int _elapsed = 0; // 秒
  bool _muted = false;
  bool _speaker = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedText {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _peerName() {
    final mock = MockData.byId(widget.roomId);
    if (mock != null) return mock.name;
    final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
    return room?.getLocalizedDisplayname() ?? '通话';
  }

  @override
  Widget build(BuildContext context) {
    final name = _peerName();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C2C2E), Color(0xFF1A1C1F)], // theme-fixed: 通话页固定深色背景
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.keyboard_arrow_down,
                          size: 28, color: Colors.white60),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Text('语音通话',
                        style: AppTheme.sans(
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.5))),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // 中部：头像 + 名字 + 计时 + 加密 chip
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Symbols.account_circle,
                          size: 68,
                          fill: 1,
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 20),
                    Text(name,
                        style: AppTheme.sans(
                            size: 28,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(_elapsedText,
                        style: AppTheme.sans(
                            size: 17,
                            color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF72FE88) // theme-fixed: 加密绿
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFF72FE88) // theme-fixed: 加密绿
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF72FE88), // theme-fixed: 加密绿
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('端对端加密',
                              style: AppTheme.sans(
                                  size: 13,
                                  color: const Color(
                                      0xFF72FE88))), // theme-fixed: 加密绿
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 控制区
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CallControl(
                          icon: _muted ? Symbols.mic_off : Symbols.mic,
                          label: '静音',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _CallControl(
                          icon: Symbols.dialpad,
                          label: '键盘',
                          onTap: () {},
                        ),
                        _CallControl(
                          icon: _speaker
                              ? Symbols.volume_up
                              : Symbols.volume_down,
                          label: '扬声器',
                          active: _speaker,
                          onTap: () => setState(() => _speaker = !_speaker),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _HangUpButton(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon,
                size: 26,
                fill: active ? 1 : 0,
                color: active
                    ? const Color(0xFF1A1C1F) // theme-fixed: 通话页深色
                    : Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTheme.sans(
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _HangUpButton extends StatelessWidget {
  const _HangUpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFBA1A1A), // theme-fixed: 挂断红
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBA1A1A) // theme-fixed: 挂断红
                      .withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Symbols.call_end,
                size: 32, fill: 1, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text('挂断',
              style: AppTheme.sans(
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
