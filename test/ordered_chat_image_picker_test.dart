import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_media_send_flow.dart';
import 'package:portal_app/presentation/chat/ordered_chat_image_picker.dart';

void main() {
  test('uses iOS ordered picker and preserves selected image order', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: true,
      pickOrderedIOSImages: () async => [
        _image('first.heic', [1], mimeType: 'image/heic'),
        _image('second.png', [2], mimeType: 'image/png'),
        _image('third.jpg', [3], mimeType: 'image/jpeg'),
      ],
      pickFallbackImages: () async {
        fail('iOS ordered picker should be used before fallback picker');
      },
    );

    final attachments = await picker.pickImages();

    expect(attachments.map((a) => a.name), ['first.heic', 'second.png', 'third.jpg']);
    expect(attachments.map((a) => a.mimeType), ['image/heic', 'image/png', 'image/jpeg']);
    expect(attachments.map((a) => a.bytes.single), [1, 2, 3]);
  });

  test('uses fallback picker for non-iOS targets and preserves order', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: false,
      pickOrderedIOSImages: () async {
        fail('non-iOS picker should use the fallback picker');
      },
      pickFallbackImages: () async => [
        _image('android-first.jpg', [10]),
        _image('android-second.jpg', [20]),
      ],
    );

    final attachments = await picker.pickImages();

    expect(attachments.map((a) => a.name), ['android-first.jpg', 'android-second.jpg']);
    expect(attachments.map((a) => a.bytes.single), [10, 20]);
  });

  test('wraps image read failures as chat media read failures', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: true,
      pickOrderedIOSImages: () async => [
        PickedChatImage(
          name: 'broken.jpg',
          mimeType: 'image/jpeg',
          readAsBytes: () async => throw StateError('unreadable image'),
        ),
      ],
      pickFallbackImages: () async => const [],
    );

    await expectLater(
      picker.pickImages(),
      throwsA(
        isA<ChatMediaSendException>()
            .having((e) => e.stage, 'stage', ChatMediaSendStage.read)
            .having((e) => e.label, 'label', '图片'),
      ),
    );
  });
}

PickedChatImage _image(
  String name,
  List<int> bytes, {
  String mimeType = 'image/jpeg',
}) {
  return PickedChatImage(
    name: name,
    mimeType: mimeType,
    readAsBytes: () async => Uint8List.fromList(bytes),
  );
}
