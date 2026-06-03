class MockAgentCuration {
  const MockAgentCuration({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceLabel,
    required this.sourceScope,
    required this.generatedAt,
    required this.timeLabel,
    required this.htmlUrl,
    required this.thumbnailUrl,
    required this.tags,
    required this.accentTone,
  });

  final String id;
  final String title;
  final String summary;
  final String sourceLabel;
  final String sourceScope;
  final int generatedAt;
  final String timeLabel;
  final String htmlUrl;
  final String thumbnailUrl;
  final List<String> tags;
  final int accentTone;
}

class MockAgentCurations {
  static List<MockAgentCuration> get sorted {
    return items.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  static const items = [
    MockAgentCuration(
      id: 'direct-contact-boundary',
      title: '私聊关系测试总结',
      summary: 'Agent 已把加好友、拒绝、删除后加回、互删后新房间等边界场景整理成一份 HTML 记录。',
      sourceLabel: '来自私聊测试与后端日志',
      sourceScope: '来自 3 个关注用户 · 2 个频道 · 5 个链接',
      generatedAt: 202605291420,
      timeLabel: '今天 14:20',
      htmlUrl: 'https://p2p-im.com/agent/html/direct-contact-boundary.html',
      thumbnailUrl: '',
      tags: ['今日重点', '私聊测试'],
      accentTone: 0,
    ),
    MockAgentCuration(
      id: 'explore-channel-review',
      title: '频道页体验复盘',
      summary: '频道页升级为探索页后，Agent 汇总了关注流、Agent 精选、频道列表三栏的信息架构。',
      sourceLabel: '来自 UI/UX 讨论',
      sourceScope: '来自 6 个频道 · 4 条动态 · 2 个设计参考',
      generatedAt: 202605291105,
      timeLabel: '今天 11:05',
      htmlUrl: 'https://p2p-im.com/agent/html/explore-channel-review.html',
      thumbnailUrl: '',
      tags: ['探索页', 'UI 复盘'],
      accentTone: 1,
    ),
    MockAgentCuration(
      id: 'media-send-quality',
      title: '图片、文件、视频发送质量报告',
      summary: '整理了多选顺序、后台发送、失败重发、缩略图缓存、收藏入口和视频预览的测试结论。',
      sourceLabel: '来自媒体消息测试',
      sourceScope: '来自 2 个私聊 · 7 张图片 · 3 个视频',
      generatedAt: 202605281830,
      timeLabel: '昨天 18:30',
      htmlUrl: 'https://p2p-im.com/agent/html/media-send-quality.html',
      thumbnailUrl: '',
      tags: ['媒体消息', '发送质量'],
      accentTone: 2,
    ),
    MockAgentCuration(
      id: 'privacy-sync',
      title: '新设备隐私同步策略',
      summary: '记录只拉离线未读、不批量拉取已读历史、可见起点和本地删除过滤的统一机制。',
      sourceLabel: '来自隐私同步方案',
      sourceScope: '来自 4 条规划记录 · 3 个边界测试',
      generatedAt: 202605271610,
      timeLabel: '5月27日 16:10',
      htmlUrl: 'https://p2p-im.com/agent/html/privacy-sync.html',
      thumbnailUrl: '',
      tags: ['隐私同步', '本地过滤'],
      accentTone: 3,
    ),
  ];
}
