import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/l10n/app_localizations_zh.dart';
import 'package:portal_app/presentation/channel/channel_home_tab.dart';

void main() {
  test('channel post preview distinguishes image posts from text posts', () {
    final l10n = AppLocalizationsZh();

    expect(
      channelPostPreviewForMessageType(MessageTypes.Text, l10n),
      '新文字帖',
    );
    expect(
      channelPostPreviewForMessageType(MessageTypes.Image, l10n),
      '新图片帖',
    );
  });

  test('channel post preview treats text events with post media as image posts',
      () {
    final l10n = AppLocalizationsZh();

    expect(
      channelPostPreviewForMessageContent(
        const {
          'msgtype': MessageTypes.Text,
          'media': {
            'images': [
              {'url': 'mxc://p2p-im.com/post-image'},
            ],
          },
        },
        l10n,
      ),
      '新图片帖',
    );
  });
}
