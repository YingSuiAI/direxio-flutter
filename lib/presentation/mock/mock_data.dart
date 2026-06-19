// Mock 数据：在没真连 Matrix homeserver 时让 UI 能展示出聊天列表 + 消息。
// 真登录后 client.rooms 非空，自动走真数据。
import 'package:flutter/material.dart';

import '../utils/contact_identity_label.dart';

/// 头像 URL：抓自 P2P-APP-UI/index.html 设计稿（lh3.googleusercontent.com/aida-public）。
/// 集中放在这里，方便联系人/聊天/详情等多处复用同一张图。
class MockAvatars {
  static const me =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDLvifagTSHVJO5ZPyKTIj9TERBMcxGFMdC6lNB42q2HLrc25zQG_W6P9xQQdDyyWml4q6K0OuxfyQN1m3wlHzzjQWzATmfuKQJdP937nxZZ2UfP9H_29MtNMTE2zkMSYP1QfZEUOOA4lSPFYKJW_CnzgAxKuqHAl_6KT9t-MkCpKIdBEggNOwydo5L20g1NdZNhHsGp1n-7LYU3ukWK97Q7Gp5T4YzLNvf9wum5cOkzsVcNfR4bYE323XQpN5hFCvBrJE1ASKahgM';
  static const alice =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD6NWImSaJK0C05V6-WJiwBVOsclTU6Jd08B1oViyDovVbf-tY0rFq74uvo1MxsiJVuRfnTZML-rUaNEoHZiE86eiqdMMDDZAof78YMBan_BxeOP163tjBbBMaUswvo5E2Ti_4DPnWEh7_eDcB7z9pRieLF2BhX-lG4chTKS_Vp0w0yLBeKVtnrwxKuQ50uw3Di-cpyJ_-DyPQYzENgsYei-bkVsTh_VtU90CD0vsdKOOMTGO340AXuXk49b1xWjrROSngFVqKz1Ac';
  static const bob =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCCH7duarxI5Gs6vPvMAK7nksjqbvGGQT8QppTjLPq3x2jnNs4P6pkcn5aFQw-iXRpMncXepMw8IewG2uL2EishD8brZl1AB3gtDaTIUZYJW946jt0mqK4dfC47XiQoT5AzS-xvl-_CapIsNOp8DZa-oOqmpXLHTYRHkpUbPKU6PClzz1b2bG4GsG7OZDDMpnnMSDLDgqF7AoMCKC46xXx-ZlxLIhfq2W0VL0PREiWzuVO1LHB0_ZSWJFgBSI6Bko_jUT8W9AFlgw8';
  static const dave =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBt1HbYj3yl6qqlO6LoOpUKyH-m9bAjXV00pnlJVWDb7mRTWlgsAgqJB3WJcbGBMVWQvPNb-Y6EI801GmIhjTXzgNWGAqzjQF4fORAse8JZKSBUrAXbpOZI2CzAIh1p5lTVL-LaCuw7Yx6HAd4lbuWeGW-TC7La-S5FVu3sDHEao1Mpt_LPxyutggyIKzxSvi7JVm8X0cO4w4emSXjPxt-X65giKXW8IL0WDF6CUBv_9Fg6vc4uoCSdSlR25tlkFwsB153wgrxxe4M';
}

enum MockMsgKind { text, toolCall, typing, system, image, file }

class MockMessage {
  const MockMessage({
    required this.isMe,
    required this.text,
    required this.time,
    this.kind = MockMsgKind.text,
    this.senderName,
    this.imageUrl,
    this.fileName,
    this.fileSize,
    this.fileMime,
    this.toolName,
    this.toolArgs,
    this.toolResultSummary,
    this.toolLatencyMs,
    this.toolWarnings,
    this.quotedSender,
    this.quotedText,
    this.chatRecordContent = const {},
  });
  final bool isMe;
  final String text;
  final DateTime time;

  /// 群聊中对方消息的发送者名；单聊或自己发的为 null。
  final String? senderName;
  final MockMsgKind kind;

