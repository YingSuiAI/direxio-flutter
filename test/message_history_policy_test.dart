import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/message_history_policy.dart';

void main() {
  test('message history policy allows concrete chat open first page', () {
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen),
      isTrue,
    );
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.userLoadOlder),
      isTrue,
    );
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.unreadRecovery),
      isTrue,
    );
  });
}
