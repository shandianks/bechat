import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 1)
class MessageModel extends Equatable {
  @HiveField(0)
  final String messageId;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String senderName;

  @HiveField(3)
  final String? senderPortrait;

  @HiveField(4)
  final String targetId; // 会话目标ID（对方用户ID 或 群ID）

  @HiveField(5)
  final int conversationType; // 1=单聊 3=群聊

  @HiveField(6)
  final String content;

  @HiveField(7)
  final String messageType; // RC:TxtMsg RC:ImgMsg 等

  @HiveField(8)
  final int sentStatus; // 0=发送中 1=发送成功 2=失败 3=删除

  @HiveField(9)
  final int? readStatus; // 0=未读 1=已读

  @HiveField(10)
  final int timestamp;

  @HiveField(11)
  final String? extra; // 扩展字段 JSON

  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    this.senderPortrait,
    required this.targetId,
    required this.conversationType,
    required this.content,
    required this.messageType,
    this.sentStatus = 1,
    this.readStatus,
    required this.timestamp,
    this.extra,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      messageId: json['messageId'] ?? json['mid'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? json['sender_name'] ?? '未知',
      senderPortrait: json['senderPortrait'],
      targetId: json['targetId'] ?? '',
      conversationType: json['conversationType'] ?? 1,
      content: json['content'] ?? json['text'] ?? json['message'] ?? '',
      messageType: json['messageType'] ?? 'RC:TxtMsg',
      sentStatus: json['sentStatus'] ?? 1,
      readStatus: json['readStatus'],
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      extra: json['extra'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPortrait': senderPortrait,
      'targetId': targetId,
      'conversationType': conversationType,
      'content': content,
      'messageType': messageType,
      'sentStatus': sentStatus,
      'readStatus': readStatus,
      'timestamp': timestamp,
      'extra': extra,
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? senderPortrait,
    String? targetId,
    int? conversationType,
    String? content,
    String? messageType,
    int? sentStatus,
    int? readStatus,
    int? timestamp,
    String? extra,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPortrait: senderPortrait ?? this.senderPortrait,
      targetId: targetId ?? this.targetId,
      conversationType: conversationType ?? this.conversationType,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      sentStatus: sentStatus ?? this.sentStatus,
      readStatus: readStatus ?? this.readStatus,
      timestamp: timestamp ?? this.timestamp,
      extra: extra ?? this.extra,
    );
  }

  /// 是否为自己发送的消息
  bool isMine(String currentUserId) => senderId == currentUserId;

  /// 获取格式化时间
  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        messageId,
        senderId,
        targetId,
        conversationType,
        content,
        messageType,
        sentStatus,
        timestamp,
      ];
}
