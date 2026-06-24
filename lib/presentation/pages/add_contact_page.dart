import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../channel/public_channel_target.dart';
import '../utils/contact_identity_label.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/m3_search_field.dart';

const _addContactToolbarHeight = 48.0;
const _addContactSearchGap = 12.0;

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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _resolved = null;
    });
    try {
      // §2.2 域名发现：调 .well-known/portal/owner.json
      final client = ref.read(matrixClientProvider);
      final wk = WellKnownService(httpClient: client.httpClient);
      final result = await wk.discoverOwner(portalUrl);
      switch (result.availability) {
        case PortalAvailability.online:
          final owner = result.owner!;
          final remoteNodeBaseUri = publicBaseUriForServerName(portalUrl);
          final ownerProfile = await _resolveOwnerProfileFallback(
            client,
            owner.matrixUserId,
            displayName: owner.displayName,
            avatarUrl: owner.avatarUrl,
          );
          setState(() {
            _resolved = {
              'mxid': owner.matrixUserId,
              'display_name': contactDisplayNameFromIdentity(
                mxid: owner.matrixUserId,
                displayName: ownerProfile.displayName,
                domain: portalUrl,
              ),
              'avatar_url': avatarHttpUrl(client, ownerProfile.avatarUrl),
              if (remoteNodeBaseUri != null)
                'remote_node_base_url': remoteNodeBaseUri.toString(),
            };
          });
          break;
        case PortalAvailability.notDeployed:
          setState(() => _error = l10n.addContactDomainNotProductUser);
          break;
        case PortalAvailability.unreachable:
          setState(() => _error = l10n.addContactDomainNotProductUser);
          break;
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
      key: const ValueKey('add_contact_scaffold'),
      backgroundColor: context.tk.bg,
      body: Column(
        children: [
          const _AddContactHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                _addContactSearchGap,
                16,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchField(
                        controller: _domainCtrl,
                        enabled: !_loading,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                            _error = null;
                            _success = null;
                            _resolved = null;
                          });
                        },
                        onSubmitted: (_) => _resolve(),
                      ),
                      const SizedBox(height: _addContactSearchGap),
                      if (_loading && _resolved == null)
                        _LoadingPlaceholder()
                      else if (_resolved != null)
                        _SearchResultList(
                          query: _query,
                          results: [
                            _SearchResult(
                              displayName: _resolved!['display_name'] as String,
                              mxid: _resolved!['mxid'] as String,
                              avatarUrl: _resolved!['avatar_url'] as String?,
                            ),
                          ],
                          onTap: (_) => context.push(
                            _addContactDetailRoute(
                              _resolved!['mxid'] as String,
                              _resolved!['display_name'] as String,
                              avatarUrl: _resolved!['avatar_url'] as String?,
                              remoteNodeBaseUri:
                                  _resolvedRemoteNodeBaseUri(_resolved!),
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

Future<({String displayName, String avatarUrl})> _resolveOwnerProfileFallback(
  Client client,
  String mxid, {
  required String displayName,
  required String avatarUrl,
}) async {
  final cleanName = displayName.trim();
  final cleanAvatar = avatarUrl.trim();
  if (!_needsOwnerProfileFallback(mxid, cleanName)) {
    return (displayName: cleanName, avatarUrl: cleanAvatar);
  }
  try {
    final homeserver = client.homeserver;
    if (homeserver == null) {
      return (displayName: cleanName, avatarUrl: cleanAvatar);
    }
    final uri = homeserver.resolveUri(
      Uri(path: '_matrix/client/v3/profile/${Uri.encodeComponent(mxid)}'),
    );
    final response = await _effectiveProfileHttpClient(client.httpClient)
        .get(uri)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) {
      return (displayName: cleanName, avatarUrl: cleanAvatar);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final matrixName = (body['displayname'] as String? ??
            body['display_name'] as String? ??
            '')
        .trim();
    final matrixAvatar = (body['avatar_url'] as String? ?? '').trim();
    return (
      displayName:
          _needsOwnerProfileFallback(mxid, matrixName) ? cleanName : matrixName,
      avatarUrl: matrixAvatar.isNotEmpty ? matrixAvatar : cleanAvatar,
    );
  } catch (_) {
    return (displayName: cleanName, avatarUrl: cleanAvatar);
  }
}

http.Client _effectiveProfileHttpClient(http.Client client) {
  final dynamic maybeTimeoutClient = client;
  try {
    final inner = maybeTimeoutClient.inner;
    if (inner is http.Client) return inner;
  } catch (_) {
    // Not a Matrix SDK timeout wrapper.
  }
  return client;
}

bool _needsOwnerProfileFallback(String mxid, String displayName) {
  final name = displayName.trim();
  if (name.isEmpty) return true;
  final localpart = localpartFromMxid(mxid);
  return localpart.isNotEmpty && name == localpart;
}

String _addContactDetailRoute(
  String userId,
  String displayName, {
  String? avatarUrl,
  Uri? remoteNodeBaseUri,
}) {
  final query = <String, String>{
    'name': displayName,
    if (avatarUrl?.trim().isNotEmpty ?? false) 'avatar': avatarUrl!.trim(),
    if (remoteNodeBaseUri != null)
      'remote_node_base_url': remoteNodeBaseUri.toString(),
  };
  return '/add-contact/detail/${Uri.encodeComponent(userId)}'
      '?${Uri(queryParameters: query).query}';
}

Uri? _resolvedRemoteNodeBaseUri(Map<String, dynamic> resolved) {
  final value = (resolved['remote_node_base_url'] as String?)?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null || parsed.host.isEmpty) return null;
  if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
  return parsed;
}

class _AddContactHeader extends StatelessWidget {
  const _AddContactHeader();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final t = context.tk;
    return SizedBox(
      height: topInset + _addContactToolbarHeight,
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
              AppLocalizations.of(context).addContactTitle,
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
    return M3SearchField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      hint: AppLocalizations.of(context).commonSearch,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

String _normalizePortalUrlInput(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'^https?://', caseSensitive: false), '')
      .replaceAll(RegExp(r'/+$'), '');
}

class _SearchResult {
  const _SearchResult({
    required this.displayName,
    required this.mxid,
    this.avatarUrl,
  });
  final String displayName;
  final String mxid;
  final String? avatarUrl;
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
      color: t.bg,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          key: const ValueKey('add_contact_result_row'),
          height: 60,
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
                  imageUrl: result.avatarUrl,
                  size: 28,
                  shape: AvatarShape.squircle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: _highlightNameSpan(
                          context,
                          result.displayName,
                          query,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.mxid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                    ],
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
            AppLocalizations.of(context).addContactEmptyHint,
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
