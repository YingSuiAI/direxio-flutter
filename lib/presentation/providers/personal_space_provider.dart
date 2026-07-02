import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalProfileData {
  const PersonalProfileData({
    this.displayName,
    this.bio = '',
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
