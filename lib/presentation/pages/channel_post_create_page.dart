import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/as_client_provider.dart';
import '../providers/channel_provider.dart';

class ChannelPostCreatePage extends ConsumerStatefulWidget {
  const ChannelPostCreatePage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelPostCreatePage> createState() =>
      _ChannelPostCreatePageState();
}

class _ChannelPostCreatePageState extends ConsumerState<ChannelPostCreatePage> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final channelId = widget.channelId.trim();
    final body = _ctrl.text.trim();
    if (channelId.isEmpty || body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final post = await ref.read(asClientProvider).createChannelPost(
            channelId,
            messageType: 'text',
            body: body,
          );
      await ref
          .read(channelPostsProvider(channelId).notifier)
          .upsertLocal(post);
      if (!mounted) return;
      context.pop();
    } catch (err) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发表失败：$err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _posting ? null : () => context.pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 40),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        '取消',
                        style: AppTheme.sans(
                          size: 15,
                          weight: FontWeight.w500,
                          color: t.text,
                        ).copyWith(height: 20 / 15),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 63,
                      height: 33,
                      child: FilledButton(
                        onPressed: _posting ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.onAccent,
                          disabledBackgroundColor:
                              t.accent.withValues(alpha: 0.48),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _posting ? '发表中' : '发表',
                          style: AppTheme.sans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: t.onAccent,
                          ).copyWith(height: 20 / 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                cursorColor: t.accent,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: t.text,
                ).copyWith(height: 20 / 15),
                decoration: InputDecoration(
                  hintText: '发表帖子...',
                  hintStyle: AppTheme.sans(
                    size: 15,
                    weight: FontWeight.w500,
                    color: t.textMute.withValues(alpha: 0.62),
                  ).copyWith(height: 20 / 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(
                    30,
                    topInset > 0 ? 14 : 22,
                    30,
                    24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
