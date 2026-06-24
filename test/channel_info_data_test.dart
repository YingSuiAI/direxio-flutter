import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/channel/channel_info_data.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';

void main() {
  test('share payload channel info keeps member count unknown', () {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:example.com',
      homeDomain: 'example.com',
      name: '产品公告',
      channelType: asChannelTypePost,
    );

    final channel = channelInfoDataFromSharePayload(payload);

    expect(channel.memberCount, -1);
    expect(channelDisplayNameWithMemberCount(channel), '产品公告');
  });

  test('known member count is still shown in channel title', () {
    const channel = ChannelInfoData(
      id: 'ch_product',
      roomId: '!channel:example.com',
      domain: 'example.com',
      name: '产品公告',
      avatarUrl: '',
      description: '',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      memberStatus: '',
      isOwned: false,
      commentsEnabled: true,
      muted: false,
      channelType: asChannelTypePost,
      tags: [],
      memberCount: 1,
    );

    expect(channelDisplayNameWithMemberCount(channel), '产品公告（1）');
  });
}
