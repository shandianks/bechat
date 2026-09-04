import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rongcloud_im_plugin/rongcloud_im_plugin.dart';

import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';

/// 融云 IM 核心服务封装
/// 所有与融云 SDK 的交互都通过这里
///
/// ⚠️ 2026-09-04 SDK 迁移说明：
/// 此前误用了 pub.dev 上不存在的假想包 rongcloud_im_wrapper_flutter（RCIMIW* 6.x API），
/// 真实官方包为 rongcloud_im_plugin（5.x），入口为静态类 [RongIMClient]：
///   - 初始化：RongIMClient.init(appKey)
///   - 连接：RongIMClient.connect(token, (code, userId) {...})，code == 0 表示成功
///   - 发送：RongIMClient.sendMessageWithCallBack(ct, tid, content, '', '', finished)
///   - 收消息：静态回调 RongIMClient.onMessageReceived = (msg, left) {...}
///   - 会话/历史：getConversationList / getHistoryMessages / clearMessagesUnreadStatus
///   - 撤回：先 getMessage(messageId) 取回 Message，再 recallMessage(message, '')
class RCIMDatasource {
  bool _isConnected = false;
  String? _currentUserId;

  // Stream 控制器
  final _messageStreamController = StreamController<MessageModel>.broadcast();
  final _connectionStatusController = StreamController<int>.broadcast();
  final _conversationListController =
      StreamController<List<Conversation>>.broadcast();

  // Stream Getters
  Stream<MessageModel> get onMessageReceived => _messageStreamController.stream;
  Stream<int> get onConnectionStatusChanged =>
      _connectionStatusController.stream;
  Stream<List<Conversation>> get onConversationListChanged =>
      _conversationListController.stream;

  String? get currentUserId => _currentUserId;
  bool get isConnected => _isConnected;

  bool _listenerBound = false;
  bool _sdkInitialized = false;

  /// 初始化 SDK（幂等：5.x Android 原生只允许 init 一次）
  Future<void> init() async {
    if (!_sdkInitialized) {
      await RongIMClient.init(AppConstants.rongCloudAppKey);
      _sdkInitialized = true;
    }
    _bindListeners();
  }

  /// 绑定静态事件回调（5.x 为静态属性赋值，只需绑定一次）
  void _bindListeners() {
    if (_listenerBound) return;
    _listenerBound = true;

    // 连接状态监听（登录后断线/重连状态变化）
    RongIMClient.onConnectionStatusChange = (int? code) {
      _connectionStatusController.add(code ?? -1);
      return null;
    };

    // 收到消息
    RongIMClient.onMessageReceived = (Message? msg, int? left) {
      final model = _convertMessage(msg);
      if (model != null) {
        _messageStreamController.add(model);
      }
      return null;
    };
  }

  /// 连接服务器（登录融云）
  /// 返回 0 表示成功（对齐 5.x connect 回调 code 语义）
  Future<int> connect({
    required String userId,
    required String token,
  }) async {
    final completer = Completer<int>();
    await RongIMClient.connect(token, (int? code, String? connectedUserId) {
      if (code == 0) {
        _isConnected = true;
        _currentUserId = connectedUserId ?? userId;
        unawaited(_loadConversationListInternal());
      }
      if (!completer.isCompleted) completer.complete(code ?? -1);
    });
    return completer.future;
  }

  /// 断开连接
  Future<void> disconnect({bool receivePush = true}) async {
    await RongIMClient.disconnect(receivePush);
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
    final textMessage = TextMessage.obtain(content);
    _attachSender(textMessage, senderName);
    return _send(conversationType, targetId, textMessage);
  }

  /// 发送图片消息
  Future<MessageModel?> sendImageMessage({
    required int conversationType,
    required String targetId,
    required String imagePath,
    String? senderName,
  }) async {
    // 5.x Android 要求 localPath 以 file:// 开头
    final imageMessage = ImageMessage.obtain(_toFileUri(imagePath));
    _attachSender(imageMessage, senderName);
    return _send(conversationType, targetId, imageMessage);
  }

