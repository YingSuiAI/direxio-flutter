import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';

// TODO Day 4: wire up matrix_dart_sdk CallSession
// client.voip.inviteToCall(roomId, CallType.kVideo) / callSession.answer() / hangup()
class CallPage extends ConsumerWidget {
  const CallPage({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.read(matrixClientProvider).getRoomById(roomId);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(room?.getLocalizedDisplayname() ?? '通话中'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
            SizedBox(height: 24),
            Text('连接中...', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallButton(icon: Icons.mic_off, label: '静音', onTap: () {}),
              _CallButton(icon: Icons.videocam_off, label: '关闭视频', onTap: () {}),
              _CallButton(
                icon: Icons.call_end,
                label: '挂断',
                color: Colors.red,
                onTap: () => Navigator.of(context).pop(),
              ),
              _CallButton(icon: Icons.flip_camera_ios_outlined, label: '切换摄像头', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color ?? Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
