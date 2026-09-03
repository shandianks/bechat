import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/group_model.dart';
import '../models/conversation_model.dart';

/// 本地存储服务（Hive）
class LocalDatasource {
  late Box<UserModel> _userBox;
  late Box<MessageModel> _messageBox;
  late Box<ConversationModel> _conversationBox;
  late Box<GroupModel> _groupBox;
  late Box<dynamic> _configBox;

  bool _initialized = false;

  /// 初始化 Hive，注册 TypeAdapter
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // 注册 Adapter
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(GroupModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ConversationModelAdapter());
    }

    // 打开 Box
    _userBox = await Hive.openBox<UserModel>(AppConstants.hiveBoxUser);
    _messageBox = await Hive.openBox<MessageModel>(AppConstants.hiveBoxMessage);
    _conversationBox = await Hive.openBox<ConversationModel>(AppConstants.hiveBoxConversation);
    _groupBox = await Hive.openBox<GroupModel>('group_box');
    _configBox = await Hive.openBox<dynamic>('config_box');

    _initialized = true;
  }

  // ============ 用户相关 ============

  /// 保存当前登录用户
  Future<void> saveCurrentUser(UserModel user) async {
    await _userBox.put('current', user);
    await _configBox.put(AppConstants.currentUserIdKey, user.id);
  }

  /// 获取当前登录用户
  UserModel? getCurrentUser() {
    return _userBox.get('current');
  }

  /// 获取当前用户ID
  String? getCurrentUserId() {
    return _configBox.get(AppConstants.currentUserIdKey);
  }

  /// 缓存用户信息
  Future<void> cacheUser(UserModel user) async {
    await _userBox.put(user.id, user);
  }

  /// 批量缓存用户
  Future<void> cacheUsers(List<UserModel> users) async {
    final map = {for (var u in users) u.id: u};
    await _userBox.putAll(map);
  }

  /// 根据ID获取用户
  UserModel? getUserById(String id) {
    return _userBox.get(id);
  }

  /// 保存好友列表
  Future<void> saveContacts(List<UserModel> contacts) async {
    await _configBox.put('contacts', contacts.map((u) => u.toJson()).toList());
  }

  /// 获取好友列表
  List<UserModel> getContacts() {
    final raw = _configBox.get('contacts');
    if (raw == null) return [];
    return (raw as List).map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// 清除登录状态
  Future<void> clearLoginState() async {
    await _userBox.delete('current');
    await _configBox.delete(AppConstants.currentUserIdKey);
    await _configBox.delete(AppConstants.currentUserTokenKey);
  }

  // ============ 消息相关 ============

  /// 保存消息到本地
  Future<void> saveMessage(MessageModel message) async {
    final key = _messageKey(message.conversationType, message.targetId, message.messageId);
    await _messageBox.put(key, message);
  }

  /// 批量保存消息
  Future<void> saveMessages(List<MessageModel> messages) async {
    final map = <String, MessageModel>{};
    for (final msg in messages) {
      final key = _messageKey(msg.conversationType, msg.targetId, msg.messageId);
      map[key] = msg;
    }
    await _messageBox.putAll(map);
  }

  /// 获取某会话的消息列表
  List<MessageModel> getMessages({
    required int conversationType,
    required String targetId,
    int? beforeTimestamp,
    int limit = 20,
  }) {
    final prefix = '${conversationType}_${targetId}_';
    final all = _messageBox.values
        .where((m) => m.targetId == targetId && m.conversationType == conversationType)
        .where((m) => beforeTimestamp == null || m.timestamp < beforeTimestamp)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return all.take(limit).toList();
  }

  String _messageKey(int conversationType, String targetId, String messageId) {
    return '${conversationType}_${targetId}_$messageId';
  }

  /// 删除某会话所有消息
  Future<void> deleteMessagesForConversation(int conversationType, String targetId) async {
    final keys = _messageBox.keys
        .where((k) => k.toString().startsWith('${conversationType}_${targetId}_'))
        .toList();
    await _messageBox.deleteAll(keys);
  }

  // ============ 会话相关 ============

  /// 保存会话列表
  Future<void> saveConversation(ConversationModel conv) async {
    await _conversationBox.put(conv.conversationKey, conv);
  }

  /// 更新会话最后消息
  Future<void> updateConversationLastMessage({
    required int conversationType,
    required String targetId,
    required String content,
    required int timestamp,
  }) async {
    final key = '${conversationType}_$targetId';
    final existing = _conversationBox.get(key);
    if (existing != null) {
      await _conversationBox.put(
        key,
        existing.copyWith(
          lastMessageContent: content,
          lastMessageTime: timestamp,
        ),
      );
    }
  }

  /// 获取会话列表（按最后消息时间倒序）
  List<ConversationModel> getConversationList() {
    final list = _conversationBox.values.toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return list;
  }

  /// 获取某个会话
  ConversationModel? getConversation({
    required int conversationType,
    required String targetId,
  }) {
    return _conversationBox.get('${conversationType}_$targetId');
  }

  /// 清除会话未读数
  Future<void> clearUnreadCount({
    required int conversationType,
    required String targetId,
  }) async {
    final key = '${conversationType}_$targetId';
    final existing = _conversationBox.get(key);
    if (existing != null) {
      await _conversationBox.put(key, existing.copyWith(unreadCount: 0));
    }
  }

  /// 获取总未读数
  int getTotalUnreadCount() {
    return _conversationBox.values.fold(0, (sum, c) => sum + c.unreadCount);
  }

  // ============ 群组相关 ============

  /// 保存群组信息
  Future<void> saveGroup(GroupModel group) async {
    await _groupBox.put(group.id, group);
  }

  /// 批量保存群组
  Future<void> saveGroups(List<GroupModel> groups) async {
    final map = {for (var g in groups) g.id: g};
    await _groupBox.putAll(map);
  }

  /// 获取群组
  GroupModel? getGroupById(String id) {
    return _groupBox.get(id);
  }

  /// 获取我加入的群组列表
  List<GroupModel> getMyGroups() {
    return _groupBox.values.toList();
  }
}

// Provider
final localDatasourceProvider = Provider<LocalDatasource>((ref) {
  return LocalDatasource();
});
