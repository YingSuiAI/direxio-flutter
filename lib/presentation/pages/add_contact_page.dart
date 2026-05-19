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

/// 添加朋友 —— 对齐设计稿 s-new-friends 顶部「搜索 + 添加」流程。
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
  String? _resolvedDomain;

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final domain = _domainCtrl.text.trim().replaceAll(
      RegExp(r'^https?://'),
      '',
    );
    if (domain.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _resolved = null;
      _resolvedDomain = null;
    });
    try {
      // §2.2 域名发现：调 .well-known/portal/owner.json
      final client = ref.read(matrixClientProvider);
      final wk = WellKnownService(httpClient: client.httpClient);
      final result = await wk.discoverOwner(domain);
      switch (result.availability) {
        case PortalAvailability.online:
          setState(() {
            _resolvedDomain = domain;
            _resolved = {
              'mxid': result.owner!.matrixUserId,
              'display_name': result.owner!.displayName.isEmpty
                  ? domain
                  : result.owner!.displayName,
            };
          });
        case PortalAvailability.notDeployed:
          setState(() => _error = '$domain 未部署 Portal');
        case PortalAvailability.unreachable:
          // well-known 没配但域名可能仍是有效 Portal —— 回退到约定 MXID
          setState(() {
            _resolvedDomain = domain;
            _resolved = {'mxid': '@owner:$domain', 'display_name': domain};
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
      setState(() => _success = '邀请已发送！等待对方接受。');
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
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '添加朋友'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 搜索框
                      M3InputField(
                        controller: _domainCtrl,
                        icon: Symbols.search,
                        hint: '手机号 / 用户名 / Node ID',
                        keyboardType: TextInputType.url,
                        onSubmitted: (_) => _resolve(),
                        trailing: TextButton(
                          onPressed: _loading ? null : _resolve,
                          style: TextButton.styleFrom(
                            foregroundColor: t.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '搜索',
                            style: AppTheme.sans(
                              size: 13,
                              weight: FontWeight.w500,
                              color: t.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 搜索结果区
                      if (_loading && _resolved == null)
                        _LoadingPlaceholder()
                      else if (_resolved != null)
                        _ResultCard(
                          displayName: _resolved!['display_name'] as String,
                          mxid: _resolved!['mxid'] as String,
                          portalUrl: _resolvedDomain ?? '',
                          loading: _loading,
                          onAdd: _loading ? null : _sendInvite,
                        )
                      else
                        const _EmptyPlaceholder(),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _Banner(message: _error!, isError: true),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 16),
                        _Banner(message: _success!, isError: false),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索结果卡片：头像 + 名字 + portal URL + 添加按钮
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.displayName,
    required this.mxid,
    required this.portalUrl,
    required this.loading,
    required this.onAdd,
  });

  final String displayName;
  final String mxid;
  final String portalUrl;
  final bool loading;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PortalAvatar(seed: displayName, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  portalUrl.isNotEmpty ? portalUrl : mxid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AddPill(loading: loading, onTap: onAdd),
        ],
      ),
    );
  }
}

/// 右侧圆角胶囊「添加」按钮 —— 对齐 s-new-friends 的「接受」按钮样式。
class _AddPill extends StatelessWidget {
  const _AddPill({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final disabled = onTap == null;
    return Material(
      color: disabled ? t.accent.withValues(alpha: 0.5) : t.accent,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.onAccent),
                  ),
                )
              : Text(
                  '添加',
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: t.onAccent,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 空态占位 —— 未输入或未搜索时显示。
class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Symbols.person_search, size: 56, color: t.textMute),
          const SizedBox(height: 12),
          Text(
            '输入对方的 Node ID 或域名查找',
            textAlign: TextAlign.center,
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(t.accent),
          ),
        ),
      ),
    );
  }
}

/// 错误 / 成功提示横幅。
class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = isError ? t.danger : t.accentCool;
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
          Icon(
            isError ? Symbols.error : Symbols.check_circle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTheme.sans(size: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
