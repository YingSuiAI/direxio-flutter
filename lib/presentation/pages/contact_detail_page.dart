import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';

class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(matrixClientProvider);
    final room = client.rooms.where((r) => r.directChatMatrixID == userId).firstOrNull;
    final displayName = room?.getLocalizedDisplayname() ?? userId;
    final domain = userId.contains(':') ? userId.split(':').last : userId;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          CircleAvatar(radius: 40, child: Text(displayName.characters.first.toUpperCase())),
          const SizedBox(height: 12),
          Text(displayName, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          Text(domain, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          if (room != null) ...[
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('发消息'),
              onTap: () => context.go('/chat/${Uri.encodeComponent(room.id)}'),
            ),
            ListTile(
              leading: const Icon(Icons.video_call_outlined),
              title: const Text('视频通话'),
              onTap: () => context.push('/call/${Uri.encodeComponent(room.id)}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('删除联系人'),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                await room.leave();
                if (context.mounted) context.pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
