import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/as_event_stream_provider.dart';

class RealtimeRoomFocus extends ConsumerStatefulWidget {
  const RealtimeRoomFocus({
    super.key,
    required this.roomId,
    required this.child,
  });

  final String roomId;
  final Widget child;

  @override
  ConsumerState<RealtimeRoomFocus> createState() => _RealtimeRoomFocusState();
}

class _RealtimeRoomFocusState extends ConsumerState<RealtimeRoomFocus> {
  String _reportedRoomId = '';
  AsEventStreamRefreshController? _refreshController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(RealtimeRoomFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId.trim() != widget.roomId.trim()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    }
  }

  @override
  void dispose() {
    final roomId = _reportedRoomId;
    if (roomId.isNotEmpty) {
      unawaited(_refreshController?.clearFocusedRoom());
    }
    super.dispose();
  }

  void _report() {
    if (!mounted) return;
    final roomId = widget.roomId.trim();
    if (roomId == _reportedRoomId) return;
    _reportedRoomId = roomId;
    final refreshController =
        _refreshController ?? ref.read(asEventStreamRefreshProvider);
    if (roomId.isEmpty) {
      unawaited(refreshController?.clearFocusedRoom());
      return;
    }
    unawaited(refreshController?.reportFocusedRoom(roomId));
  }

  @override
  Widget build(BuildContext context) {
    _refreshController = ref.watch(asEventStreamRefreshProvider);
    return widget.child;
  }
}
