import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../utils/direct_contact_status.dart';
import '../utils/contact_identity_label.dart';
import '../mock/mock_data.dart';
import '../widgets/portal_avatar.dart';

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);

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
    final portalUrl = _normalizePortalUrlInput(_domainCtrl.text);
    if (portalUrl.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _resolved = null;
      _resolvedDomain = null;
    });
    try {
      final isLoggedIn =
          ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
      final mockContact = _mockContactByPortalUrl(portalUrl);
      if ((_mockAuthEnabled || !isLoggedIn) && mockContact != null) {
        setState(() {
          _resolvedDomain = portalUrl;
          _resolved = {
            'mxid': mockContact.mxid,
            'display_name': mockContact.name,
          };
        });
        return;
      }

      // §2.2 域名发现：调 .well-known/portal/owner.json
      final client = ref.read(matrixClientProvider);
      final wk = WellKnownService(httpClient: client.httpClient);
      final result = await wk.discoverOwner(portalUrl);
      switch (result.availability) {
        case PortalAvailability.online:
          setState(() {
            _resolvedDomain = portalUrl;
            _resolved = {
              'mxid': result.owner!.matrixUserId,
              'display_name': contactDisplayNameFromIdentity(
                mxid: result.owner!.matrixUserId,
                displayName: result.owner!.displayName,
                domain: portalUrl,
              ),
            };
          });
        case PortalAvailability.notDeployed:
          setState(() => _error = '该域名不是产品用户');
        case PortalAvailability.unreachable:
          setState(() => _error = '该域名不是产品用户');
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
      final agentMxid = portalAgentMxidForClient(client);
      final acceptedContact =
          ref.read(asSyncCacheProvider).acceptedContactForUserId(mxid);
      final existingRoomId = client.getDirectChatFromUserId(mxid);
      final existingRoom =
          existingRoomId == null ? null : client.getRoomById(existingRoomId);
      if (existingRoom != null) {
        if (acceptedContact != null) {
          setState(() => _success = '已经是联系人。');
          return;
        }
        if (isPendingDirectContact(existingRoom, agentMxid: agentMxid)) {
          setState(() => _success = '好友请求已发送，等待对方接受。');
          return;
        }
      }
      final contact = await ref.read(asClientProvider).createContactRequest(
            mxid: mxid,
            displayName: (_resolved?['display_name'] as String?) ?? '',
            domain: _resolvedDomain ?? '',
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      final status = contact.status.trim();
      if (status != 'pending_inbound') {
        await client.oneShotSync();
      }
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      setState(() {
        _success = switch (status) {
          'accepted' => '已恢复旧会话，可以继续聊天。',
          'pending_inbound' => '对方已向你发送好友请求，请到新朋友页处理。',
          _ => '邀请已发送！等待对方接受。',
        };
      });
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
      backgroundColor: Colors.transparent,
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
                        hint: '输入 Portal URL',
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
                          onAvatarTap: () => context.push(
                            '/contact-home/${Uri.encodeComponent(_resolved!['mxid'] as String)}',
                          ),
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

String _normalizePortalUrlInput(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'^https?://', caseSensitive: false), '')
      .replaceAll(RegExp(r'/+$'), '');
}

MockConversation? _mockContactByPortalUrl(String portalUrl) {
  for (final contact in MockData.friendContacts) {
    final home = MockData.contactHomeByMxid(contact.mxid);
    if (home?.domain == portalUrl || contact.mxid == portalUrl) {
      return contact;
    }
  }
  return null;
}

/// 搜索结果卡片：头像 + 名字 + portal URL + 添加按钮
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.displayName,
    required this.mxid,
    required this.portalUrl,
    required this.loading,
    required this.onAdd,
    required this.onAvatarTap,
  });

  final String displayName;
  final String mxid;
  final String portalUrl;
  final bool loading;
  final VoidCallback? onAdd;
  final VoidCallback onAvatarTap;

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
          GestureDetector(
            key: const ValueKey('add_contact_result_avatar'),
            onTap: onAvatarTap,
            child: PortalAvatar(seed: mxid, size: 48),
          ),
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
            '输入对方的 Portal URL 查找',
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
