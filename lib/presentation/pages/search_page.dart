import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  List<Room> _results = [];

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final client = ref.read(matrixClientProvider);
    setState(() {
      _results = client.rooms
          .where((r) => r.getLocalizedDisplayname()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索联系人、群组、消息...',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final room = _results[i];
          return ListTile(
            leading: CircleAvatar(
              child: Text(room.getLocalizedDisplayname().characters.first.toUpperCase()),
            ),
            title: Text(room.getLocalizedDisplayname()),
            subtitle: Text(room.isDirectChat ? '联系人' : '群组'),
            onTap: () => room.isDirectChat
                ? context.push('/chat/${Uri.encodeComponent(room.id)}')
                : context.push('/group/${Uri.encodeComponent(room.id)}'),
          );
        },
      ),
    );
  }
}
