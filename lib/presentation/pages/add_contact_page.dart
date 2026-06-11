import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
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
  String _query = '';

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
    });
    try {
      final isLoggedIn =
          ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
      final mockContact = _mockContactByPortalUrl(portalUrl);
      if ((_mockAuthEnabled || !isLoggedIn) && mockContact != null) {
        setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tk.surfaceHover,
      body: Column(
        children: [
          const _AddContactHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchField(
                        controller: _domainCtrl,
                        enabled: !_loading,
                        onChanged: (value) => setState(() {
                          _query = value;
                          _error = null;
                          _success = null;
                          _resolved = null;
                        }),
                        onSubmitted: (_) => _resolve(),
                      ),
                      const SizedBox(height: 12),
                      if (_loading && _resolved == null)
                        _LoadingPlaceholder()
                      else if (_resolved != null)
                        _SearchResultList(
                          query: _query,
                          results: [
                            _SearchResult(
                              displayName: _resolved!['display_name'] as String,
                              mxid: _resolved!['mxid'] as String,
                            ),
                          ],
                          onTap: (_) => context.push(
                            _addContactDetailRoute(
                              _resolved!['mxid'] as String,
                              _resolved!['display_name'] as String,
                            ),
                          ),
                        )
                      else if (_query.trim().isNotEmpty)
                        _SearchResultList(
                          query: _query,
                          results: _demoSearchResults(_query),
                          onTap: (result) => context.push(
                            _addContactDetailRoute(
                              result.mxid,
                              result.displayName,
                            ),
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

String _addContactDetailRoute(String userId, String displayName) {
  return '/add-contact/detail/${Uri.encodeComponent(userId)}'
      '?name=${Uri.encodeQueryComponent(displayName)}';
}

class _AddContactHeader extends StatelessWidget {
  const _AddContactHeader();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final t = context.tk;
    return SizedBox(
      height: topInset + 56,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderGlassButton(onTap: () => context.pop()),
            ),
            Text(
              '添加好友',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderGlassButton extends StatelessWidget {
  const _HeaderGlassButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: t.surface.withValues(alpha: 0.65),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Symbols.arrow_back, size: 24, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.textMute.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: AppTheme.sans(
            size: 16,
            weight: FontWeight.w500,
            color: t.accent,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: '搜索',
            hintStyle: AppTheme.sans(size: 16, color: t.textMute),
            prefixIcon: Icon(Symbols.search, size: 18, color: t.textMute),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 36,
            ),
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
          ),
        ),
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

List<_SearchResult> _demoSearchResults(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final results = <_SearchResult>[
    const _SearchResult(displayName: 'benjamin', mxid: '@benjamin:p2p-im.com'),
    const _SearchResult(displayName: 'benjamin', mxid: '@benjamin2:p2p-im.com'),
    for (final contact in MockData.friendContacts)
      _SearchResult(displayName: contact.name, mxid: contact.mxid),
  ];
  return results
      .where((result) => result.displayName.toLowerCase().contains(needle))
      .take(8)
      .toList(growable: false);
}

class _SearchResult {
  const _SearchResult({required this.displayName, required this.mxid});
  final String displayName;
  final String mxid;
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({
    required this.query,
    required this.results,
    required this.onTap,
  });

  final String query;
  final List<_SearchResult> results;
  final ValueChanged<_SearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const _EmptyPlaceholder();
    return Column(
      children: [
        for (final result in results)
          _SearchResultRow(
            result: result,
            query: query,
            onTap: () => onTap(result),
          ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.query,
    required this.onTap,
  });

  final _SearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.border.withValues(alpha: 0.45),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                PortalAvatar(
                  key: const ValueKey('add_contact_result_avatar'),
                  seed: result.mxid,
                  size: 28,
                  shape: AvatarShape.squircle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: _highlightNameSpan(
                      context,
                      result.displayName,
                      query,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextSpan _highlightNameSpan(BuildContext context, String name, String query) {
  final t = context.tk;
  final base = AppTheme.sans(
    size: 16,
    weight: FontWeight.w500,
    color: t.text,
  ).copyWith(letterSpacing: -0.4);
  final accent = base.copyWith(color: t.accent);
  final needle = query.trim();
  final matchIndex =
      needle.isEmpty ? -1 : name.toLowerCase().indexOf(needle.toLowerCase());
  if (matchIndex < 0) return TextSpan(text: name, style: base);
  return TextSpan(
    children: [
      if (matchIndex > 0)
        TextSpan(text: name.substring(0, matchIndex), style: base),
      TextSpan(
        text: name.substring(matchIndex, matchIndex + needle.length),
        style: accent,
      ),
      if (matchIndex + needle.length < name.length)
        TextSpan(text: name.substring(matchIndex + needle.length), style: base),
    ],
  );
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
            '输入对方昵称或 Portal URL 查找',
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
