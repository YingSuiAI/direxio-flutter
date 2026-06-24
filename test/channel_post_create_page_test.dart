import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portal_app/core/theme/app_theme.dart';
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
}
