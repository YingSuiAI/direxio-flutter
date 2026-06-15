import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_media_send_flow.dart';
import 'package:portal_app/presentation/chat/ordered_chat_image_picker.dart';

void main() {
  test('uses iOS ordered picker and preserves selected image order', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: true,
      pickOrderedIOSImages: ({required original, required limit}) async => [
        _image('first.heic', [1], mimeType: 'image/heic'),
        _image('second.png', [2], mimeType: 'image/png'),
        _image('third.jpg', [3], mimeType: 'image/jpeg'),
      ],
      pickFallbackImages: ({required original, required limit}) async {
        fail('iOS ordered picker should be used before fallback picker');
      },
    );

    final attachments = await picker.pickImages();

    expect(attachments.map((a) => a.name),
        ['first.heic', 'second.png', 'third.jpg']);
    expect(attachments.map((a) => a.mimeType),
        ['image/heic', 'image/png', 'image/jpeg']);
    expect(attachments.map((a) => a.bytes.single), [1, 2, 3]);
  });

  test('uses fallback picker for non-iOS targets and preserves order',
      () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: false,
      pickOrderedIOSImages: ({required original, required limit}) async {
        fail('non-iOS picker should use the fallback picker');
      },
      pickFallbackImages: ({required original, required limit}) async => [
        _image('android-first.jpg', [10]),
        _image('android-second.jpg', [20]),
      ],
    );

    final attachments = await picker.pickImages();

    expect(attachments.map((a) => a.name),
        ['android-first.jpg', 'android-second.jpg']);
    expect(attachments.map((a) => a.bytes.single), [10, 20]);
  });

  test('wraps image read failures as chat media read failures', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: true,
      pickOrderedIOSImages: ({required original, required limit}) async => [
        PickedChatImage(
          name: 'broken.jpg',
          mimeType: 'image/jpeg',
          readAsBytes: () async => throw StateError('unreadable image'),
        ),
      ],
      pickFallbackImages: ({required original, required limit}) async =>
          const [],
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

  test('limits selected images to nine', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: false,
      pickOrderedIOSImages: ({required original, required limit}) async {
        fail('non-iOS picker should use the fallback picker');
      },
      pickFallbackImages: ({required original, required limit}) async => [
        for (var i = 0; i < 12; i++) _image('image-$i.jpg', [i]),
      ],
    );

    final attachments = await picker.pickImages(limit: 12);

    expect(attachments, hasLength(9));
    expect(attachments.map((a) => a.name).last, 'image-8.jpg');
  });

  test('marks compressed images as non-original by default', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: false,
      pickOrderedIOSImages: ({required original, required limit}) async {
        fail('non-iOS picker should use the fallback picker');
      },
      pickFallbackImages: ({required original, required limit}) async {
        expect(original, isFalse);
        expect(limit, 9);
        return [
          _image('compressed.jpg', [1])
        ];
      },
    );

    final attachments = await picker.pickImages();

    expect(attachments.single.original, isFalse);
  });

  test('passes original selection through to picker and attachment', () async {
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: true,
      pickOrderedIOSImages: ({required original, required limit}) async {
        expect(original, isTrue);
        expect(limit, 3);
        return [
          _image('original.heic', [9], mimeType: 'image/heic')
        ];
      },
      pickFallbackImages: ({required original, required limit}) async {
        fail('iOS ordered picker should be used before fallback picker');
      },
    );

    final attachments = await picker.pickImages(original: true, limit: 3);

    expect(attachments.single.original, isTrue);
    expect(attachments.single.mimeType, 'image/heic');
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
