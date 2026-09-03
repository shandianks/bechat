import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../datasources/local_datasource.dart';
import '../datasources/rcim_datasource.dart';
import '../models/group_model.dart';
import 'auth_repository.dart';

/// 群组服务
class GroupRepository {
  final LocalDatasource _local;
  final RCIMDatasource _rcim;
  final AuthRepository _auth;

  GroupRepository(this._local, this._rcim, this._auth);

  /// 创建群组
  Future<GroupModel> createGroup({
    required String name,
    String? portrait,
    String? introduction,
    List<String>? memberIds,
  }) async {
    final groupId = const Uuid().v4();
    final creatorId = _auth.currentUserId ?? '';

    // 创建群（通过融云）
    final code = await _rcim.createGroup(
      groupId: groupId,
      groupName: name,
      memberIds: memberIds,
    );

    if (code != 0 && code != 20601) {
      // code=20601 表示群已存在（Demo 环境可能遇到）
      throw Exception('创建群组失败，错误码: $code');
    }

    // 构建群组对象
    final members = [...?memberIds, creatorId];
    final group = GroupModel(
      id: groupId,
      name: name,
      portrait: portrait,
      introduction: introduction,
      creatorId: creatorId,
      memberCount: members.length,
      createTime: DateTime.now().millisecondsSinceEpoch,
      memberIds: members.toSet().toList(),
    );

    // 保存到本地
    await _local.saveGroup(group);
    return group;
  }

  /// 拉人入群
  Future<void> addMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    await _rcim.addGroupMembers(
      groupId: groupId,
      memberIds: memberIds,
    );

    // 更新本地群信息
    final group = _local.getGroupById(groupId);
    if (group != null) {
      final newMembers = {...group.memberIds, ...memberIds}.toList();
      await _local.saveGroup(group.copyWith(
        memberIds: newMembers,
        memberCount: newMembers.length,
      ));
    }
  }

  /// 踢人出群
  Future<void> removeMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    await _rcim.removeGroupMembers(
      groupId: groupId,
      memberIds: memberIds,
    );

    final group = _local.getGroupById(groupId);
    if (group != null) {
      final newMembers = group.memberIds.where((id) => !memberIds.contains(id)).toList();
      await _local.saveGroup(group.copyWith(
        memberIds: newMembers,
        memberCount: newMembers.length,
      ));
    }
  }

  /// 获取群信息
  GroupModel? getGroupById(String groupId) {
    return _local.getGroupById(groupId);
  }

  /// 获取我加入的群列表
  List<GroupModel> getMyGroups() {
    return _local.getMyGroups();
  }

  /// 获取群成员
  Future<List<String>> getGroupMembers(String groupId) async {
    return await _rcim.getGroupMembers(groupId: groupId);
  }

  /// 我是否是群主
  bool isGroupOwner(String groupId) {
    final group = _local.getGroupById(groupId);
    return group?.creatorId == _auth.currentUserId;
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
    ref.read(authRepositoryProvider),
  );
});
