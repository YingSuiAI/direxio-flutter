typedef MissingRoomHistorySync = Future<void> Function({
  required String roomId,
  required int timelineLimit,
});

Future<bool> syncMissingRoomHistoryFromServer({
  required String roomId,
  required MissingRoomHistorySync syncHistory,
}) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return false;
  await syncHistory(
    roomId: trimmedRoomId,
    timelineLimit: 0,
  );
  return true;
}
