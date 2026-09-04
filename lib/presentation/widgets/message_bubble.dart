import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/voice_player_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showAvatar;

  /// 长按菜单动作回调：action ∈ copy / recall / delete
  final Future<void> Function(String action, MessageModel message)? onAction;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showAvatar = true,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showActionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _buildAvatar(),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 发送者名称（群聊）
                  if (!isMine && message.conversationType == 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  // 气泡
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.myBubble : AppColors.otherBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : (showAvatar ? 4 : 18)),
                        bottomRight: Radius.circular(isMine ? (showAvatar ? 4 : 18) : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: _buildContent(context),
                  ),
                  // 时间 + 发送状态
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.formattedTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _buildSendStatus(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 8),
              _buildAvatar(),
            ],
          ],
        ),
        ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.messageType) {
      case 'RC:ImgMsg':
        return _buildImageContent(context);
      case 'RC:VcMsg':
        return _buildVoiceContent();
      default:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 16,
            color: isMine ? AppColors.myBubbleText : AppColors.otherBubbleText,
            height: 1.4,
          ),
        );
    }
  }

  Widget _buildImageContent(BuildContext context) {
    final isLocal = message.content.startsWith('/') ||
        message.content.startsWith('file://') ||
        message.content.startsWith('content://') ||
        message.content.startsWith('ph://') ||
        message.content.startsWith('tmp://');

    return GestureDetector(
      onTap: () => _showFullImage(context, message.content, isLocal),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImage(isLocal ? message.content : null, isLocal ? null : message.content),
      ),
    );
  }

  Widget _buildImage(String? localPath, String? remoteUrl) {
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 180,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageError(),
        );
      }
      return _buildImageError();
    }

    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remoteUrl,
        width: 180,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 180,
          height: 180,
          color: AppColors.inputBg,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => _buildImageError(),
      );
    }

    return _buildImageError();
  }

  Widget _buildImageError() {
    return Container(
      width: 180,
      height: 120,
      color: AppColors.inputBg,
      child: const Icon(Icons.broken_image, color: AppColors.textHint, size: 32),
    );
  }

  void _showFullImage(BuildContext context, String content, bool isLocal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageScreen(content: content, isLocal: isLocal),
      ),
    );
  }

  Widget _buildVoiceContent() {
    return _VoiceBubble(
      message: message,
      isMine: isMine,
    );
  }

  Widget _buildAvatar() {
    final portrait = message.senderPortrait;
    return CircleAvatar(
      radius: 16,
      backgroundImage: portrait != null ? NetworkImage(portrait) : null,
      child: portrait == null
          ? const Icon(Icons.person, size: 18, color: AppColors.textHint)
          : null,
    );
  }

  Widget _buildSendStatus() {
    switch (message.sentStatus) {
      case 0:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textHint),
          ),
        );
      case 1:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.textHint,
        );
      case 2:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.error,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 长按弹出消息操作菜单
  Future<void> _showActionSheet(BuildContext context) async {
    if (onAction == null) return;

    // 构建可用操作
    final actions = <(String, IconData, String)>[
      if (message.messageType == 'RC:TxtMsg')
        ('copy', Icons.copy_rounded, '复制'),
      if (isMine && message.sentStatus == 1)
        ('recall', Icons.replay_rounded, '撤回'),
      ('delete', Icons.delete_outline_rounded, '删除'),
    ];
    if (actions.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (key, icon, label) in actions)
                ListTile(
                  leading: Icon(icon, color: key == 'delete' ? AppColors.error : null),
                  title: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: key == 'delete' ? AppColors.error : null,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, key),
                ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !context.mounted) return;
    await onAction?.call(picked, message);
  }
}

/// 语音消息气泡（点击播放/暂停）
class _VoiceBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _VoiceBubble({required this.message, required this.isMine});

  /// 从 extra 或 content 解析语音时长（秒）
  int get _durationSeconds {
    if (message.extra != null && message.extra!.isNotEmpty) {
      try {
        final json = jsonDecode(message.extra!);
        if (json is Map && json['duration'] is int) {
          return json['duration'] as int;
        }
      } catch (_) {}
    }
    // 兼容旧格式：content 为 "5s"
    final m = RegExp(r'^(\d+)').firstMatch(message.content);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final service = VoicePlayerService.instance;

    return GestureDetector(
      onTap: () {
        service.toggle(
          messageId: message.messageId,
          source: message.content,
        );
      },
      child: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final isPlaying = service.playingMessageId == message.messageId &&
              service.isPlaying;
          double? progress;
          if (isPlaying && service.duration > Duration.zero) {
            progress = (service.position.inMilliseconds /
                    service.duration.inMilliseconds)
                .clamp(0.0, 1.0);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 播放状态图标
                  Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    size: 20,
                    color: isMine
                        ? AppColors.myBubbleText
                        : AppColors.otherBubbleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_durationSeconds\u2033',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine
                          ? AppColors.myBubbleText
                          : AppColors.otherBubbleText,
                    ),
                  ),
                  // 未播放小红点（对方消息，本次会话内未播放过）
                  if (!isMine &&
                      !service.playedMessageIds.contains(message.messageId) &&
                      service.playingMessageId != message.messageId)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              // 播放进度条
              SizedBox(
                width: 130,
                height: 2,
                child: isPlaying
                    ? LinearProgressIndicator(
                        value: progress ?? 0,
                        backgroundColor:
                            (isMine ? Colors.white : Colors.black)
                                .withOpacity(0.15),
                        color: isMine
                            ? AppColors.myBubbleText
                            : AppColors.primary,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 全屏图片查看器
class _FullImageScreen extends StatelessWidget {
  final String content;
  final bool isLocal;

  const _FullImageScreen({required this.content, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: isLocal
              ? Image.file(
                  File(content),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: content,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white54,
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
        ),
      ),
    );
  }
}
