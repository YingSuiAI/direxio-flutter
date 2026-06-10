import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalSpaceData {
  const PersonalSpaceData({
    required this.signature,
    required this.channels,
    required this.works,
  });

  final String signature;
  final List<MyChannel> channels;
  final List<WorkItem> works;
}

class MyChannel {
  const MyChannel({
    required this.name,
    required this.domain,
    required this.description,
    required this.memberCount,
  });

  final String name;
  final String domain;
  final String description;
  final int memberCount;
}

class WorkItem {
  const WorkItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.kind,
    required this.month,
    required this.day,
    required this.sortKey,
    this.previewColor = 0xFFEFEFF2,
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
  final String kind;
  final String month;
  final String day;
  final int sortKey;
  final int previewColor;
}

final personalSpaceProvider = FutureProvider<PersonalSpaceData>((ref) async {
  return const PersonalSpaceData(
    signature: '用自己的节点，连接重要的人和内容。',
    channels: [
      MyChannel(
        name: 'P2P IM 频道',
        domain: 'p2p-im.com',
        description: '产品进展、节点部署和去中心化 IM 实验记录',
        memberCount: 128,
      ),
    ],
    works: [
      WorkItem(
        id: 'cloud-install',
        title: '第三方平台一键安装',
        subtitle: '第三方平台一键安装的云端服务能用吗？这是给我自己养的节点，还是给第三方平台养的节点？',
        body:
            '第三方平台一键安装的云端服务能用吗？这是给我自己养的节点，还是给第三方平台养的节点？如果只是把部署入口外包出去，用户的数据和控制权仍然要留在自己的域名和 VPS 上。',
        kind: '内容',
        month: '今天',
        day: '',
        sortKey: 202605261200,
        previewColor: 0xFFE7EAEE,
      ),
      WorkItem(
        id: 'stock-followup',
        title: '最后问一声，还有要加仓股票的吗',
        subtitle: '整理了一组投资讨论里的待确认问题，准备让 Agent 继续追问关键假设。',
        body: '整理了一组投资讨论里的待确认问题，准备让 Agent 继续追问关键假设，再决定是否需要生成回复草稿。',
        kind: '笔记',
        month: '五月',
        day: '06',
        sortKey: 202605061000,
        previewColor: 0xFFB00000,
      ),
      WorkItem(
        id: 'brunch',
        title: 'Brunch 一下',
        subtitle: '周末记录，顺手测试一下动态里的图片预览排版。',
        body: '周末记录，顺手测试一下动态里的图片预览排版。后续这里会支持多图、链接和 Agent 生成内容。',
        kind: '生活',
        month: '五月',
        day: '02',
        sortKey: 202605021000,
        previewColor: 0xFFE8C58A,
      ),
      WorkItem(
        id: 'agent-summary-template',
        title: 'Agent 消息总结模板',
        subtitle: '适合把长对话整理成清晰行动项，后续可以一键发布到自己的频道和动态。',
        body: '适合把长对话整理成清晰行动项，后续可以一键发布到自己的频道和动态，也可以先保存为私密内容。',
        kind: '内容',
        month: '四月',
        day: '17',
        sortKey: 202604171000,
        previewColor: 0xFFD9E2F1,
      ),
    ],
  );
});

class PersonalProfileData {
  const PersonalProfileData({
    this.displayName,
    this.bio = '用自己的节点，连接重要的人和内容。',
    this.gender = '未设置',
    this.birthday = '不展示',
    this.location = '未设置',
    this.phone = '',
    this.email = '',
    this.coverImageBytes,
  });

  final String? displayName;
  final String bio;
  final String gender;
  final String birthday;
  final String location;
  final String phone;
  final String email;
  final Uint8List? coverImageBytes;

  PersonalProfileData copyWith({
    String? displayName,
    String? bio,
    String? gender,
    String? birthday,
    String? location,
    String? phone,
    String? email,
    Uint8List? coverImageBytes,
    bool clearCoverImage = false,
  }) {
    return PersonalProfileData(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      coverImageBytes:
          clearCoverImage ? null : coverImageBytes ?? this.coverImageBytes,
    );
  }
}

final personalProfileProvider = StateProvider<PersonalProfileData>((ref) {
  return const PersonalProfileData();
});
