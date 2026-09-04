import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/rcim_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/models/user_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/group_model.dart';

// ============ 全局 Providers ============

/// 融云连接状态
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  kicked,
  error,
}

final connectionStatusProvider = StateProvider<ConnectionStatus>((ref) {
  return ConnectionStatus.disconnected;
});

// ============ 认证 Providers ============

final authProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
  );
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).currentUser;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});

// ============ 聊天 Providers ============

final chatProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
    ref.read(authProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// 某个会话的消息列表（自动订阅更新）
final chatMessagesProvider = StreamProvider.family<List<MessageModel>, ChatTarget>((ref, target) {
  final repo = ref.watch(chatProvider);
  return repo.messageStream(target.conversationType, target.targetId);
});

/// 加载消息历史
final loadMessagesProvider = FutureProvider.family<List<MessageModel>, ChatTarget>((ref, target) async {
  final repo = ref.read(chatProvider);
  return await repo.loadMessages(
    conversationType: target.conversationType,
    targetId: target.targetId,
  );
});

/// 发送消息
final sendMessageProvider = Provider((ref) {
  return (int conversationType, String targetId, String content) async {
    final repo = ref.read(chatProvider);
    return await repo.sendMessage(
      conversationType: conversationType,
      targetId: targetId,
      content: content,
    );
  };
});

/// 发送图片消息
final sendImageMessageProvider = Provider((ref) {
  return (int conversationType, String targetId, String imagePath) async {
    final repo = ref.read(chatProvider);
    return await repo.sendImageMessage(
      conversationType: conversationType,
      targetId: targetId,
      imagePath: imagePath,
    );
  };
});

/// 标记已读
final markAsReadProvider = Provider((ref) {
  return (int conversationType, String targetId) async {
    final repo = ref.read(chatProvider);
    await repo.markAsRead(
      conversationType: conversationType,
      targetId: targetId,
    );
  };
});

// ============ 会话列表 Providers ============

final conversationProvider = Provider<ConversationRepository>((ref) {
  final repo = ConversationRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final conversationListProvider = StreamProvider<List<ConversationModel>>((ref) {
  final repo = ref.watch(conversationProvider);
  return repo.watchConversationList();
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(conversationListProvider);
  return list.maybeWhen(
    data: (convs) => convs.fold(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
});

// ============ 群组 Providers ============

final groupProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    ref.read(localDatasourceProvider),
    ref.read(authProvider),
  );
});

final myGroupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  final repo = ref.read(groupProvider);
  return repo.getMyGroups();
});

// ============ 辅助 Providers ============

/// 联系人列表（模拟数据，Demo用）
final contactsProvider = Provider<List<UserModel>>((ref) {
  final users = ref.watch(localDatasourceProvider).getContacts();
  if (users.isEmpty) {
    // 返回模拟联系人
    return List.generate(10, (i) => UserModel(
      id: 'user_$i',
      nickname: _mockNames[i % _mockNames.length],
      portrait: 'https://api.dicebear.com/7.x/avataaars/svg?seed=user_$i',
    ));
  }
  return users;
});

final _mockNames = [
  '张三', '李四', '王五', '赵六', '钱七',
  '孙八', '周九', '吴十', '郑小明', '王小二',
];

// ============ 类型定义 ============

/// 聊天目标（用于 Provider key）
class ChatTarget {
  final int conversationType;
  final String targetId;

  const ChatTarget({
    required this.conversationType,
    required this.targetId,
  });

  @override
  bool operator ==(Object other) =>
      other is ChatTarget &&
      other.conversationType == conversationType &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(conversationType, targetId);

  String get key => '${conversationType}_$targetId';
}

// ============ 全局初始化 Provider ============

/// App 全局初始化
final appInitProvider = FutureProvider<void>((ref) async {
  // 1. 初始化本地存储
  final local = ref.read(localDatasourceProvider);
  await local.init();

  // 2. 初始化融云 SDK
  final rcim = ref.read(rcimDatasourceProvider);
  await rcim.init();

  // 3. 如果已登录，恢复 IM 连接
  final currentUserId = local.getCurrentUserId();
  if (currentUserId != null) {
    ref.read(connectionStatusProvider.notifier).state = ConnectionStatus.connecting;
    // TODO: 从本地存储获取真实 token
    // final token = await getTokenFromLocal(currentUserId);
    // await rcim.connect(userId: currentUserId, token: token);
  }
});
