import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_media_send_flow.dart';
import 'package:portal_app/presentation/chat/ordered_chat_image_picker.dart';
import 'package:portal_app/presentation/pages/channel_post_create_page.dart';

void main() {
  testWidgets('post image picker uses chat picker with nine image limit',
      (tester) async {
    bool? requestedOriginal;
    int? requestedLimit;
    final picker = ChatImageAttachmentPicker(
      useIOSOrderedPicker: false,
      pickOrderedIOSImages: ({required original, required limit}) async {
        fail('non-iOS test picker should use fallback picker');
      },
      pickFallbackImages: ({required original, required limit}) async {
        requestedOriginal = original;
        requestedLimit = limit;
        return const [];
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChannelPostCreatePage(
            channelId: 'ch_post',
            imagePicker: picker,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('channel_post_add_image')));
    await tester.pumpAndSettle();

    expect(requestedOriginal, isFalse);
    expect(requestedLimit, chatImagePickerMaxSelection);
  });

  testWidgets('selected post images open as a swipeable preview gallery',
      (tester) async {
    final imageBytes = _onePixelPng();
    expect(imageBytes, isNotEmpty);
    var uploadCount = 0;
    Future<Uri> uploadImage(
      Uint8List file, {
      String? filename,
      String? contentType,
    }) async {
      uploadCount += 1;
      return Uri.parse('mxc://server/upload_$uploadCount');
    }

    Future<List<ChatMediaAttachment>> pickAttachments({
      required bool original,
      required int limit,
    }) async {
      return [
        ChatMediaAttachment.image(
          name: 'first.png',
          bytes: imageBytes,
          mimeType: 'image/png',
        ),
        ChatMediaAttachment.image(
          name: 'second.png',
          bytes: imageBytes,
          mimeType: 'image/png',
        ),
      ];
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChannelPostCreatePage(
            channelId: 'ch_post',
            imageAttachmentPicker: pickAttachments,
            imageUploader: uploadImage,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('channel_post_add_image')));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      if (find
          .byKey(const ValueKey('channel_post_create_image_0'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(uploadCount, 2);
    expect(
      find.byKey(const ValueKey('channel_post_create_image_0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('channel_post_create_image_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('first.png'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('second.png'), findsOneWidget);
  });
}

Uint8List _onePixelPng() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  );
}
