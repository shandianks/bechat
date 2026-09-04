import 'package:uuid/uuid.dart';
import '../datasources/local_datasource.dart';
import '../models/group_model.dart';
import 'auth_repository.dart';

/// 群组服务
///
/// ⚠️ 2026-09-04 SDK 迁移说明：
/// 融云 rongcloud_im_plugin 5.x 客户端**没有群组管理 API**
/// （createGroup/addGroupMembers/removeMembers/getGroupMembers 均不存在，
/// 建群需服务端 REST 接口 + AppSecret）。
/// Demo 方案：群组创建/成员管理全部本地落库（Hive），成员间群消息仍走融云
/// （群 ID 需先在融云服务端/管理台创建真实群，否则群消息发送会失败）。
/// 生产环境接入服务端后，把本文件各方法的"本地实现"替换为服务端调用即可。
class GroupRepository {
  final LocalDatasource _local;
  final AuthRepository _auth;

  GroupRepository(this._local, this._auth);

  /// 创建群组（本地创建；生产：先调服务端 REST 建融云群，再落本地）
  Future<GroupModel> createGroup({
    required String name,
    String? portrait,
    String? introduction,
    List<String>? memberIds,
  }) async {
    final groupId = const Uuid().v4();
    final creatorId = _auth.currentUserId ?? '';

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

  /// 拉人入群（本地更新成员；生产：调服务端 REST 同步融云群成员）
  Future<void> addMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
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

  /// 踢人出群（本地更新成员；生产：调服务端 REST 同步融云群成员）
  Future<void> removeMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
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

  /// 获取群成员（Demo：直接读本地群资料；生产可从服务端拉真实成员列表）
  Future<List<String>> getGroupMembers(String groupId) async {
    return _local.getGroupById(groupId)?.memberIds ?? [];
  }

  /// 我是否是群主
  bool isGroupOwner(String groupId) {
    final group = _local.getGroupById(groupId);
    return group?.creatorId == _auth.currentUserId;
  }
}
