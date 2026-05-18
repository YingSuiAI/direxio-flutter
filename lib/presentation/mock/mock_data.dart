/// Mock 数据：在没真连 Matrix homeserver 时让 UI 能展示出聊天列表 + 消息。
/// 真登录后 client.rooms 非空，自动走真数据。
import 'package:flutter/material.dart';

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

enum MockMsgKind { text, toolCall, typing, system }

class MockMessage {
  const MockMessage({
    required this.isMe,
    required this.text,
    required this.time,
    this.kind = MockMsgKind.text,
    this.toolName,
    this.toolArgs,
    this.toolResultSummary,
    this.toolLatencyMs,
    this.toolWarnings,
  });
  final bool isMe;
  final String text;
  final DateTime time;
  final MockMsgKind kind;
  // 工具调用专用
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final String? toolResultSummary;
  final int? toolLatencyMs;
  final List<String>? toolWarnings;
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
    this.isGroup = false,
  });
  final String id;
  final String name;
  final String mxid;
  final String subtitle;
  final int unread;
  final List<MockMessage> messages;
  final Color? accentColor;
  final String? avatarUrl;
  final bool isGroup;

  MockMessage? get lastMessage =>
      messages.isEmpty ? null : messages.last;
}

class MockData {
  static final DateTime _now = DateTime.now();

  static final List<MockConversation> conversations = [
    MockConversation(
      id: 'mock_aibot',
      name: 'My Agent',
      mxid: '@aibot:portal.ai',
      subtitle: '今日摘要已准备好，有 3 条新警报',
      unread: 1,
      accentColor: const Color(0xFF0058BC),
      messages: [
        MockMessage(
          isMe: true,
          text: '请帮我查询今天天气',
          time: _now.subtract(const Duration(minutes: 3)),
        ),
        MockMessage(
          isMe: false,
          text:
              '## ☀️ 今日上海天气\n\n'
              '| 指标 | 值 |\n'
              '| --- | --- |\n'
              '| 天气 | 多云转晴 |\n'
              '| 气温 | **18 ~ 26°C** |\n'
              '| 风向 | 东南风 3 级 |\n'
              '| 空气质量 | 良 |\n'
              '| 紫外线 | 中等 |\n\n'
              '> ☔ 上午有零星阵雨可能，建议出门带把伞；下午会逐渐放晴。',
          time: _now.subtract(const Duration(minutes: 2, seconds: 30)),
        ),
        MockMessage(
          isMe: true,
          text: '那适合户外活动吗？',
          time: _now.subtract(const Duration(minutes: 2)),
        ),
        MockMessage(
          isMe: false,
          text: '下午 **15:00 之后** 比较适合，建议轻便外套即可。\n\n需要我帮你查附近的公园吗？',
          time: _now.subtract(const Duration(minutes: 1, seconds: 50)),
        ),
      ],
    ),
    MockConversation(
      id: 'mock_alice',
      name: 'Alice Chen',
      mxid: '@alice:portal.local',
      subtitle: '好的，明天见！',
      unread: 2,
      avatarUrl: MockAvatars.alice,
      messages: [
        MockMessage(isMe: false, text: '你好！',
            time: _now.subtract(const Duration(minutes: 30))),
        MockMessage(isMe: true, text: '嗨，最近怎么样？',
            time: _now.subtract(const Duration(minutes: 28))),
        MockMessage(isMe: false, text: '还不错，在忙一个新项目',
            time: _now.subtract(const Duration(minutes: 25))),
        MockMessage(isMe: true, text: '听起来不错！是什么项目呢？',
            time: _now.subtract(const Duration(minutes: 23))),
        MockMessage(isMe: false, text: '是一个去中心化通讯应用，我整理了一份设计文档',
            time: _now.subtract(const Duration(minutes: 20))),
        MockMessage(isMe: true, text: '好的，明天见！',
            time: _now.subtract(const Duration(minutes: 15))),
      ],
    ),
    MockConversation(
      id: 'mock_design_group',
      name: '产品设计组',
      mxid: '#design-group:portal.local',
      subtitle: 'Carol: 原型图更新了',
      unread: 5,
      isGroup: true,
      messages: [
        MockMessage(isMe: false, text: 'Alice: 大家好，今天来讨论一下新版本的设计方案',
            time: _now.subtract(const Duration(days: 1, hours: 5))),
        MockMessage(isMe: false, text: 'Bob: 好的，我这边准备了几个方案',
            time: _now.subtract(const Duration(days: 1, hours: 4, minutes: 30))),
        MockMessage(isMe: true, text: '方案发出来看看',
            time: _now.subtract(const Duration(days: 1, hours: 4))),
        MockMessage(isMe: false, text: 'Carol: 原型图更新了',
            time: _now.subtract(const Duration(days: 1))),
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
        MockMessage(isMe: false, text: '文件已发送，请查收',
            time: _now.subtract(const Duration(days: 1, hours: 2))),
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
        MockMessage(isMe: true, text: '请帮我看看这份文档',
            time: _now.subtract(const Duration(days: 2, hours: 1))),
        MockMessage(isMe: false, text: '好的，我会在会议前审阅',
            time: _now.subtract(const Duration(days: 2))),
      ],
    ),
    MockConversation(
      id: 'mock_eve',
      name: 'Eve Wang',
      mxid: '@eve:portal.local',
      subtitle: '收到，稍后处理',
      unread: 0,
      messages: [
        MockMessage(isMe: true, text: '帮忙处理一下这个 issue',
            time: _now.subtract(const Duration(days: 3, hours: 1))),
        MockMessage(isMe: false, text: '收到，稍后处理',
            time: _now.subtract(const Duration(days: 3))),
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
