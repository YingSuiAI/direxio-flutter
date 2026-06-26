import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/chat/chat_attachment_panel.dart';

void main() {
  testWidgets('attachment panel exposes video call action separately',
      (tester) async {
    var videoCallTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatAttachmentPanel(
              room: null,
              roomId: 'room',
              canSend: true,
              useAsProductMedia: false,
              onClose: () {},
              onCannotSend: (_) {},
              onVideoCall: () => videoCallTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('视频通话'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);

    await tester.tap(find.text('视频通话'));
    expect(videoCallTapped, isTrue);
  });

  testWidgets('attachment panel uses localized action labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ChatAttachmentPanel(
              room: null,
              roomId: 'room',
              canSend: true,
              useAsProductMedia: false,
              onClose: () {},
              onCannotSend: (_) {},
            ),
          ),
        ),
      ),
    );

    for (final label in [
      'Album',
      'Camera',
      'Voice call',
      'Video Call',
      'Video',
      'File',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Location'), findsNothing);
    expect(find.text('Contact card'), findsNothing);
    expect(find.text('相册'), findsNothing);
    expect(find.text('拍摄'), findsNothing);
  });
}
