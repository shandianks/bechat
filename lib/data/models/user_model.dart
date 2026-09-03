import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nickname;

  @HiveField(2)
  final String? portrait;

  @HiveField(3)
  final String? phone;

  @HiveField(4)
  final int? gender; // 0未知 1男 2女

  @HiveField(5)
  final int? birthday;

  @HiveField(6)
  final String? region;

  @HiveField(7)
  final String? signature;

  @HiveField(8)
  final int? createTime;

  const UserModel({
    required this.id,
    required this.nickname,
    this.portrait,
    this.phone,
    this.gender,
    this.birthday,
    this.region,
    this.signature,
    this.createTime,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['userId'] ?? '',
      nickname: json['nickname'] ?? json['name'] ?? '未知用户',
      portrait: json['portrait'] ?? json['avatar'],
      phone: json['phone'],
      gender: json['gender'],
      birthday: json['birthday'],
      region: json['region'],
      signature: json['signature'],
      createTime: json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'portrait': portrait,
      'phone': phone,
      'gender': gender,
      'birthday': birthday,
      'region': region,
      'signature': signature,
      'createTime': createTime,
    };
  }

  UserModel copyWith({
    String? id,
    String? nickname,
    String? portrait,
    String? phone,
    int? gender,
    int? birthday,
    String? region,
    String? signature,
    int? createTime,
  }) {
    return UserModel(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      portrait: portrait ?? this.portrait,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      region: region ?? this.region,
      signature: signature ?? this.signature,
      createTime: createTime ?? this.createTime,
    );
  }

  @override
  List<Object?> get props => [id, nickname, portrait, phone, gender, birthday, region, signature, createTime];
}
