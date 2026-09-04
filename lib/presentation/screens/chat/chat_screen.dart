import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/voice_player_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';
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
  bool _isLoading = true;
  List<MessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    VoicePlayerService.instance.stop();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
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
      setState(() => _isLoading = false);
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
    final msg = await repo.sendImageMessage(
      conversationType: widget.conversationType,
      targetId: widget.targetId,
      imagePath: imagePath,
    );
    setState(() {
      _messages = [msg, ..._messages];
    });
    _scrollToBottom();
  }

  Future<void> _sendVoice(String voicePath, int durationSeconds) async {
    final repo = ref.read(chatProvider);
    final msg = await repo.sendVoiceMessage(
      conversationType: widget.conversationType,
      targetId: widget.targetId,
      voicePath: voicePath,
      durationSeconds: durationSeconds,
    );
    if (!mounted) return;
    setState(() {
      _messages = [msg, ..._messages];
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    _textController.clear();
    _focusNode.requestFocus();

    final sendMessage = ref.read(sendMessageProvider);
    final msg = await sendMessage(
      widget.conversationType,
      widget.targetId,
      content,
    );

    setState(() {
      _messages = [msg, ..._messages];
    });
    _scrollToBottom();
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
                        onRefresh: _loadMessages,
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
            color: AppColors.textHint.withOpacity(0.5),
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
