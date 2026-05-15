import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(roomId);
    if (room == null) return const Scaffold(body: Center(child: Text('群组不存在')));

    final members = room.getParticipants();
    final topic = room.topic;

    return Scaffold(
      appBar: AppBar(title: Text(room.getLocalizedDisplayname())),
      body: ListView(
        children: [
          if (topic != null && topic.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('群公告', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(topic),
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('成员 (${members.length})',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ...members.map((m) => ListTile(
                leading: CircleAvatar(
                  child: Text(m.displayName?.characters.first.toUpperCase() ?? '?'),
                ),
                title: Text(m.displayName ?? m.id),
                subtitle: Text(m.id.contains(':') ? m.id.split(':').last : m.id),
              )),
          const Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app,
                color: Theme.of(context).colorScheme.error),
            title: Text('退出群组',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              await room.leave();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
