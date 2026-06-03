import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/message_history_policy.dart';

void main() {
  test('new device privacy policy blocks automatic read-history backfill', () {
    expect(
      shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen),
      isFalse,
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
