import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/local_datasource.dart';
import '../datasources/rcim_datasource.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import 'auth_repository.dart';

/// 聊天服务
class ChatRepository {
  final LocalDatasource _local;
  final RCIMDatasource _rcim;
  final AuthRepository _auth;

  final _messageController = StreamController<
      ({int conversationType, String targetId, List<MessageModel> messages})>.broadcast();
  StreamSubscription? _rcimSubscription;

  /// 缓存当前会话的消息列表
  final Map<String, List<MessageModel>> _messageCache = {};

  ChatRepository(this._local, this._rcim, this._auth) {
    _subscribeToRCIM();
  }

  void _subscribeToRCIM() {
    _rcimSubscription = _rcim.onMessageReceived.listen((message) async {
      await _local.saveMessage(message);
      // 会话摘要/未读统一走本地事件源（ConversationRepository 订阅后自动刷新）
      await _local.onIncomingMessage(
        conversationType: message.conversationType,
        targetId: message.targetId,
        content: message.summaryContent,
        timestamp: message.timestamp,
        // 单聊首会话时用发送者信息兜底标题/头像
        title: message.conversationType == 1 ? message.senderName : null,
        portrait: message.conversationType == 1 ? message.senderPortrait : null,
      );

      // 同步插入内存缓存（仅当该会话已加载过，避免污染未打开会话的缓存）
      final key = _cacheKey(message.conversationType, message.targetId);
      final list = _messageCache[key];
      if (list != null) {
        final exists = list.any((m) => m.messageId == message.messageId);
        if (!exists) {
          list.add(message);
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }

      _notifyMessageUpdate(message.conversationType, message.targetId);
    });
  }

  /// 加载消息历史
  Future<List<MessageModel>> loadMessages({
    required int conversationType,
    required String targetId,
    String? beforeMessageId,
  }) async {
    final key = _cacheKey(conversationType, targetId);

    // 先从本地加载
    final localMessages = _local.getMessages(
      conversationType: conversationType,
      targetId: targetId,
    );

    // 如果本地消息足够（>=10条），直接返回
    if (localMessages.length >= 10) {
      return _mergeIntoCache(key, localMessages);
    }

    // 从融云拉取历史
    int? beforeTimestamp;
    if (beforeMessageId != null) {
      final msg = localMessages.firstWhere(
        (m) => m.messageId == beforeMessageId,
        orElse: () => localMessages.first,
      );
      beforeTimestamp = msg.timestamp;
    }

    try {
      final remoteMessages = await _rcim.getHistoryMessages(
        conversationType: conversationType,
        targetId: targetId,
        timestamp: beforeTimestamp,
      );

      // 合并去重
      final all = <String, MessageModel>{};
      for (final m in remoteMessages) {
        all[m.messageId] = m;
      }
      for (final m in localMessages) {
        all[m.messageId] = m;
      }

      final merged = all.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      await _local.saveMessages(merged);
      return _mergeIntoCache(key, merged);
    } catch (e) {
      // 融云连接失败时返回本地
      return _mergeIntoCache(key, localMessages);
    }
  }

  /// 将新数据合并进内存缓存（不整体覆盖，避免并发时吞掉刚发的新消息）
  /// 返回合并后的完整列表
  List<MessageModel> _mergeIntoCache(String key, List<MessageModel> incoming) {
    final merged = <String, MessageModel>{};
    for (final m in _messageCache[key] ?? <MessageModel>[]) {
      merged[m.messageId] = m;
    }
    for (final m in incoming) {
      merged[m.messageId] = m;
    }
    final sorted = merged.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _messageCache[key] = sorted;
    return sorted;
  }

  /// 发送消息
  Future<MessageModel> sendMessage({
    required int conversationType,
    required String targetId,
    required String content,
  }) async {
    final currentUser = _auth.currentUser;

    // 先构建本地消息（乐观显示）
    final localMsg = MessageModel(
      messageId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? '',
      senderName: currentUser?.nickname ?? '我',
      senderPortrait: currentUser?.portrait,
      targetId: targetId,
      conversationType: conversationType,
      content: content,
      messageType: 'RC:TxtMsg',
      sentStatus: 0, // 发送中
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // 添加到本地缓存（乐观更新）
    final key = _cacheKey(conversationType, targetId);
    final list = _messageCache[key] ?? [];
    _messageCache[key] = [localMsg, ...list];
    _notifyMessageUpdate(conversationType, targetId);

    try {
      // 发送到融云
      final sentMsg = await _rcim.sendTextMessage(
        conversationType: conversationType,
        targetId: targetId,
        content: content,
        senderName: currentUser?.nickname ?? '我',
      );

      if (sentMsg != null) {
        // 更新本地消息状态
        await _local.saveMessage(sentMsg);
        await _local.updateConversationLastMessage(
          conversationType: conversationType,
          targetId: targetId,
          content: content,
          timestamp: sentMsg.timestamp,
        );

        // 更新缓存中的消息（不存在则插入头部，防止被并发加载覆盖）
        _replaceOrInsert(key, localMsg, sentMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        // 发送失败
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _replaceOrInsert(key, localMsg, failedMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      // 发送失败
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      _replaceOrInsert(key, localMsg, failedMsg);
      _notifyMessageUpdate(conversationType, targetId);
      return failedMsg;
    }
  }

  /// 发送图片消息
  Future<MessageModel> sendImageMessage({
    required int conversationType,
    required String targetId,
    required String imagePath,
  }) async {
    final currentUser = _auth.currentUser;

    // 先构建本地消息（乐观显示）
    final localMsg = MessageModel(
      messageId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? '',
      senderName: currentUser?.nickname ?? '我',
      senderPortrait: currentUser?.portrait,
      targetId: targetId,
      conversationType: conversationType,
      content: imagePath, // 本地路径，MessageBubble 会优先显示本地图片
      messageType: 'RC:ImgMsg',
      sentStatus: 0, // 发送中
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // 添加到本地缓存（乐观更新）
    final key = _cacheKey(conversationType, targetId);
    final list = _messageCache[key] ?? [];
    _messageCache[key] = [localMsg, ...list];
    _notifyMessageUpdate(conversationType, targetId);

    try {
      // 发送到融云
      final sentMsg = await _rcim.sendImageMessage(
        conversationType: conversationType,
        targetId: targetId,
        imagePath: imagePath,
        senderName: currentUser?.nickname ?? '我',
      );

      if (sentMsg != null) {
        await _local.saveMessage(sentMsg);
        await _local.updateConversationLastMessage(
          conversationType: conversationType,
          targetId: targetId,
          content: '[图片]',
          timestamp: sentMsg.timestamp,
        );

        // 更新缓存中的消息（不存在则插入头部，防止被并发加载覆盖）
        _replaceOrInsert(key, localMsg, sentMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _replaceOrInsert(key, localMsg, failedMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      _replaceOrInsert(key, localMsg, failedMsg);
      _notifyMessageUpdate(conversationType, targetId);
      return failedMsg;
    }
  }

  /// 发送语音消息
  Future<MessageModel> sendVoiceMessage({
    required int conversationType,
    required String targetId,
    required String voicePath,
    required int durationSeconds,
  }) async {
    final currentUser = _auth.currentUser;

    // 本地消息（乐观显示：本地路径可立即播放预览）
    final localMsg = MessageModel(
      messageId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? '',
      senderName: currentUser?.nickname ?? '我',
      senderPortrait: currentUser?.portrait,
      targetId: targetId,
      conversationType: conversationType,
      content: voicePath,
      messageType: 'RC:VcMsg',
      sentStatus: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      extra: jsonEncode({'duration': durationSeconds}),
    );

    final key = _cacheKey(conversationType, targetId);
    final list = _messageCache[key] ?? [];
    _messageCache[key] = [localMsg, ...list];
    _notifyMessageUpdate(conversationType, targetId);

    try {
      final sentMsg = await _rcim.sendVoiceMessage(
        conversationType: conversationType,
        targetId: targetId,
        voicePath: voicePath,
        durationSeconds: durationSeconds,
        senderName: currentUser?.nickname ?? '我',
      );

      if (sentMsg != null) {
        await _local.saveMessage(sentMsg);
        await _local.updateConversationLastMessage(
          conversationType: conversationType,
          targetId: targetId,
          content: '[语音]',
          timestamp: sentMsg.timestamp,
        );

        _replaceOrInsert(key, localMsg, sentMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _replaceOrInsert(key, localMsg, failedMsg);
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      _replaceOrInsert(key, localMsg, failedMsg);
      _notifyMessageUpdate(conversationType, targetId);
      return failedMsg;
    }
  }

  /// 获取当前消息列表（从缓存）
  List<MessageModel> getCurrentMessages(int conversationType, String targetId) {
    return _messageCache[_cacheKey(conversationType, targetId)] ?? [];
  }

  /// 撤回消息（融云 + 本地同步移除）
  /// 返回 true 表示撤回成功
  Future<bool> recallMessage({
    required int conversationType,
    required String targetId,
    required String messageId,
  }) async {
    final code = await _rcim.recallMessage(messageId);
    if (code != 0) return false;

    await _removeMessageLocal(
      conversationType: conversationType,
      targetId: targetId,
      messageId: messageId,
    );

    // 会话摘要回退到上一条（无则置占位文案），对齐主流 IM 行为
    final rest = _local.getMessages(
      conversationType: conversationType,
      targetId: targetId,
      limit: 1,
    );
    if (rest.isNotEmpty) {
      await _local.updateConversationLastMessage(
        conversationType: conversationType,
        targetId: targetId,
        content: rest.first.summaryContent,
        timestamp: rest.first.timestamp,
      );
    } else {
      await _local.updateConversationLastMessage(
        conversationType: conversationType,
        targetId: targetId,
        content: '[消息已撤回]',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return true;
  }

  /// 本地删除消息（仅本端生效）
  Future<void> deleteMessage({
    required int conversationType,
    required String targetId,
    required String messageId,
  }) async {
    await _removeMessageLocal(
      conversationType: conversationType,
      targetId: targetId,
      messageId: messageId,
    );
  }

  /// 从内存缓存 + Hive 移除单条消息并通知刷新
  Future<void> _removeMessageLocal({
    required int conversationType,
    required String targetId,
    required String messageId,
  }) async {
    final key = _cacheKey(conversationType, targetId);
    final list = _messageCache[key];
    if (list != null) {
      list.removeWhere((m) => m.messageId == messageId);
    }
    await _local.deleteMessage(
      conversationType: conversationType,
      targetId: targetId,
      messageId: messageId,
    );
    _notifyMessageUpdate(conversationType, targetId);
  }

  /// 定位乐观消息并替换；若缓存已被并发加载覆盖（找不到），则插入头部
  void _replaceOrInsert(String key, MessageModel localMsg, MessageModel newMsg) {
    final list = _messageCache[key];
    if (list == null) {
      _messageCache[key] = [newMsg];
      return;
    }
    final idx = list.indexWhere((m) => m.messageId == localMsg.messageId);
    if (idx >= 0) {
      list[idx] = newMsg;
    } else {
      list.insert(0, newMsg);
    }
  }

  /// 标记消息已读
  Future<void> markAsRead({
    required int conversationType,
    required String targetId,
  }) async {
    await _rcim.markMessageAsRead(
      conversationType: conversationType,
      targetId: targetId,
    );
    await _local.clearUnreadCount(
      conversationType: conversationType,
      targetId: targetId,
    );
  }

  String _cacheKey(int conversationType, String targetId) => '${conversationType}_$targetId';

  void _notifyMessageUpdate(int conversationType, String targetId) {
    _messageController.add((
      conversationType: conversationType,
      targetId: targetId,
      messages: getCurrentMessages(conversationType, targetId),
    ));
  }

  /// 按会话过滤的消息流（删除/撤回致列表为空时也能正确推送）
  Stream<List<MessageModel>> messageStream(int conversationType, String targetId) {
    return _messageController.stream
        .where((e) =>
            e.conversationType == conversationType && e.targetId == targetId)
        .map((e) => e.messages);
  }

  void dispose() {
    _rcimSubscription?.cancel();
    _messageController.close();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
    ref.read(authRepositoryProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});
