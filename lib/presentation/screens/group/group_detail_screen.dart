import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 群聊详情页（暂用）
class GroupDetailScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/group/$groupId/info'),
          ),
        ],
      ),
      body: const Center(
        child: Text('群聊详情页面'),
      ),
    );
  }
}
