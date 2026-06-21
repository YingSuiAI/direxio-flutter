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
}
