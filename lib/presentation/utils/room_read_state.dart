import 'package:matrix/matrix.dart';

bool markRoomLocallyRead(Room room) {
  if (room.notificationCount == 0 && room.highlightCount == 0) return false;
  room.notificationCount = 0;
  room.highlightCount = 0;
  return true;
}
