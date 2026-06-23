import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/design_tokens.dart';
import 'portal_avatar.dart';

class GroupCompositeAvatar extends StatelessWidget {
  const GroupCompositeAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.imageUrl,
    this.members = const [],
    this.memberAvatarUrls = const [],
    this.radius = 8,
  });

  final String seed;
  final double size;
  final String? imageUrl;
  final List<GroupCompositeAvatarMember> members;
  final List<String> memberAvatarUrls;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cleanImageUrl = imageUrl?.trim() ?? '';
    if (cleanImageUrl.isNotEmpty) {
      return PortalAvatar(
        seed: seed,
        size: size,
        imageUrl: cleanImageUrl,
        shape: AvatarShape.squircle,
      );
    }

    final items = (members.isNotEmpty
            ? members.map((member) => member.normalized)
            : memberAvatarUrls.map(
                (url) => GroupCompositeAvatarMember(seed: url, imageUrl: url),
              ))
        .where((member) => member.seed.isNotEmpty)
        .take(9)
        .toList(growable: false);
    if (items.isEmpty) {
      final t = context.tk;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Icon(Symbols.groups, size: size * 0.5, color: t.textMute),
      );
    }

    final columns = _groupAvatarColumns(items.length);
    final rows = _groupAvatarRows(items.length);
    const gap = 1.0;
    final itemSize = (size - gap * (columns - 1)) / columns;
    final rowData = [
      for (var row = 0; row < rows; row++)
        items.skip(row * columns).take(columns).toList(growable: false),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.tk.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var rowIndex = 0; rowIndex < rowData.length; rowIndex++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var columnIndex = 0;
                    columnIndex < rowData[rowIndex].length;
                    columnIndex++) ...[
                  _GroupCompositeAvatarCell(
                    member: rowData[rowIndex][columnIndex],
                    size: itemSize,
                  ),
                  if (columnIndex < rowData[rowIndex].length - 1)
                    const SizedBox(width: gap),
                ],
              ],
            ),
            if (rowIndex < rowData.length - 1) const SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}

class GroupCompositeAvatarMember {
  const GroupCompositeAvatarMember({
    required this.seed,
    this.imageUrl,
  });

  final String seed;
  final String? imageUrl;

  GroupCompositeAvatarMember get normalized {
    return GroupCompositeAvatarMember(
      seed: seed.trim(),
      imageUrl: imageUrl?.trim(),
    );
  }
}

class _GroupCompositeAvatarCell extends StatelessWidget {
  const _GroupCompositeAvatarCell({
    required this.member,
    required this.size,
  });

  final GroupCompositeAvatarMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = member.imageUrl?.trim() ?? '';
    if (!_isValidGroupAvatarUrl(url)) {
      return PortalAvatar(
        key: ValueKey('group_composite_avatar_member_${member.seed}'),
        seed: member.seed,
        size: size,
        shape: AvatarShape.squircle,
      );
    }
    return PortalAvatar(
      key: ValueKey('group_composite_avatar_member_${member.seed}_$url'),
      seed: member.seed,
      size: size,
      imageUrl: url,
      shape: AvatarShape.squircle,
    );
  }
}

int _groupAvatarColumns(int count) {
  if (count <= 1) return 1;
  if (count <= 4) return 2;
  return 3;
}

int _groupAvatarRows(int count) {
  if (count <= 1) return 1;
  if (count == 2) return 1;
  if (count <= 4) return 2;
  return ((count + 2) ~/ 3).clamp(1, 3);
}

bool _isValidGroupAvatarUrl(String value) {
  return value.startsWith('http://') || value.startsWith('https://');
}
