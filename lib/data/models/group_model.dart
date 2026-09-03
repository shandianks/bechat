import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'user_model.dart';

part 'group_model.g.dart';

@HiveType(typeId: 2)
class GroupModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? portrait;

  @HiveField(3)
  final String? introduction;

  @HiveField(4)
  final String creatorId;

  @HiveField(5)
  final int memberCount;

  @HiveField(6)
  final int? maxMemberCount;

  @HiveField(7)
  final int createTime;

  @HiveField(8)
  final List<String> memberIds; // 成员ID列表

  const GroupModel({
    required this.id,
    required this.name,
    this.portrait,
    this.introduction,
    required this.creatorId,
    this.memberCount = 0,
    this.maxMemberCount,
    required this.createTime,
    this.memberIds = const [],
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? json['groupId'] ?? json['targetId'] ?? '',
      name: json['name'] ?? json['groupName'] ?? '未命名群组',
      portrait: json['portrait'] ?? json['avatar'],
      introduction: json['introduction'],
      creatorId: json['creatorId'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      maxMemberCount: json['maxMemberCount'],
      createTime: json['createTime'] ?? DateTime.now().millisecondsSinceEpoch,
      memberIds: (json['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'portrait': portrait,
      'introduction': introduction,
      'creatorId': creatorId,
      'memberCount': memberCount,
      'maxMemberCount': maxMemberCount,
      'createTime': createTime,
      'memberIds': memberIds,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? portrait,
    String? introduction,
    String? creatorId,
    int? memberCount,
    int? maxMemberCount,
    int? createTime,
    List<String>? memberIds,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      portrait: portrait ?? this.portrait,
      introduction: introduction ?? this.introduction,
      creatorId: creatorId ?? this.creatorId,
      memberCount: memberCount ?? this.memberCount,
      maxMemberCount: maxMemberCount ?? this.maxMemberCount,
      createTime: createTime ?? this.createTime,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  @override
  List<Object?> get props => [id, name, portrait, creatorId, memberCount, createTime];
}
