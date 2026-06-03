import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:portal_app/presentation/utils/chat_time_format.dart';

void main() {
  test('formats utc message timestamps in local time', () {
    final utc = DateTime.utc(2026, 5, 28, 8, 15);
    final local = utc.toLocal();

    expect(
      formatChatMessageTime(utc, now: local),
      DateFormat('HH:mm').format(local),
    );
  });
}
