import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _selectedMembers = <String>[];
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = '请输入群名称');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final repo = ref.read(groupProvider);
      final group = await repo.createGroup(
        name: _nameController.text.trim(),
        introduction: _descController.text.trim(),
        memberIds: _selectedMembers,
      );

      if (mounted) {
        // 跳转到群聊
        context.pushReplacement(
          '/chat/group/${group.id}?title=${Uri.encodeComponent(group.name)}',
        );
      }
    } catch (e) {
      setState(() {
        _error = '创建失败: $e';
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 群名称
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '群名称',
              hintText: '给群起个名字',
              errorText: _error,
              prefixIcon: const Icon(Icons.groups),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          // 群简介
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '群简介（选填）',
              hintText: '介绍这个群是做什么的',
              prefixIcon: Icon(Icons.info_outline),
            ),
            maxLines: 3,
            maxLength: 100,
          ),
          const SizedBox(height: 24),
          // 选择成员
          Row(
            children: [
              const Text(
                '选择成员',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedMembers.length} 人已选',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 成员选择列表
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contacts.map((user) {
              final isSelected = _selectedMembers.contains(user.id);
              return FilterChip(
                label: Text(user.nickname),
                avatar: CircleAvatar(
                  backgroundImage: user.portrait != null
                      ? NetworkImage(user.portrait!)
                      : null,
                  child: user.portrait == null
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedMembers.add(user.id);
                    } else {
                      _selectedMembers.remove(user.id);
                    }
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '创建后可以随时拉人入群或踢人',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
