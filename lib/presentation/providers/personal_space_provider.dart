import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalSpaceData {
  const PersonalSpaceData({
    required this.signature,
    required this.channels,
  });

  final String signature;
  final List<MyChannel> channels;
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
