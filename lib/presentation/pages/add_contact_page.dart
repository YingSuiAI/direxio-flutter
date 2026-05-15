import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';

class AddContactPage extends ConsumerStatefulWidget {
  const AddContactPage({super.key});

  @override
  ConsumerState<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends ConsumerState<AddContactPage> {
  final _domainCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;
  Map<String, dynamic>? _resolved;

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final domain = _domainCtrl.text.trim().replaceAll(RegExp(r'^https?://'), '');
    if (domain.isEmpty) return;
    setState(() { _loading = true; _error = null; _resolved = null; });
    try {
      // Try .well-known/portal/owner.json first
      final client = ref.read(matrixClientProvider);
      final resp = await client.httpClient.get(
        Uri.parse('https://$domain/.well-known/portal/owner.json'),
      );
      if (resp.statusCode == 200) {
        // Parse as JSON — simple string parsing for demo
        final mxid = RegExp(r'"matrix_user_id"\s*:\s*"([^"]+)"')
            .firstMatch(resp.body)
            ?.group(1);
        final displayName = RegExp(r'"display_name"\s*:\s*"([^"]+)"')
            .firstMatch(resp.body)
            ?.group(1);
        setState(() => _resolved = {'mxid': mxid ?? '@owner:$domain', 'display_name': displayName ?? domain});
      } else {
        setState(() => _resolved = {'mxid': '@owner:$domain', 'display_name': domain});
      }
    } catch (e) {
      setState(() => _resolved = {'mxid': '@owner:$domain', 'display_name': domain});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInvite() async {
    final mxid = _resolved?['mxid'] as String?;
    if (mxid == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(matrixClientProvider);
      await client.startDirectChat(mxid);
      setState(() => _success = '邀请已发送！等待对方接受。');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('添加联系人')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('输入对方的域名', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('每个 Portal 对应一个域名，域名即身份',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _domainCtrl,
                    decoration: const InputDecoration(
                      hintText: 'liyananp2p.com',
                      prefixIcon: Icon(Icons.language),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: (_) => _resolve(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _resolve,
                  child: const Text('查找'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_resolved != null) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text((_resolved!['display_name'] as String).characters.first.toUpperCase()),
                  ),
                  title: Text(_resolved!['display_name'] as String),
                  subtitle: Text(_resolved!['mxid'] as String),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _sendInvite,
                child: const Text('发送好友申请'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Text(_success!, style: TextStyle(color: cs.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
