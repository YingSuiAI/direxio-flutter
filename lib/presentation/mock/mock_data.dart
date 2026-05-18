/// Mock 数据：在没真连 Matrix homeserver 时让 UI 能展示出聊天列表 + 消息。
/// 真登录后 client.rooms 非空，自动走真数据。
import 'package:flutter/material.dart';

enum MockMsgKind { text, toolCall, typing, system }

class MockMessage {
  const MockMessage({
    required this.isMe,
    required this.text,
    required this.time,
    this.kind = MockMsgKind.text,
    this.senderName,
    this.toolName,
    this.toolArgs,
    this.toolResultSummary,
    this.toolLatencyMs,
    this.toolWarnings,
  });
  final bool isMe;
  final String text;
  final DateTime time;

  /// 群聊中对方消息的发送者名；单聊或自己发的为 null。
  final String? senderName;
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
    this.members,
  });
  final String id;
  final String name;
  final String mxid;
  final String subtitle;
  final int unread;
  final List<MockMessage> messages;
  final Color? accentColor;

  /// 群聊成员名；为 null 表示单聊。
  final List<String>? members;

  bool get isGroup => members != null;

  MockMessage? get lastMessage =>
      messages.isEmpty ? null : messages.last;
}

class MockData {
  static final DateTime _now = DateTime.now();

  static final List<MockConversation> conversations = [
    MockConversation(
      id: 'mock_aibot',
      name: 'AI Bot',
      mxid: '@aibot:portal.ai',
      subtitle: 'AI 助手',
      unread: 0,
      accentColor: const Color(0xFF6FA8FF),
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
      id: 'mock_jack',
      name: 'Jack',
      mxid: '@jack:liyananp2p.com',
      subtitle: '工作伙伴',
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
    MockConversation(
      id: 'mock_design_group',
      name: '产品设计组',
      mxid: '!design:liyananp2p.com',
      subtitle: '6 名成员',
      unread: 0,
      accentColor: const Color(0xFF34C759),
      members: const ['Alice Chen', 'Bob Smith', 'Carol', 'Dave', 'Eve', 'Frank'],
      messages: [
        MockMessage(
          isMe: false,
          senderName: 'Alice Chen',
          text: '大家好，今天来讨论一下新版本的设计方案',
          time: _now.subtract(const Duration(hours: 2, minutes: 10)),
        ),
        MockMessage(
          isMe: false,
          senderName: 'Bob Smith',
          text: '好的，我这边准备了几个方案',
          time: _now.subtract(const Duration(hours: 2, minutes: 5)),
        ),
        MockMessage(
          isMe: true,
          text: '方案发出来看看',
          time: _now.subtract(const Duration(hours: 2)),
        ),
        MockMessage(
          isMe: false,
          senderName: 'Alice Chen',
          text: '稍等，我整理一下文档链接',
          time: _now.subtract(const Duration(minutes: 30)),
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
}
