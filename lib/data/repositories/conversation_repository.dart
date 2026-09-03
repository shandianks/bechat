import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/local_datasource.dart';
import '../datasources/rcim_datasource.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

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
    // 监听融云会话列表变化
    _rcim.onConversationListChanged.listen((rcimConversations) async {
      final list = <ConversationModel>[];
      for (final rc in rcimConversations) {
        final conv = ConversationModel(
          targetId: rc.targetId ?? '',
          conversationType: rc.conversationType ?? 1,
          title: rc.title,
          portrait: rc.portrait,
          lastMessageContent: rc.draft ?? rc.lastMessage?.objectName,
          lastMessageTime: rc.sentTime?.toInt() ?? 0,
          unreadCount: rc.unreadMessageCount ?? 0,
        );
        list.add(conv);
        await _local.saveConversation(conv);
      }
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      _conversationList = list;
      _conversationListController.add(_conversationList);
    });

    // 初始化时从本地加载
    _conversationList = _local.getConversationList();
    _conversationListController.add(_conversationList);
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
