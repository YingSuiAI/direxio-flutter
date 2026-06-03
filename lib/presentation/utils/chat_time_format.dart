import 'package:intl/intl.dart';

String formatChatMessageTime(DateTime value, {DateTime? now}) {
  final localValue = value.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final messageDay =
      DateTime(localValue.year, localValue.month, localValue.day);
  if (messageDay == today) return DateFormat('HH:mm').format(localValue);
  if (today.difference(messageDay).inDays == 1) {
    return '昨天 ${DateFormat('HH:mm').format(localValue)}';
  }
  return '${DateFormat('M月d日').format(localValue)} ${DateFormat('HH:mm').format(localValue)}';
}
