import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/message_history_policy.dart';

void main() {
  test('message history policy only allows unread recovery bodies', () {
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen),
      isFalse,
    );
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.userLoadOlder),
      isFalse,
    );
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.unreadRecovery),
      isTrue,
    );
  });
}
