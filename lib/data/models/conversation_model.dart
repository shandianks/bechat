import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'message_model.dart';
import 'user_model.dart';
import 'group_model.dart';

part 'conversation_model.g.dart';

/// 会话列表项
@HiveType(typeId: 3)
class ConversationModel extends Equatable {
  @HiveField(0)
  final String targetId; // 单聊=对方用户ID，群聊=群ID

  @HiveField(1)
  final int conversationType; // 1=单聊 3=群聊

  @HiveField(2)
  final String? title; // 显示标题（用户名 或 群名）

  @HiveField(3)
  final String? portrait; // 头像

  @HiveField(4)
  final String? lastMessageContent; // 最后一条消息摘要

  @HiveField(5)
  final int lastMessageTime; // 最后消息时间戳

  @HiveField(6)
  final int unreadCount; // 未读消息数

  @HiveField(7)
  final String? draft; // 草稿

  @HiveField(8)
  final int? mentionedCount; // @我的消息数

  const ConversationModel({
    required this.targetId,
    required this.conversationType,
    this.title,
    this.portrait,
    this.lastMessageContent,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.draft,
    this.mentionedCount,
  });

  /// 生成会话唯一Key
  String get conversationKey => '${conversationType}_$targetId';

  /// 是否为群聊
  bool get isGroup => conversationType == 3;

  /// 是否为单聊
  bool get isPrivate => conversationType == 1;

  /// 格式化最后消息时间
  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(lastMessageTime);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year) {
      return '${dt.month}/${dt.day}';
    }
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  factory ConversationModel.fromMessage({
    required MessageModel message,
    UserModel? user,
    GroupModel? group,
  }) {
    return ConversationModel(
      targetId: message.targetId,
      conversationType: message.conversationType,
      title: message.isGroup
          ? (group?.name ?? '群组')
          : (user?.nickname ?? '用户'),
      portrait: message.isGroup
          ? group?.portrait
          : (user?.portrait ?? message.senderPortrait),
      lastMessageContent: _getMessageSummary(message),
      lastMessageTime: message.timestamp,
    );
  }

  static String _getMessageSummary(MessageModel msg) {
    switch (msg.messageType) {
      case 'RC:TxtMsg':
        return msg.content;
      case 'RC:ImgMsg':
        return '[图片]';
      case 'RC:VcMsg':
        return '[语音]';
      case 'RC:FileMsg':
        return '[文件]';
      default:
        return msg.content;
    }
  }

  ConversationModel copyWith({
    String? targetId,
    int? conversationType,
    String? title,
    String? portrait,
    String? lastMessageContent,
    int? lastMessageTime,
    int? unreadCount,
    String? draft,
    int? mentionedCount,
  }) {
    return ConversationModel(
      targetId: targetId ?? this.targetId,
      conversationType: conversationType ?? this.conversationType,
      title: title ?? this.title,
      portrait: portrait ?? this.portrait,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      draft: draft ?? this.draft,
      mentionedCount: mentionedCount ?? this.mentionedCount,
    );
  }

  @override
  List<Object?> get props => [
        targetId,
        conversationType,
        lastMessageTime,
        unreadCount,
        lastMessageContent,
      ];
}
