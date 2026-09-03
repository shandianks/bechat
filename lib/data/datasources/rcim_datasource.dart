import 'dart:async';
import 'package:rongcloud_im_wrapper_flutter/rongcloud_im_wrapper_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';

/// 融云 IM 核心服务封装
/// 所有与融云 SDK 的交互都通过这里
class RCIMDatasource {
  final RCIMIWEngine _engine = RCIMIWEngine.create();
  bool _isConnected = false;
  String? _currentUserId;

  // Stream 控制器
  final _messageStreamController = StreamController<MessageModel>.broadcast();
  final _connectionStatusController = StreamController<int>.broadcast();
  final _conversationListController = StreamController<List<RCIMIWConversation>>.broadcast();

  // Stream Getters
  Stream<MessageModel> get onMessageReceived => _messageStreamController.stream;
  Stream<int> get onConnectionStatusChanged => _connectionStatusController.stream;
  Stream<List<RCIMIWConversation>> get onConversationListChanged => _conversationListController.stream;

  String? get currentUserId => _currentUserId;
  bool get isConnected => _isConnected;

  /// 初始化 SDK
  Future<void> init() async {
    await _engine.init(AppConstants.rongCloudAppKey, options: RCIMIWEngineOptions());
    await _setListener();
  }

  /// 设置事件监听
  Future<void> _setListener() async {
    // 连接状态监听
    _engine.setConnectionStatusListener((code) {
      _isConnected = (code == RCIMIWConnectionStatus.connected);
      _connectionStatusController.add(code);
      return null;
    });

    // 消息监听
    _engine.setOnMessageReceivedListener((message, leftN, offline, hasBatch) {
      final model = _convertMessage(message);
      if (model != null) {
        _messageStreamController.add(model);
      }
      return null;
    });

    // 会话列表监听
    _engine.setConversationListStatusChangedListener((status, code) {
      if (status == 0) {
        _loadConversationListInternal();
      }
      return null;
    });
  }

  /// 连接服务器（登录融云）
  Future<int> connect({
    required String userId,
    required String token,
  }) async {
    final code = await _engine.connect(token, userId: userId);
    if (code == RCIMIWErrorCode.success) {
      _isConnected = true;
      _currentUserId = userId;
      await _loadConversationListInternal();
    }
    return code;
  }

  /// 断开连接
  Future<void> disconnect({bool receivePush = true}) async {
    await _engine.disconnect(receivePush);
    _isConnected = false;
    _currentUserId = null;
  }

  /// 发送文字消息
  Future<MessageModel?> sendTextMessage({
    required int conversationType,
    required String targetId,
    required String content,
    String? senderName,
  }) async {
    final textMessage = RCIMIWTextMessage.create(
      conversationType: conversationType,
      targetId: targetId,
      text: content,
    );

    final sentMessage = await _engine.sendMessage(
      conversationType,
      targetId,
      message: textMessage,
      params: RCSendMessageParams(),
    );

    return _convertMessage(sentMessage);
  }

  /// 发送图片消息
  Future<MessageModel?> sendImageMessage({
    required int conversationType,
    required String targetId,
    required String imagePath,
    String? senderName,
  }) async {
    final imageMessage = RCIMIWImageMessage.create(
      conversationType: conversationType,
      targetId: targetId,
      path: imagePath,
    );

    final sentMessage = await _engine.sendMessage(
      conversationType,
      targetId,
      message: imageMessage,
      params: RCSendMessageParams(),
    );

    return _convertMessage(sentMessage);
  }

  /// 获取历史消息
  Future<List<MessageModel>> getHistoryMessages({
    required int conversationType,
    required String targetId,
    int? timestamp,
    int count = 20,
  }) async {
    final messages = await _engine.getHistoryMessages(
      conversationType,
      targetId,
      timestamp: timestamp ?? -1,
      count: count,
      total: -1,
    );

    final result = <MessageModel>[];
    for (final msg in messages) {
      final model = _convertMessage(msg);
      if (model != null) result.add(model);
    }
    return result;
  }

  /// 加载会话列表
  Future<List<RCIMIWConversation>> _loadConversationListInternal() async {
    final list = await _engine.getConversationList(
      [RCIMIWConversationType.private, RCIMIWConversationType.group],
      0,
      -1,
    );
    if (list != null) {
      _conversationListController.add(list);
    }
    return list ?? [];
  }

  Future<void> loadConversationList() async {
    await _loadConversationListInternal();
  }

  /// 设置消息已读
  Future<void> markMessageAsRead({
    required int conversationType,
    required String targetId,
  }) async {
    await _engine.markMessageAsRead(conversationType, targetId, -1);
  }

  /// 创建群组
  Future<int> createGroup({
    required String groupId,
    required String groupName,
    List<String>? memberIds,
  }) async {
    final code = await _engine.createGroup(
      RCIMIWGroupOptions()
        ..name = groupName
        ..memberIds = memberIds ?? [],
      groupId,
    );
    return code;
  }

  /// 拉人入群
  Future<int> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    return await _engine.addGroupMembers(groupId, memberIds);
  }

  /// 退出群组
  Future<int> removeGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    return await _engine.removeGroupMembers(groupId, memberIds);
  }

  /// 获取群成员
  Future<List<String>> getGroupMembers({
    required String groupId,
  }) async {
    final members = await _engine.getGroupMembers(groupId);
    return members ?? [];
  }

  /// 撤回消息
  Future<int> recallMessage(String messageId) async {
    return await _engine.recallMessage(messageId);
  }

  /// 将 RCIMIWMessage 转换为 MessageModel
  MessageModel? _convertMessage(RCIMIWMessage? msg) {
    if (msg == null) return null;
    String content = '';
    String messageType = msg.objectName ?? 'RC:TxtMsg';

    if (msg is RCIMIWTextMessage) {
      content = msg.text ?? '';
      messageType = 'RC:TxtMsg';
    } else if (msg is RCIMIWImageMessage) {
      content = msg.remoteUrl ?? '';
      messageType = 'RC:ImgMsg';
    } else if (msg is RCIMIWVoiceMessage) {
      content = '${msg.duration}s';
      messageType = 'RC:VcMsg';
    }

    return MessageModel(
      messageId: msg.messageId?.toString() ?? '',
      senderId: msg.senderUserId ?? '',
      senderName: msg.senderUserName ?? '',
      senderPortrait: msg.senderPortraitUrl,
      targetId: msg.targetId ?? '',
      conversationType: msg.conversationType ?? 1,
      content: content,
      messageType: messageType,
      sentStatus: msg.sentStatus == RCSentStatus.sent ? 1 : 0,
      timestamp: msg.sentTime?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      extra: msg.extra,
    );
  }

  void dispose() {
    _messageStreamController.close();
    _connectionStatusController.close();
    _conversationListController.close();
    _engine.destroy();
  }
}

// Provider
final rcimDatasourceProvider = Provider<RCIMDatasource>((ref) {
  final ds = RCIMDatasource();
  ref.onDispose(() => ds.dispose());
  return ds;
});
