import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_room_recovery_controller.dart';

void main() {
  test('runs one automatic recovery attempt until retry', () {
    final controller = ChatRoomRecoveryController();

    expect(controller.begin(), isTrue);
    expect(controller.inFlight, isTrue);
    expect(controller.attempted, isTrue);
    expect(controller.failed, isFalse);

    expect(controller.begin(), isFalse);

    controller.finish(recovered: false);
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isTrue);
    expect(controller.failed, isTrue);
    expect(controller.begin(), isFalse);

    controller.retry();
    expect(controller.begin(), isTrue);
    expect(controller.inFlight, isTrue);
    expect(controller.failed, isFalse);
  });

  test('successful recovery and sync reset clear stale failure', () {
    final controller = ChatRoomRecoveryController();

    expect(controller.begin(), isTrue);
    controller.finish(recovered: true);
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isFalse);
    expect(controller.failed, isFalse);

    expect(controller.begin(), isTrue);
    controller.finish(recovered: false);
    expect(controller.failed, isTrue);

    controller.reset();
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isFalse);
    expect(controller.failed, isFalse);
    expect(controller.begin(), isTrue);
  });

  test('runAttempt owns recovery result state transitions', () async {
    final controller = ChatRoomRecoveryController();
    var calls = 0;

    final recovered = await controller.runAttempt(
      attempt: () async {
        calls++;
        return true;
      },
    );

    expect(recovered, ChatRoomRecoveryAttemptResult.recovered);
    expect(calls, 1);
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isFalse);
    expect(controller.failed, isFalse);

    final failed = await controller.runAttempt(
      attempt: () async {
        calls++;
        return false;
      },
    );
    final skipped = await controller.runAttempt(
      attempt: () async {
        calls++;
        return true;
      },
    );

    expect(failed, ChatRoomRecoveryAttemptResult.failed);
    expect(skipped, ChatRoomRecoveryAttemptResult.skipped);
    expect(calls, 2);
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isTrue);
    expect(controller.failed, isTrue);

    final forced = await controller.runAttempt(
      force: true,
      attempt: () async {
        calls++;
        return true;
      },
    );

    expect(forced, ChatRoomRecoveryAttemptResult.recovered);
    expect(calls, 3);
    expect(controller.failed, isFalse);
  });

  test('runAttempt records failed state when recovery throws', () async {
    final controller = ChatRoomRecoveryController();

    final result = await controller.runAttempt(
      attempt: () async => throw StateError('sync failed'),
    );

    expect(result, ChatRoomRecoveryAttemptResult.failed);
    expect(controller.inFlight, isFalse);
    expect(controller.attempted, isTrue);
    expect(controller.failed, isTrue);
  });
}
