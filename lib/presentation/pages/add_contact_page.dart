/// 添加联系人 —— 通过域名发现对方 Portal 身份。M3 风格。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';

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
    final domain =
        _domainCtrl.text.trim().replaceAll(RegExp(r'^https?://'), '');
    if (domain.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _resolved = null;
      _success = null;
    });
    try {
      final client = ref.read(matrixClientProvider);
      final wk = WellKnownService(httpClient: client.httpClient);
      final result = await wk.discoverOwner(domain);
      switch (result.availability) {
        case PortalAvailability.online:
          setState(() => _resolved = {
                'mxid': result.owner!.matrixUserId,
                'display_name': result.owner!.displayName.isEmpty
                    ? domain
                    : result.owner!.displayName,
              });
        case PortalAvailability.notDeployed:
          setState(() => _error = '$domain 未部署 Portal');
        case PortalAvailability.unreachable:
          setState(() => _resolved = {
                'mxid': '@owner:$domain',
                'display_name': domain,
              });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInvite() async {
    final mxid = _resolved?['mxid'] as String?;
    if (mxid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(matrixClientProvider);
      await client.startDirectChat(mxid);
      setState(() => _success = '邀请已发送，等待对方接受。');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '添加联系人'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('输入对方的域名',
                    style: AppTheme.sans(
                        size: 17,
                        weight: FontWeight.w600,
                        color: t.text)),
                const SizedBox(height: 4),
                Text('每个 Portal 对应一个域名，域名即身份',
                    style:
                        AppTheme.sans(size: 13, color: t.textMute)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: M3InputField(
                        controller: _domainCtrl,
                        icon: Symbols.link,
                        hint: 'liyananp2p.com',
                        keyboardType: TextInputType.url,
                        onSubmitted: (_) => _resolve(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    M3PrimaryButton(
                      label: '查找',
                      expand: false,
                      onPressed: _loading ? null : _resolve,
                    ),
                  ],
                ),
                if (_resolved != null) ...[
                  const SizedBox(height: 20),
                  M3Card(
                    child: Row(
                      children: [
                        PortalAvatar(
                            seed: _resolved!['display_name'] as String,
                            size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _resolved!['display_name'] as String,
                                  style: AppTheme.sans(
                                      size: 17,
                                      weight: FontWeight.w600,
                                      color: t.text)),
                              const SizedBox(height: 2),
                              Text(_resolved!['mxid'] as String,
                                  style: AppTheme.sans(
                                      size: 13,
                                      color: t.textMute)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  M3PrimaryButton(
                    label: '发送好友申请',
                    onPressed: _loading ? null : _sendInvite,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    icon: Symbols.error,
                    color: t.danger,
                    message: _error!,
                  ),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    icon: Symbols.check_circle,
                    color: t.accent,
                    message: _success!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTheme.sans(size: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
