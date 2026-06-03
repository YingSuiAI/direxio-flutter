class MockFollowFeedItem {
  const MockFollowFeedItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorInitial,
    required this.title,
    required this.likes,
    required this.publishedAt,
    required this.coverTone,
    required this.coverHeight,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorInitial;
  final String title;
  final int likes;
  final int publishedAt;
  final int coverTone;
  final double coverHeight;
}

class MockFollowFeedAuthor {
  const MockFollowFeedAuthor({
    required this.id,
    required this.name,
    required this.initial,
  });

  final String id;
  final String name;
  final String initial;
}

class MockFollowFeed {
  static String get defaultAuthorId => authors.first.id;

  static List<MockFollowFeedAuthor> get authors {
    final seen = <String>{};
    final latestByAuthor = <String, MockFollowFeedItem>{};
    for (final item in items) {
      final existing = latestByAuthor[item.authorId];
      if (existing == null || item.publishedAt > existing.publishedAt) {
        latestByAuthor[item.authorId] = item;
      }
    }
    final ordered = latestByAuthor.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final result = <MockFollowFeedAuthor>[];
    for (final item in ordered) {
      if (!seen.add(item.authorId)) continue;
      result.add(
        MockFollowFeedAuthor(
          id: item.authorId,
          name: item.authorName,
          initial: item.authorInitial,
        ),
      );
    }
    return result;
  }

  static List<MockFollowFeedItem> filtered(String authorId) {
    final normalized = authorId.trim().isEmpty ? defaultAuthorId : authorId;
    final feed = items.where((item) => item.authorId == normalized);
    return feed.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  static const items = [
    MockFollowFeedItem(
      id: 'deploy-checklist',
      authorId: 'yanan',
      authorName: 'Yanan',
      authorInitial: 'Y',
      title: 'Agent 帮我把部署流程整理成一张清单',
      likes: 42,
      publishedAt: 202605290918,
      coverTone: 0,
      coverHeight: 214,
    ),
    MockFollowFeedItem(
      id: 'media-favorites',
      authorId: 'alice',
      authorName: 'Alice',
      authorInitial: 'A',
      title: '图片消息发送和收藏页体验记录',
      likes: 16,
      publishedAt: 202605291130,
      coverTone: 1,
      coverHeight: 150,
    ),
    MockFollowFeedItem(
      id: 'direct-boundaries',
      authorId: 'dave',
      authorName: 'Dave',
      authorInitial: 'D',
      title: '私聊关系边界测试记录',
      likes: 9,
      publishedAt: 202605291020,
      coverTone: 2,
      coverHeight: 184,
    ),
    MockFollowFeedItem(
      id: 'channel-dynamics',
      authorId: 'mira',
      authorName: 'Mira',
      authorInitial: 'M',
      title: '频道帖子如何进入动态流',
      likes: 21,
      publishedAt: 202605290842,
      coverTone: 3,
      coverHeight: 132,
    ),
    MockFollowFeedItem(
      id: 'video-preview',
      authorId: 'li',
      authorName: 'Li',
      authorInitial: 'L',
      title: '视频首帧预览和播放体验梳理',
      likes: 28,
      publishedAt: 202605281930,
      coverTone: 4,
      coverHeight: 178,
    ),
    MockFollowFeedItem(
      id: 'node-notes',
      authorId: 'nora',
      authorName: 'Nora',
      authorInitial: 'N',
      title: '个人节点运行日志和证书提醒',
      likes: 11,
      publishedAt: 202605281720,
      coverTone: 0,
      coverHeight: 160,
    ),
    MockFollowFeedItem(
      id: 'writing-wall',
      authorId: 'owen',
      authorName: 'Owen',
      authorInitial: 'O',
      title: '作品墙改成动态后怎么组织内容',
      likes: 7,
      publishedAt: 202605281640,
      coverTone: 1,
      coverHeight: 196,
    ),
    MockFollowFeedItem(
      id: 'privacy-review',
      authorId: 'qin',
      authorName: 'Qin',
      authorInitial: 'Q',
      title: '新设备登录只拉未读消息的隐私复盘',
      likes: 19,
      publishedAt: 202605281520,
      coverTone: 2,
      coverHeight: 172,
    ),
    MockFollowFeedItem(
      id: 'channel-rules',
      authorId: 'rhea',
      authorName: 'Rhea',
      authorInitial: 'R',
      title: '频道和群聊的边界不要混在一起',
      likes: 14,
      publishedAt: 202605281430,
      coverTone: 3,
      coverHeight: 148,
    ),
    MockFollowFeedItem(
      id: 'deploy-skill',
      authorId: 'sam',
      authorName: 'Sam',
      authorInitial: 'S',
      title: '部署 skill 的 AWS 检测脚本清单',
      likes: 25,
      publishedAt: 202605281330,
      coverTone: 4,
      coverHeight: 188,
    ),
  ];
}
