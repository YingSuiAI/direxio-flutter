import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MockChannel {
  const MockChannel({
    required this.id,
    required this.name,
    required this.handle,
    required this.domain,
    required this.latestMessage,
    required this.latestAt,
    required this.latestTimeLabel,
    required this.unreadCount,
    required this.isOwned,
    required this.tags,
    required this.posts,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String handle;
  final String domain;
  final String latestMessage;
  final int latestAt;
  final String latestTimeLabel;
  final int unreadCount;
  final bool isOwned;
  final List<String> tags;
  final List<MockChannelPost> posts;
  final IconData icon;
  final Color color;
}

class MockChannelPost {
  const MockChannelPost({
    required this.author,
    required this.timeLabel,
    required this.body,
    required this.views,
    required this.reactionLabel,
    required this.commentCount,
  });

  final String author;
  final String timeLabel;
  final String body;
  final String views;
  final String reactionLabel;
  final int commentCount;
}

class MockChannels {
  static List<String> get categories {
    final userTags = <String>{};
    for (final channel in items) {
      userTags.addAll(channel.tags);
    }
    return ['全部', '我的频道', ...userTags];
  }

  static List<MockChannel> filtered(String category) {
    final channels = switch (category) {
      '全部' => items,
      '我的频道' => items.where((channel) => channel.isOwned),
      _ => items.where((channel) => channel.tags.contains(category)),
    };
    return channels.toList()..sort((a, b) => b.latestAt.compareTo(a.latestAt));
  }

  static MockChannel? byId(String id) {
    for (final channel in items) {
      if (channel.id == id) return channel;
    }
    return null;
  }

  static const items = [
    MockChannel(
      id: 'p2p-im',
      name: 'P2P IM 官方',
      handle: '@p2p-im',
      domain: 'p2p-im.com',
      latestMessage: '后端部署清单已更新',
      latestAt: 202605261840,
      latestTimeLabel: '18:40',
      unreadCount: 3,
      isOwned: true,
      tags: ['产品', '部署', '公告', '协议', '客户端', '测试', '上架'],
      posts: [
        MockChannelPost(
          author: 'owner',
          timeLabel: '今天 18:40',
          body: '后端部署清单已更新：个人资料、二维码加好友、好友审批、频道基础模型会先进入后端第一批接口。',
          views: '128',
          reactionLabel: '👍 18',
          commentCount: 7,
        ),
        MockChannelPost(
          author: 'owner',
          timeLabel: '今天 16:10',
          body: '频道页会先按用户自己的频道和已加入频道展示，不做中心化推荐流。',
          views: '96',
          reactionLabel: '❤️ 12',
          commentCount: 4,
        ),
      ],
      icon: Symbols.campaign,
      color: Color(0xFF3097CB),
    ),
    MockChannel(
      id: 'agent-workflows',
      name: 'Agent 工作流',
      handle: '@agent-workflows',
      domain: 'agent-workflows.p2p-im.com',
      latestMessage: '有人分享了群聊总结模板',
      latestAt: 202605261812,
      latestTimeLabel: '18:12',
      unreadCount: 8,
      isOwned: false,
      tags: ['AI', '创作', '自动化', 'MCP', '插件', '知识库'],
      posts: [
        MockChannelPost(
          author: 'Mira',
          timeLabel: '今天 18:12',
          body: '有人分享了群聊总结模板，可以让 Agent 先按联系人和主题聚合，再输出待办。',
          views: '2.1k',
          reactionLabel: '👍 36',
          commentCount: 12,
        ),
        MockChannelPost(
          author: 'Chen',
          timeLabel: '今天 14:36',
          body: '代写回复最好保留“发送前确认”，不要让 Agent 自动替用户发敏感内容。',
          views: '1.7k',
          reactionLabel: '💡 22',
          commentCount: 9,
        ),
      ],
      icon: Symbols.dynamic_feed,
      color: Color(0xFF006B27),
    ),
    MockChannel(
      id: 'self-hosting',
      name: '去中心化部署互助',
      handle: '@self-hosting',
      domain: 'self-hosting.p2p-im.com',
      latestMessage: 'Nginx 证书续期失败可以这样排查',
      latestAt: 202605261628,
      latestTimeLabel: '16:28',
      unreadCount: 0,
      isOwned: false,
      tags: ['部署', '产品', '安全', '运维', '证书', '域名'],
      posts: [
        MockChannelPost(
          author: 'Lin',
          timeLabel: '今天 16:28',
          body: 'Nginx 证书续期失败可以这样排查：先看 DNS，再看 80 端口，再看 certbot 日志。',
          views: '824',
          reactionLabel: '🔧 19',
          commentCount: 6,
        ),
      ],
      icon: Symbols.hub,
      color: Color(0xFF7D5260),
    ),
    MockChannel(
      id: 'indie-builders',
      name: '独立开发者广场',
      handle: '@indie-builders',
      domain: 'indie-builders.p2p-im.com',
      latestMessage: '早期用户访谈问题清单',
      latestAt: 202605261544,
      latestTimeLabel: '15:44',
      unreadCount: 0,
      isOwned: false,
      tags: ['产品', '创作', '增长', '用户访谈', '商业化'],
      posts: [
        MockChannelPost(
          author: 'Ava',
          timeLabel: '今天 15:44',
          body: '早期用户访谈问题清单：先问最近一次痛点场景，再问现在如何绕过，最后问愿不愿意立刻试用。',
          views: '1.3k',
          reactionLabel: '👍 31',
          commentCount: 14,
        ),
      ],
      icon: Symbols.public,
      color: Color(0xFF6D5E00),
    ),
    MockChannel(
      id: 'ai-studio',
      name: 'AI 创作实验室',
      handle: '@ai-studio',
      domain: 'ai-studio.p2p-im.com',
      latestMessage: '短视频脚本生成流程已整理',
      latestAt: 202605261320,
      latestTimeLabel: '13:20',
      unreadCount: 1,
      isOwned: true,
      tags: ['AI', '创作', '多媒体', '视频', '图片', '脚本'],
      posts: [
        MockChannelPost(
          author: 'owner',
          timeLabel: '今天 13:20',
          body: '短视频脚本生成流程已整理：主题、爆点、分镜、标题、发布文案分成五步。',
          views: '342',
          reactionLabel: '✨ 15',
          commentCount: 5,
        ),
      ],
      icon: Symbols.rss_feed,
      color: Color(0xFF8C1D18),
    ),
    MockChannel(
      id: 'local-nodes',
      name: '本地节点生活',
      handle: '@local-nodes',
      domain: 'local-nodes.p2p-im.com',
      latestMessage: '周末线下节点部署互助活动',
      latestAt: 202605252108,
      latestTimeLabel: '昨天',
      unreadCount: 0,
      isOwned: false,
      tags: ['本地', '生活', '隐私', '线下', '节点', '活动'],
      posts: [
        MockChannelPost(
          author: 'Nan',
          timeLabel: '昨天 21:08',
          body: '周末线下节点部署互助活动，重点解决域名解析、反代和 App 首次登录。',
          views: '418',
          reactionLabel: '🙌 11',
          commentCount: 3,
        ),
      ],
      icon: Symbols.location_on,
      color: Color(0xFF006A6A),
    ),
  ];
}
