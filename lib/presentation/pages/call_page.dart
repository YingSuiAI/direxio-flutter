import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

// TODO Day 4: wire up matrix_dart_sdk CallSession
// client.voip.inviteToCall(roomId, CallType.kVideo) / callSession.answer() / hangup()
class CallPage extends ConsumerWidget {
  const CallPage({super.key, required this.roomId, this.isVideo = false});
  final String roomId;
  final bool isVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.read(matrixClientProvider).getRoomById(roomId);
    final displayName = room?.getLocalizedDisplayname() ?? 'Alice Chen';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // 160deg gradient (顶左 → 底右), 用近似 begin/end
            colors: [Color(0xFF2C2C2E), Color(0xFF1A1C1F)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Row(
                  children: [
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                    Expanded(
                      child: Center(
                        child: Text(
                          isVideo ? '视频通话' : '语音通话',
                          style: AppTheme.sans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // ── Center: video preview (video) / avatar (voice) ─────
              Expanded(
                child: isVideo
                    ? Stack(
                        children: [
                          Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Symbols.videocam_off,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Container(
                              width: 100,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Icon(
                                Symbols.person,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
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
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Symbols.account_circle,
                        size: 68,
                        color: Colors.white.withValues(alpha: 0.5),
                        fill: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      displayName,
                      style: AppTheme.sans(
                        size: 28,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '00:42',
                      style: AppTheme.sans(
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF72FE88).withValues(alpha: 0.20),
                        border: Border.all(
                          color: const Color(
                            0xFF72FE88,
                          ).withValues(alpha: 0.30),
                        ),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF72FE88),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '端对端加密',
                            style: AppTheme.sans(
                              size: 13,
                              weight: FontWeight.w500,
                              color: const Color(0xFF72FE88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Controls ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _ControlButton(icon: Symbols.mic_off, label: '静音'),
                        _ControlButton(icon: Symbols.dialpad, label: '键盘'),
                        _ControlButton(icon: Symbols.volume_up, label: '扬声器'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _HangupButton(onTap: () => Navigator.of(context).pop()),
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

// 顶部关闭按钮（向下箭头）
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Symbols.keyboard_arrow_down,
          size: 28,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// 圆形操作按钮（静音 / 键盘 / 扬声器）
class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.sans(
            size: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// 挂断按钮（pulse 脉冲动画）
class _HangupButton extends StatefulWidget {
  const _HangupButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HangupButton> createState() => _HangupButtonState();
}

class _HangupButtonState extends State<_HangupButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulse = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              // pulse: 从 0 → 18px spreadRadius, opacity 0.6 → 0
              final t = _pulse.value;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFBA1A1A),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFBA1A1A,
                      ).withValues(alpha: 0.6 * (1.0 - t)),
                      blurRadius: 0,
                      spreadRadius: 18 * t,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: const Icon(
              Symbols.call_end,
              size: 32,
              color: Colors.white,
              fill: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '挂断',
            style: AppTheme.sans(
              size: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
