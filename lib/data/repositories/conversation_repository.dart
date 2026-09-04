import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/local_datasource.dart';
import '../datasources/rcim_datasource.dart';
import '../models/conversation_model.dart';

/// 会话列表服务
class ConversationRepository {
  final LocalDatasource _local;
  final RCIMDatasource _rcim;

  final _conversationListController = StreamController<List<ConversationModel>>.broadcast();
  List<ConversationModel> _conversationList = [];

  ConversationRepository(this._local, this._rcim) {
    _init();
  }

  void _init() {
    // 单一事实源：所有会话写操作（收消息/发送/撤回/清未读/upsert）都经 LocalDatasource 广播，
    // 这里订阅后从 Hive 重读推流，避免内存副本与 Hive 双写不一致
    _local.onConversationChanged.listen((_) => _refreshList());

    // 融云会话列表变化：仅补本地缺失的会话（冷启动/新设备首拉），已存在则本地为准不覆盖
    _rcim.onConversationListChanged.listen((rcimConversations) async {
      for (final rc in rcimConversations) {
        final type = rc.conversationType ?? 1;
        final target = rc.targetId ?? '';
        if (target.isEmpty) continue;
        final local = _local.getConversation(
          conversationType: type,
          targetId: target,
        );
        if (local == null) {
          await _local.saveConversation(ConversationModel(
            targetId: target,
            conversationType: type,
            title: rc.title,
            portrait: rc.portrait,
            lastMessageContent: _displayOf(rc),
            lastMessageTime: rc.sentTime?.toInt() ?? 0,
            unreadCount: rc.unreadMessageCount ?? 0,
          ));
          // saveConversation 已广播事件，订阅会自动刷新列表
        }
      }
    });

    // 初始化时从本地加载
    _refreshList();
  }

  /// 融云会话对象 → 会话列表展示文本（对象名转占位文案）
  String _displayOf(RCIMIWConversation rc) {
    final name = rc.lastMessage?.objectName;
    switch (name) {
      case 'RC:ImgMsg':
        return '[图片]';
      case 'RC:VcMsg':
        return '[语音]';
      case 'RC:FileMsg':
        return '[文件]';
      default:
        // 文本消息对象名原样展示无意义，优先草稿
        return (rc.draft?.isNotEmpty ?? false) ? rc.draft! : '';
    }
  }

  /// 获取会话列表
  List<ConversationModel> getConversationList() {
    return _conversationList;
  }

  /// 监听会话列表变化
  Stream<List<ConversationModel>> watchConversationList() {
    return _conversationListController.stream;
  }

  /// 获取会话
  ConversationModel? getConversation({
    required int conversationType,
    required String targetId,
  }) {
    return _local.getConversation(
      conversationType: conversationType,
      targetId: targetId,
    );
  }

  /// 获取总未读数
  int get totalUnreadCount {
    return _conversationList.fold(0, (sum, c) => sum + c.unreadCount);
  }

  /// 创建或更新会话（本地）
  Future<void> upsertConversation({
    required int conversationType,
    required String targetId,
    String? title,
    String? portrait,
  }) async {
    final key = '${conversationType}_$targetId';
    final existing = _local.getConversation(
      conversationType: conversationType,
      targetId: targetId,
    );

    if (existing != null) {
      await _local.saveConversation(existing.copyWith(
        title: title ?? existing.title,
        portrait: portrait ?? existing.portrait,
      ));
    } else {
      final conv = ConversationModel(
        targetId: targetId,
        conversationType: conversationType,
        title: title,
        portrait: portrait,
        lastMessageTime: DateTime.now().millisecondsSinceEpoch,
      );
      await _local.saveConversation(conv);
      _refreshList();
    }
  }

  void _refreshList() {
    _conversationList = _local.getConversationList();
    _conversationListController.add(_conversationList);
  }

  void dispose() {
    _conversationListController.close();
  }
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final repo = ConversationRepository(
    ref.read(localDatasourceProvider),
    ref.read(rcimDatasourceProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});