  /// 发送语音消息
  Future<MessageModel?> sendVoiceMessage({
    required int conversationType,
    required String targetId,
    required String voicePath,
    int durationSeconds = 0,
    String? senderName,
  }) async {
    // 5.x Android 要求 localPath 以 file:// 开头
    final voiceMessage =
        VoiceMessage.obtain(_toFileUri(voicePath), durationSeconds);
    _attachSender(voiceMessage, senderName);
    return _send(conversationType, targetId, voiceMessage);
  }

  /// 统一发送入口（5.x：sendMessageWithCallBack + finished 回调判定结果）
  /// 发送成功（code==0）后从本地库取完整消息（媒体消息含远端地址）返回；
  /// 失败返回 null。
  Future<MessageModel?> _send(
    int conversationType,
    String targetId,
    MessageContent content,
  ) {
    final completer = Completer<MessageModel?>();
    // 快照变量先声明：finished 回调可能先于 Future resolve 触发，闭包引用才合法
    Message? snapshot;

    RongIMClient.sendMessageWithCallBack(
      conversationType,
      targetId,
      content,
      '',
      '',
      (int messageId, int status, int code) {
        if (code != 0) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        // 成功：取本地完整消息（图片/语音发送成功后 SDK 会补全远端地址）
        RongIMClient.getMessage(messageId).then((Message? full) {
          final model = _convertMessage(full ?? snapshot)?.copyWith(
            messageId: '$messageId',
            sentStatus: 1,
          );
          if (!completer.isCompleted) completer.complete(model);
        }).catchError((Object _) {
          // getMessage 极低概率失败：退化为快照 + 成功态
          final model = _convertMessage(snapshot)?.copyWith(
            messageId: '$messageId',
            sentStatus: 1,
          );
          if (!completer.isCompleted) completer.complete(model);
        });
      },
    ).then((Message? m) {
      // Future 携带发送快照（权威结果以 finished 回调为准）
      snapshot = m;
    }).catchError((Object _) {
      // 发送链路异常且回调未成功：兜底完成，避免上层永久挂起
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  /// 为消息附加发送者信息（对端可通过 content.sendUserInfo 展示昵称/头像）
  void _attachSender(MessageContent content, String? senderName) {
    if (senderName == null || senderName.isEmpty) return;
    content.sendUserInfo = UserInfo()
      ..userId = _currentUserId ?? ''
      ..name = senderName;
  }

  /// Android 媒体消息路径规范化：绝对路径 → file:// 前缀
  String _toFileUri(String path) {
    if (path.startsWith('file://') ||
        path.startsWith('content://') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }
    return Uri.file(path).toString();
  }

  /// 获取历史消息（sentTime 之前 beforeCount 条；sentTime 传 null/-1 从最新开始）
  Future<List<MessageModel>> getHistoryMessages({
    required int conversationType,
    required String targetId,
    int? timestamp,
    int count = 20,
  }) async {
    final messages = await RongIMClient.getHistoryMessages(
      conversationType,
      targetId,
      timestamp ?? -1,
      count,
      0,
    );

    final result = <MessageModel>[];
    if (messages != null) {
      for (final msg in messages) {
        final model = _convertMessage(msg as Message?);
        if (model != null) result.add(model);
      }
    }
    return result;
  }

  /// 加载会话列表（内部：拉取后推流）
  Future<List<Conversation>> _loadConversationListInternal() async {
    final list = await RongIMClient.getConversationList([
      RCConversationType.Private,
      RCConversationType.Group,
    ]);
    if (list != null) {
      _conversationListController.add(list.cast<Conversation>());
    }
    return list?.cast<Conversation>() ?? [];
  }

  Future<void> loadConversationList() async {
    await _loadConversationListInternal();
  }

  /// 设置消息已读（清零某会话未读数）
  Future<void> markMessageAsRead({
    required int conversationType,
    required String targetId,
  }) async {
    await RongIMClient.clearMessagesUnreadStatus(
      conversationType,
      targetId,
    );
  }

  /// 撤回消息
  /// 5.x recallMessage 需要完整 Message 对象：先按 messageId 取回再撤回
  /// 返回 0 表示成功，非 0 为错误码
  Future<int> recallMessage(String messageId) async {
    final id = int.tryParse(messageId);
    if (id == null) return -1;
    final message = await RongIMClient.getMessage(id);
    if (message == null) return -1;
    final result = await RongIMClient.recallMessage(message, '');
    // 5.x：撤回成功返回 RecallNotificationMessage，失败返回 null
    return result == null ? -1 : 0;
  }

  /// 将融云 5.x Message 转换为 MessageModel
  MessageModel? _convertMessage(Message? msg) {
    if (msg == null) return null;

    final contentObj = msg.content;
    String content = '';
    String messageType = msg.objectName ?? 'RC:TxtMsg';
    String? extra = msg.extra;

    if (contentObj is TextMessage) {
      content = contentObj.content ?? '';
      messageType = 'RC:TxtMsg';
    } else if (contentObj is ImageMessage) {
      // 远端地址：5.x 图片存 imageUri（发送成功后 SDK 自动补全）
      final remote = contentObj.imageUri ?? '';
      final local = contentObj.localPath ?? '';
      content = remote.isNotEmpty ? remote : local;
      messageType = 'RC:ImgMsg';
    } else if (contentObj is VoiceMessage) {
      // 语音：5.x objectName 为 RC:HQVCMsg，项目内部统一映射 RC:VcMsg
      final remote = contentObj.remoteUrl ?? '';
      final local = contentObj.localPath ?? '';
      content = remote.isNotEmpty ? remote : local;
      messageType = 'RC:VcMsg';
      extra = jsonEncode({'duration': contentObj.duration ?? 0});
    } else if (contentObj is RecallNotificationMessage) {
      // 对端撤回通知（objectName RC:RcNtf）
      // 文案按撤回操作者区分：自己撤回（其它端操作）vs 对方撤回
      final operatorId = contentObj.mOperatorId ?? '';
      final isSelf = operatorId.isNotEmpty && operatorId == _currentUserId;
      messageType = AppConstants.msgTypeRecall;
      content = isSelf ? '你撤回了一条消息' : '[对方撤回了一条消息]';
      extra = jsonEncode({
        'operatorId': operatorId,
        'originalObjectName': contentObj.mOriginalObjectName ?? '',
        'recallTime': contentObj.mRecallTime ?? 0,
      });
    } else if (contentObj is FileMessage) {
      content = contentObj.mName ?? '[文件]';
      messageType = 'RC:FileMsg';
    } else {
      // 未知/未解码消息（引用、GIF、阅后即焚等）：给占位文案避免空白气泡
      content = '[暂不支持的消息类型]';
      if (contentObj == null) {
        // 解码失败（如 SDK 未注册 decoder）：退化为原始 objectName 展示
        content = '[$messageType]';
      }
    }

    // 发送者信息：5.x Message 无 senderName 字段，昵称在 content.sendUserInfo
    String senderName = contentObj?.sendUserInfo?.name ?? '';
    String? senderPortrait = contentObj?.sendUserInfo?.portraitUri;

    // 收消息（direction=Receive）sentStatus 无意义，统一置 1（成功）
    final isReceive = msg.messageDirection == RCMessageDirection.Receive;
    final sentStatus = isReceive
        ? 1
        : (msg.sentStatus == RCSentStatus.Sent ||
                msg.sentStatus == RCSentStatus.Received ||
                msg.sentStatus == RCSentStatus.Read)
            ? 1
            : (msg.sentStatus == RCSentStatus.Failed ? 2 : 0);

    return MessageModel(
      messageId: msg.messageId?.toString() ?? '',
      senderId: msg.senderUserId ?? '',
      senderName: senderName,
      senderPortrait: senderPortrait,
      targetId: msg.targetId ?? '',
      conversationType: msg.conversationType ?? 1,
      content: content,
      messageType: messageType,
      sentStatus: sentStatus,
      timestamp: msg.sentTime ?? DateTime.now().millisecondsSinceEpoch,
      extra: extra,
    );
  }

  void dispose() {
    unawaited(RongIMClient.disconnect(true));
    _messageStreamController.close();
    _connectionStatusController.close();
    _conversationListController.close();
  }
}

// Provider
final rcimDatasourceProvider = Provider<RCIMDatasource>((ref) {
  final ds = RCIMDatasource();
  ref.onDispose(() => ds.dispose());
  return ds;
});
