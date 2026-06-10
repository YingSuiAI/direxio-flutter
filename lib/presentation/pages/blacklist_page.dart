import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/portal_avatar.dart';

class BlacklistPage extends StatefulWidget {
  const BlacklistPage({super.key});

  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  final List<_BlacklistEntry> _entries = const [
    _BlacklistEntry(name: '吴世伟', seed: '@wushiwei-1:p2p-im.com'),
    _BlacklistEntry(name: '吴世伟', seed: '@wushiwei-2:p2p-im.com'),
    _BlacklistEntry(name: '林佩瑜', seed: '@linpeiyu-1:p2p-im.com'),
    _BlacklistEntry(name: '吴世伟', seed: '@wushiwei-3:p2p-im.com'),
    _BlacklistEntry(name: '吴世伟', seed: '@wushiwei-4:p2p-im.com'),
    _BlacklistEntry(name: '林佩瑜', seed: '@linpeiyu-2:p2p-im.com'),
    _BlacklistEntry(name: '林佩瑜', seed: '@linpeiyu-3:p2p-im.com'),
    _BlacklistEntry(name: '林佩瑜', seed: '@linpeiyu-4:p2p-im.com'),
  ].toList();

  void _remove(_BlacklistEntry entry) {
    setState(() => _entries.remove(entry));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已移除 ${entry.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _BlacklistHeader(topInset: topInset),
            Expanded(
              child: _entries.isEmpty
                  ? const _BlacklistEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 1),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return _BlacklistRow(
                          entry: entry,
                          onRemove: () => _remove(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlacklistEntry {
  const _BlacklistEntry({
    required this.name,
    required this.seed,
  });

  final String name;
  final String seed;
}

class _BlacklistHeader extends StatelessWidget {
  const _BlacklistHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: topInset + 57,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderGlassButton(
                icon: Symbols.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Text(
              '通讯录黑名单',
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
  const _HeaderGlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 24, color: t.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlacklistRow extends StatelessWidget {
  const _BlacklistRow({
    required this.entry,
    required this.onRemove,
  });

  final _BlacklistEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            PortalAvatar(
              seed: entry.seed,
              size: 28,
              shape: AvatarShape.squircle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 52,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: t.border.withValues(alpha: 0.45),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RemoveButton(onTap: onRemove),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '移除',
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: t.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlacklistEmpty extends StatelessWidget {
  const _BlacklistEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Text(
        '暂无黑名单联系人',
        style: AppTheme.sans(size: 14, color: t.textMute),
      ),
    );
  }
}