  // 图片消息专用（kind == image）
  final String? imageUrl;

  // 文件消息专用（kind == file）
  final String? fileName;
  final String? fileSize; // 已格式化好的展示文本，如 "PDF · 2.8 MB"
  final String? fileMime;
  // 工具调用专用
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final String? toolResultSummary;
  final int? toolLatencyMs;
  final List<String>? toolWarnings;
  final String? quotedSender;
  final String? quotedText;

  /// 转发的聊天记录消息专用：保存 Matrix 兼容的 chat_record payload。
  final Map<String, Object?> chatRecordContent;
}

class MockConversation {
  const MockConversation({
    required this.id,
    required this.name,
    required this.mxid,
    required this.subtitle,
    required this.messages,
    this.unread = 0,
    this.accentColor,
    this.avatarUrl,
    this.members,
    this.isOwnerGroup = false,
    bool? isGroup,
  }) : isGroup = isGroup ?? members != null;
  final String id;
  final String name;
  final String mxid;
  final String subtitle;
  final int unread;
  final List<MockMessage> messages;
  final Color? accentColor;
  final String? avatarUrl;
  final List<String>? members;
  final bool isOwnerGroup;
  final bool isGroup;

  MockMessage? get lastMessage => messages.isEmpty ? null : messages.last;
}

class MockContactHome {
  const MockContactHome({
    required this.userId,
    required this.displayName,
    required this.domain,
    required this.bio,
    required this.avatarUrl,
    required this.channels,
    required this.dynamics,
  });

  final String userId;
  final String displayName;
  final String domain;
  final String bio;
  final String? avatarUrl;
  final List<MockContactChannel> channels;
  final List<MockContactDynamic> dynamics;
}

class MockContactChannel {
  const MockContactChannel({
    required this.name,
    required this.description,
    required this.memberCount,
    this.roomId = '',
    this.channelId = '',
    this.avatarUrl,
  });

  final String name;
  final String description;
  final int memberCount;
  final String roomId;
  final String channelId;
  final String? avatarUrl;
}

class MockContactDynamic {
  const MockContactDynamic({
    required this.month,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.previewColor,
    required this.sortKey,
  });

  final String month;
  final String day;
  final String title;
  final String subtitle;
  final int previewColor;
  final int sortKey;
}

class MockData {
  static final DateTime _now = DateTime.now();

