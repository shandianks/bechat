import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../providers/providers.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  List<String> _memberIds = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final repo = ref.read(groupProvider);
    final members = await repo.getGroupMembers(widget.groupId);
    if (mounted) {
      setState(() {
        _memberIds = members;
        _loadingMembers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider).getGroupById(widget.groupId);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwner = group?.creatorId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('群信息'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // 群头像 + 名称
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: group?.portrait != null
                      ? NetworkImage(group!.portrait!)
                      : null,
                  child: group?.portrait == null
                      ? const Icon(Icons.groups, size: 40)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  group?.name ?? '群组',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (group?.introduction != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    group!.introduction!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 统计信息
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('成员', group?.memberCount ?? _memberIds.length),
                Container(width: 1, height: 32, color: AppColors.divider),
                _buildStat('群号', widget.groupId.substring(0, 8)),
                Container(width: 1, height: 32, color: AppColors.divider),
                _buildStat('群类型', isOwner ? '我是群主' : '普通群'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 成员列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '群成员',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isOwner)
                  TextButton.icon(
                    onPressed: () {
                      // TODO: 添加成员
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('添加'),
                  ),
              ],
            ),
          ),
          if (_loadingMembers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...List.generate(_memberIds.length, (i) {
              final memberId = _memberIds[i];
              final isGroupOwner = memberId == group?.creatorId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://api.dicebear.com/7.x/avataaars/svg?seed=$memberId',
                  ),
                ),
                title: Text('用户 ${memberId.substring(0, 6)}'),
                subtitle: isGroupOwner ? const Text('群主', style: TextStyle(color: AppColors.primary)) : null,
                trailing: isOwner && !isGroupOwner
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('确定移除该成员？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(groupProvider).removeMembers(
                              groupId: widget.groupId,
                              memberIds: [memberId],
                            );
                            _loadMembers();
                          }
                        },
                      )
                    : null,
              );
            }),
          const SizedBox(height: 32),
          // 操作按钮
          if (isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () {
                  // TODO: 解散群
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('解散群功能开发中...')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('解散群'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确定退出群聊？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    // TODO: 退出群
                    if (context.mounted) context.pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('退出群聊'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStat(String label, dynamic value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
