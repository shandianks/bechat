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

  final _messageController = StreamController<List<MessageModel>>.broadcast();
  StreamSubscription? _rcimSubscription;

  /// 缓存当前会话的消息列表
  final Map<String, List<MessageModel>> _messageCache = {};

  ChatRepository(this._local, this._rcim, this._auth) {
    _subscribeToRCIM();
  }

  void _subscribeToRCIM() {
    _rcimSubscription = _rcim.onMessageReceived.listen((message) async {
      await _local.saveMessage(message);
      await _local.updateConversationLastMessage(
        conversationType: message.conversationType,
        targetId: message.targetId,
        content: message.content,
        timestamp: message.timestamp,
      );
      _notifyMessageUpdate(message.conversationType, message.targetId);
    });
  }

  /// 加载消息历史
  Future<List<MessageModel>> loadMessages({
    required int conversationType,
    required String targetId,
    String? beforeMessageId,
  }) async {
    // 先从本地加载
    final localMessages = _local.getMessages(
      conversationType: conversationType,
      targetId: targetId,
    );

    // 如果本地消息足够（>=10条），直接返回
    if (localMessages.length >= 10) {
      _messageCache[_cacheKey(conversationType, targetId)] = localMessages;
      return localMessages;
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
      _messageCache[_cacheKey(conversationType, targetId)] = merged;
      return merged;
    } catch (e) {
      // 融云连接失败时返回本地
      _messageCache[_cacheKey(conversationType, targetId)] = localMessages;
      return localMessages;
    }
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

        // 更新缓存中的消息
        final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
        if (idx != null && idx >= 0) {
          _messageCache[key]![idx] = sentMsg;
        }
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        // 发送失败
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _messageCache[key]![_messageCache[key]!.indexWhere((m) => m.messageId == localMsg.messageId)] = failedMsg;
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      // 发送失败
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
      if (idx != null && idx >= 0) {
        _messageCache[key]![idx] = failedMsg;
      }
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

        // 更新缓存中的消息
        final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
        if (idx != null && idx >= 0) {
          _messageCache[key]![idx] = sentMsg;
        }
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _messageCache[key]![_messageCache[key]!.indexWhere((m) => m.messageId == localMsg.messageId)] = failedMsg;
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
      if (idx != null && idx >= 0) {
        _messageCache[key]![idx] = failedMsg;
      }
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

        final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
        if (idx != null && idx >= 0) {
          _messageCache[key]![idx] = sentMsg;
        }
        _notifyMessageUpdate(conversationType, targetId);
        return sentMsg;
      } else {
        final failedMsg = localMsg.copyWith(sentStatus: 2);
        _messageCache[key]![_messageCache[key]!.indexWhere((m) => m.messageId == localMsg.messageId)] = failedMsg;
        _notifyMessageUpdate(conversationType, targetId);
        return failedMsg;
      }
    } catch (e) {
      final failedMsg = localMsg.copyWith(sentStatus: 2);
      final idx = _messageCache[key]?.indexWhere((m) => m.messageId == localMsg.messageId);
      if (idx != null && idx >= 0) {
        _messageCache[key]![idx] = failedMsg;
      }
      _notifyMessageUpdate(conversationType, targetId);
      return failedMsg;
    }
  }

  /// 获取当前消息列表（从缓存）
  List<MessageModel> getCurrentMessages(int conversationType, String targetId) {
    return _messageCache[_cacheKey(conversationType, targetId)] ?? [];
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
    _messageController.add(getCurrentMessages(conversationType, targetId));
  }

  Stream<List<MessageModel>> messageStream(int conversationType, String targetId) {
    return _messageController.stream
        .where((msgs) => msgs.isNotEmpty && msgs.first.targetId == targetId && msgs.first.conversationType == conversationType);
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