  static final List<MockConversation> conversations = [
    const MockConversation(
      id: 'mock_aibot',
      name: 'OpenClaw',
      mxid: '@openclaw:local',
      subtitle: '本机 OpenClaw 已接入',
      unread: 0,
      accentColor: Color(0xFF3097CB),
      messages: [],
    ),
    MockConversation(
      id: 'mock_alice',
      name: 'Alice Chen',
      mxid: '@alice:portal.local',
      subtitle: '好的，明天见！',
      unread: 2,
      avatarUrl: MockAvatars.alice,
      messages: [
        MockMessage(
          isMe: false,
          text: '你好！',
          time: _now.subtract(const Duration(minutes: 30)),
        ),
        MockMessage(
          isMe: true,
          text: '嗨，最近怎么样？',
          time: _now.subtract(const Duration(minutes: 28)),
        ),
        MockMessage(
          isMe: false,
          text: '还不错，在忙一个新项目',
          time: _now.subtract(const Duration(minutes: 25)),
        ),
        MockMessage(
          isMe: true,
          text: '听起来不错！是什么项目呢？',
          time: _now.subtract(const Duration(minutes: 23)),
        ),
        MockMessage(
          isMe: false,
          text: '是一个去中心化通讯应用，我整理了一份设计文档',
          time: _now.subtract(const Duration(minutes: 20)),
        ),
        MockMessage(
          isMe: false,
          text: 'design_v2.pdf',
          time: _now.subtract(const Duration(minutes: 19)),
          kind: MockMsgKind.file,
          fileName: 'design_v2.pdf',
          fileSize: 'PDF · 2.8 MB',
          fileMime: 'application/pdf',
        ),
        MockMessage(
          isMe: false,
          text: '[图片]',
          time: _now.subtract(const Duration(minutes: 18)),
          kind: MockMsgKind.image,
          imageUrl: 'https://picsum.photos/seed/alice1/600/450',
        ),
        MockMessage(
          isMe: true,
          text: '[图片]',
          time: _now.subtract(const Duration(minutes: 17)),
          kind: MockMsgKind.image,
          imageUrl: 'https://picsum.photos/seed/sent1/600/450',
        ),
        MockMessage(
          isMe: true,
          text: '好的，明天见！',
          time: _now.subtract(const Duration(minutes: 15)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_core_group',
      name: 'P2P IM 核心群',
      mxid: '!core:portal.local',
      subtitle: 'Li: 今天先把频道和动态体验跑顺',
      unread: 1,
      isOwnerGroup: true,
      members: const [
        'Li',
        'Alice Chen',
        'Bob Smith',
        'Dave Lee',
        'Agent',
      ],
      messages: [
        MockMessage(
          isMe: false,
          senderName: 'Li',
          text: '今天先把频道和动态体验跑顺',
          time: _now.subtract(const Duration(minutes: 40)),
        ),
        MockMessage(
          isMe: true,
          text: '收到，我来整理测试路径',
          time: _now.subtract(const Duration(minutes: 35)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_design_group',
      name: '产品设计组',
      mxid: '!design:portal.local',
      subtitle: 'Carol: 原型图更新了',
      unread: 5,
      members: const [
        'Alice Chen',
        'Bob Smith',
        'Carol',
        'Dave',
        'Eve',
        'Frank',
      ],
      messages: [
        MockMessage(
          isMe: false,
          senderName: 'Alice Chen',
          text: '大家好，今天来讨论一下新版本的设计方案',
          time: _now.subtract(const Duration(days: 1, hours: 5)),
        ),
        MockMessage(
          isMe: false,
          senderName: 'Bob Smith',
          text: '好的，我这边准备了几个方案',
          time: _now.subtract(const Duration(days: 1, hours: 4, minutes: 30)),
        ),
        MockMessage(
          isMe: true,
          text: '方案发出来看看',
          time: _now.subtract(const Duration(days: 1, hours: 4)),
        ),
        MockMessage(
          isMe: false,
          senderName: 'Carol',
          text: '原型图更新了',
          time: _now.subtract(const Duration(days: 1)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_agent_creator_group',
      name: 'Agent 创作小组',
      mxid: '!agent-creator:portal.local',
      subtitle: 'Mira: 动态详情页可以接入长文生成',
      unread: 0,
      members: const [
        'Mira',
        'Alice Chen',
        'Dave Lee',
        'Agent',
      ],
      messages: [
        MockMessage(
          isMe: false,
          senderName: 'Mira',
          text: '动态详情页可以接入长文生成',
          time: _now.subtract(const Duration(hours: 2, minutes: 10)),
        ),
        MockMessage(
          isMe: true,
          text: '先做 mock 体验，再接真实发布流',
          time: _now.subtract(const Duration(hours: 2)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_bob',
      name: 'Bob Smith',
      mxid: '@bob:portal.local',
      subtitle: '文件已发送，请查收',
      unread: 0,
      avatarUrl: MockAvatars.bob,
      messages: [
        MockMessage(
          isMe: false,
          text: '文件已发送，请查收',
          time: _now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_dave',
      name: 'Dave Lee',
      mxid: '@dave:portal.local',
      subtitle: '好的，我会在会议前审阅',
      unread: 0,
      avatarUrl: MockAvatars.dave,
      messages: [
        MockMessage(
          isMe: true,
          text: '请帮我看看这份文档',
          time: _now.subtract(const Duration(days: 2, hours: 1)),
        ),
        MockMessage(
          isMe: false,
          text: '好的，我会在会议前审阅',
          time: _now.subtract(const Duration(days: 2)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_eve',
      name: 'Eve Wang',
      mxid: '@eve:portal.local',
      subtitle: '收到，稍后处理',
      unread: 0,
      messages: [
        MockMessage(
          isMe: true,
          text: '帮忙处理一下这个 issue',
          time: _now.subtract(const Duration(days: 3, hours: 1)),
        ),
        MockMessage(
          isMe: false,
          text: '收到，稍后处理',
          time: _now.subtract(const Duration(days: 3)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_jack',
      name: 'Jack',
      mxid: '@jack:liyananp2p.com',
      subtitle: '另外周末有空吗？想约你打球',
      unread: 2,
      messages: [
        MockMessage(
          isMe: false,
          text: '在吗？周一下午的评审会改时间了',
          time: _now.subtract(const Duration(hours: 1, minutes: 20)),
        ),
        MockMessage(
          isMe: true,
          text: '改到几点？',
          time: _now.subtract(const Duration(hours: 1, minutes: 15)),
        ),
        MockMessage(
          isMe: false,
          text: '推到周二上午 10 点，会议室还是 A 区 3 楼',
          time: _now.subtract(const Duration(hours: 1, minutes: 10)),
        ),
        MockMessage(
          isMe: true,
          text: '收到，我把日历更新一下',
          time: _now.subtract(const Duration(hours: 1)),
        ),
        MockMessage(
          isMe: false,
          text: '对了，把上次那份 PRD 也带上，到时候要过一下',
          time: _now.subtract(const Duration(minutes: 45)),
        ),
        MockMessage(
          isMe: false,
          text: '另外周末有空吗？想约你打球',
          time: _now.subtract(const Duration(minutes: 12)),
        ),
      ],
    ),
  ];

  static List<MockConversation> get friendContacts => conversations
      .where(
          (c) => const {'mock_alice', 'mock_bob', 'mock_dave'}.contains(c.id))
      .toList();

  static List<MockConversation> get groupConversations =>
      conversations.where((c) => c.isGroup).toList();

  static MockContactHome? contactHomeByMxid(String mxid) {
    final mock = byMxid(mxid);
    if (mock == null) return null;
    final localpart = mxid.startsWith('@') && mxid.contains(':')
        ? mxid.substring(1, mxid.indexOf(':'))
        : mock.name.toLowerCase().replaceAll(' ', '.');
    final parsedDomain = domainFromMxid(mxid);
    final rawDomain = parsedDomain.isEmpty ? 'portal.local' : parsedDomain;
    final displayDomain = '$localpart.$rawDomain';

    if (mock.id == 'mock_alice') {
      return MockContactHome(
        userId: mxid,
        displayName: mock.name,
        domain: displayDomain,
        bio: '产品设计师，喜欢把复杂流程变简单。',
        avatarUrl: mock.avatarUrl,
        channels: const [
          MockContactChannel(
            name: '设计观察',
            description: '产品原型、交互细节和设计记录',
            memberCount: 246,
          ),
        ],
        dynamics: const [
          MockContactDynamic(
            month: '今天',
            day: '',
            title: '原型图更新了',
            subtitle: '把频道详情和联系人主页的几个入口重新梳理了一遍。',
            previewColor: 0xFFE4ECF7,
            sortKey: 202605261100,
          ),
          MockContactDynamic(
            month: '五月',
            day: '12',
            title: '新的资料页草稿',
            subtitle: '访客看到的是主页，不应该看到设置和编辑入口。',
            previewColor: 0xFFF1E5D8,
            sortKey: 202605121000,
          ),
        ],
      );
    }

    return MockContactHome(
      userId: mxid,
      displayName: mock.name,
      domain: displayDomain,
      bio: mock.subtitle,
      avatarUrl: mock.avatarUrl,
      channels: const [],
      dynamics: [
        MockContactDynamic(
          month: '今天',
          day: '',
          title: mock.subtitle,
          subtitle: '来自 ${mock.name} 的最近动态预览。',
          previewColor: 0xFFECEFF3,
          sortKey: 202605260900,
        ),
      ],
    );
  }

  static MockConversation? byId(String id) {
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  static MockConversation? byMxid(String mxid) {
    for (final c in conversations) {
      if (c.mxid == mxid) return c;
    }
    return null;
  }
}
