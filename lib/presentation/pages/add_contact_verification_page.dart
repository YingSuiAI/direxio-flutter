import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/contact_identity_label.dart';
import '../utils/product_conversation_summary_writer.dart';

class AddContactVerificationPage extends ConsumerStatefulWidget {
  const AddContactVerificationPage({
    super.key,
    required this.userId,
    this.displayName,
  });

  final String userId;
  final String? displayName;

  @override
  ConsumerState<AddContactVerificationPage> createState() =>
      _AddContactVerificationPageState();
}

class _AddContactVerificationPageState
    extends ConsumerState<AddContactVerificationPage> {
  final _messageController = TextEditingController();
  bool _loading = false;
  bool _requested = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (_loading || _requested) return;
    final profile = _profileForAddContact(widget.userId, widget.displayName);
    setState(() => _loading = true);
    try {
      final isLoggedIn =
          (await ref.read(authStateNotifierProvider.future)).isLoggedIn;
      if (isLoggedIn) {
        final contact = await ref.read(asClientProvider).createContactRequest(
              mxid: widget.userId,
              displayName: profile.name,
              domain: profile.domain,
            );
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.withContactEntry(contact),
            );
        await recordProductConversationMutation(
          ref,
          contact.productConversation,
        );
      }
      if (!mounted) return;
      setState(() => _requested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_requestSentText(context)),
          duration: const Duration(milliseconds: 900),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      await Navigator.of(context).maybePop();
    } catch (e, stackTrace) {
      debugPrint(
          'send add-contact verification request failed: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_requestFailedText(context, e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: const ValueKey('add_contact_verification_scaffold'),
      backgroundColor: t.surfaceHover,
      body: Stack(
        children: [
          Column(
            children: [
              _VerificationHeader(
                title: l10n?.addContactVerificationTitle ?? '好友验证',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                  child: _VerificationCard(
                    controller: _messageController,
                    title: l10n?.addContactVerificationMessageTitle ?? '发送好友申请',
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            child: _VerificationSubmitButton(
              loading: _loading,
              requested: _requested,
              label: l10n?.addContactVerificationSend ?? '发送申请',
              requestedLabel: l10n?.contactFriendRequested ?? '已申请',
              onTap: _sendRequest,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationHeader extends StatelessWidget {
  const _VerificationHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final t = context.tk;
    return SizedBox(
      height: topInset + 56,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _VerificationBackButton(onTap: () => context.pop()),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ).copyWith(letterSpacing: -0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationBackButton extends StatelessWidget {
  const _VerificationBackButton({required this.onTap});

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
      child: Material(
        color: t.surface.withValues(alpha: 0.65),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
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
    );
  }
}

class _VerificationCard extends StatefulWidget {
  const _VerificationCard({
    required this.controller,
    required this.title,
  });

  final TextEditingController controller;
  final String title;

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  static const _maxLength = 200;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _VerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onTextChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.controller.text.characters.length;
    return Container(
      key: const ValueKey('add_contact_verification_card'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: AppTheme.sans(
              size: 14,
              weight: FontWeight.w500,
              color: t.text,
            ).copyWith(letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('add_contact_verification_message_box'),
            height: 74,
            decoration: BoxDecoration(
              color: isDark ? t.surfaceHover : t.bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: widget.controller,
              maxLength: _maxLength,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTheme.sans(size: 14, color: t.text),
              cursorColor: t.accent,
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: AppTheme.sans(size: 14, color: t.textMute),
                contentPadding: const EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$count/$_maxLength',
              style: AppTheme.sans(size: 10, color: t.textMute)
                  .copyWith(letterSpacing: -0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationSubmitButton extends StatelessWidget {
  const _VerificationSubmitButton({
    required this.loading,
    required this.requested,
    required this.label,
    required this.requestedLabel,
    required this.onTap,
  });

  final bool loading;
  final bool requested;
  final String label;
  final String requestedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: loading || requested ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          disabledBackgroundColor: t.accent.withValues(alpha: 0.45),
          disabledForegroundColor: t.onAccent.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(t.onAccent),
                ),
              )
            : Text(
                requested ? requestedLabel : label,
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w500,
                  color: t.onAccent,
                ).copyWith(letterSpacing: -0.4),
              ),
      ),
    );
  }
}

class _AddContactProfile {
  const _AddContactProfile({
    required this.name,
    required this.domain,
  });

  final String name;
  final String domain;
}

_AddContactProfile _profileForAddContact(String userId, String? displayName) {
  final domain = domainFromMxid(userId);
  final name = contactDisplayNameFromIdentity(
    mxid: userId,
    displayName: displayName ?? '',
    domain: domain,
    fallback: displayName ?? userId,
  );
  return _AddContactProfile(name: name, domain: domain);
}

String _requestSentText(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations)
          ?.addContactRequestSent ??
      '好友请求已发送，等待对方接受。';
}

String _requestFailedText(BuildContext context, Object error) {
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (_selfContactRequestError(error)) {
    return l10n?.addContactCannotAddSelf ?? '不能添加自己';
  }
  return l10n?.addContactRequestFailed('$error') ?? '发送好友请求失败: $error';
}

bool _selfContactRequestError(Object error) {
  return error is AsClientException &&
      error.statusCode == 400 &&
      error.message.trim() == 'mxid must be a remote peer';
}
