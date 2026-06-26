import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_scroll_to_latest.dart';

void main() {
  test('does not complete an initial scroll before dimensions are ready', () {
    final coordinator = ChatScrollToLatestCoordinator();

    expect(
      coordinator.request('message-1', targetEventPending: false),
      isTrue,
    );
    expect(coordinator.shouldJump, isTrue);
    expect(coordinator.retry('message-1'), isTrue);

    expect(
      coordinator.request('message-1', targetEventPending: false),
      isFalse,
    );

    coordinator.complete('message-1');

    expect(
      coordinator.request('message-1', targetEventPending: false),
      isFalse,
    );
  });

  test('target event navigation suppresses latest-message auto scroll', () {
    final coordinator = ChatScrollToLatestCoordinator();

    expect(
      coordinator.request('message-1', targetEventPending: true),
      isFalse,
    );
    expect(
      coordinator.request('message-1', targetEventPending: false),
      isTrue,
    );
    expect(
      coordinator.shouldRun('message-1', targetEventPending: true),
      isFalse,
    );
    expect(
      coordinator.request('message-1', targetEventPending: false),
      isTrue,
    );
  });
}
