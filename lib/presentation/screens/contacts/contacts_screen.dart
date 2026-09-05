import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local_datasource.dart';
import '../../../data/models/user_model.dart';
import '../../providers/providers.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final groups = ref.watch(myGroupsProvider);

    final filtered = contacts.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.nickname.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddContact(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // 列表
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          '没有找到联系人',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      // 群组列表
                      groups.when(
                        data: (groupList) {
                          if (groupList.isEmpty) return const SizedBox.shrink();
                          return _buildSection(
                            '我的群组',
                            groupList.map((g) => _ContactItem(
                              id: g.id,
                              name: g.name,
                              portrait: g.portrait,
                              type: _ContactType.group,
                              subtitle: '${g.memberCount} 人',
                            )).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      // 联系人列表
                      _buildSection(
                        '联系人',
                        filtered.map((u) => _ContactItem(
                          id: u.id,
                          name: u.nickname,
                          portrait: u.portrait,
                          type: _ContactType.user,
                          subtitle: u.signature,
                        )).toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_ContactItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...items.map((item) => _buildContactTile(item)),
        const Divider(height: 1, indent: 72),
      ],
    );
  }

  Widget _buildContactTile(_ContactItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: item.portrait != null ? NetworkImage(item.portrait!) : null,
        child: item.portrait == null
            ? Icon(
                item.type == _ContactType.group ? Icons.groups : Icons.person,
                color: AppColors.textHint,
              )
            : null,
      ),
      title: Text(
        item.name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: item.subtitle != null
          ? Text(
              item.subtitle!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: () {
        if (item.type == _ContactType.group) {
          context.push('/chat/group/${item.id}?title=${Uri.encodeComponent(item.name)}');
        } else {
          context.push('/chat/private/${item.id}?title=${Uri.encodeComponent(item.name)}');
        }
      },
    );
  }

  void _showAddContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.primary),
              title: const Text('添加联系人'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddContactDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: AppColors.primary),
              title: const Text('创建群聊'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/group/create');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 添加联系人弹窗：输入对方融云用户 ID + 昵称，持久化到本地通讯录
  Future<void> _showAddContactDialog(BuildContext context) async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加联系人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '用户 ID',
                hintText: '对方的融云用户 ID',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                hintText: '备注名称',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    final id = idController.text.trim();
    final name = nameController.text.trim();
    if (confirmed != true || id.isEmpty || name.isEmpty || !mounted) return;

    try {
      final local = ref.read(localDatasourceProvider);
      final contacts = [...local.getContacts()];
      contacts.removeWhere((u) => u.id == id);
      contacts.add(
        UserModel(id: id, nickname: name, signature: '手动添加'),
      );
      await local.saveContacts(contacts);
      // 本地数据源是普通 Provider，不会自动通知 → 手动失效触发刷新
      ref.invalidate(contactsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已添加联系人'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('添加失败: $e')),
      );
    }
  }
}

enum _ContactType { user, group }

class _ContactItem {
  final String id;
  final String name;
  final String? portrait;
  final _ContactType type;
  final String? subtitle;

  _ContactItem({
    required this.id,
    required this.name,
    this.portrait,
    required this.type,
    this.subtitle,
  });
}
