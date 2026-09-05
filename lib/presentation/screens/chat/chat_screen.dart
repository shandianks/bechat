import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/voice_player_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/message_model.dart';
import '../../providers/providers.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input_bar.dart';

/// 聊天页面（单聊 + 群聊 复用）
class ChatScreen extends ConsumerStatefulWidget {
  final int conversationType; // 1=单聊 3=群聊
  final String targetId;
  final String title;

  const ChatScreen({
    super.key,
    required this.conversationType,
    required this.targetId,
    required this.title,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<List<MessageModel>>? _messageSub;
  bool _isLoading = true;
  List<MessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initVoiceTracking();
    // 订阅消息流：收消息 / 发送状态变更 / 撤回删除 均由 Repository 推送驱动
    _messageSub = ref
        .read(chatProvider)
        .messageStream(widget.conversationType, widget.targetId)
        .listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      // 正停留在聊天页：收到的消息即时清零会话未读
      unawaited(ref.read(chatProvider).markAsRead(
            conversationType: widget.conversationType,
            targetId: widget.targetId,
          ));
    });
  }

  /// 语音红点持久化：
  /// 1) 启动时把本地已播放记录灌入播放服务（重启后红点不复活）
  /// 2) 播放回调 → 写入 Hive
  Future<void> _initVoiceTracking() async {
    final repo = ref.read(chatProvider);
    try {
      final played = await repo.loadPlayedVoiceIds();
      VoicePlayerService.instance.playedMessageIds.addAll(played);
    } catch (_) {}
    VoicePlayerService.instance.onVoicePlayed = (messageId) {
      unawaited(repo.markVoicePlayed(messageId));
    };
  }

  @override
  void dispose() {
    VoicePlayerService.instance.onVoicePlayed = null;
    _messageSub?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    VoicePlayerService.instance.stop();
    super.dispose();
  }

  Future<void> _loadMessages({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatProvider);
      final msgs = await repo.loadMessages(
        conversationType: widget.conversationType,
        targetId: widget.targetId,
      );
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });

      // 标记已读
      repo.markAsRead(
        conversationType: widget.conversationType,
        targetId: widget.targetId,
      );

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      if (showSpinner) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendImage(String imagePath) async {
    final repo = ref.read(chatProvider);
    await repo.sendImageMessage(
      conversationType: widget.conversationType,
      targetId: widget.targetId,
      imagePath: imagePath,
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _sendVoice(String voicePath, int durationSeconds) async {
    final repo = ref.read(chatProvider);
    await repo.sendVoiceMessage(
      conversationType: widget.conversationType,
      targetId: widget.targetId,
      voicePath: voicePath,
      durationSeconds: durationSeconds,
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _sendFile(String filePath) async {
    final repo = ref.read(chatProvider);
    await repo.sendFileMessage(
      conversationType: widget.conversationType,
      targetId: widget.targetId,
      filePath: filePath,
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    _textController.clear();
    _focusNode.requestFocus();

    final sendMessage = ref.read(sendMessageProvider);
    await sendMessage(
      widget.conversationType,
      widget.targetId,
      content,
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  /// 长按消息菜单动作
  Future<void> _handleMessageAction(String action, MessageModel msg) async {
    final repo = ref.read(chatProvider);
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.content));
        messenger.showSnackBar(
          const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
        );
        break;
      case 'recall':
        final ok = await repo.recallMessage(
          conversationType: widget.conversationType,
          targetId: widget.targetId,
          messageId: msg.messageId,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(ok ? '已撤回' : '撤回失败：可能超过撤回时限'),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case 'delete':
        await repo.deleteMessage(
          conversationType: widget.conversationType,
          targetId: widget.targetId,
          messageId: msg.messageId,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
        );
        break;
      case 'resend':
        final resent = await repo.resendMessage(
          conversationType: widget.conversationType,
          targetId: widget.targetId,
          failedMessage: msg,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              resent.sentStatus == 1 ? '已重发' : '重发失败，请检查网络后重试',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.conversationType == 3 ? '群聊' : '在线',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.conversationType == 3)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.push('/group/${widget.targetId}/info'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => _loadMessages(showSpinner: false),
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMine = msg.senderId == currentUserId;
                            final showAvatar = !isMine &&
                                (index == _messages.length - 1 ||
                                    _messages[index + 1].senderId != msg.senderId);

                            return MessageBubble(
                              message: msg,
                              isMine: isMine,
                              showAvatar: showAvatar,
                              onAction: _handleMessageAction,
                            );
                          },
                        ),
                      ),
          ),
          // 输入栏
          ChatInputBar(
            controller: _textController,
            focusNode: _focusNode,
            onSend: _sendMessage,
            conversationType: widget.conversationType,
            targetId: widget.targetId,
            onSendImage: _sendImage,
            onSendVoice: _sendVoice,
            onSendFile: _sendFile,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 56,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无消息',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '开始聊天吧',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
