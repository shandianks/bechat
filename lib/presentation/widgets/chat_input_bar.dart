import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final int conversationType;
  final String targetId;
  final void Function(String imagePath) onSendImage;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.conversationType,
    required this.targetId,
    required this.onSendImage,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        widget.onSendImage(image.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 更多功能按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.textSecondary,
                onPressed: () => _showMoreActions(context),
              ),
              // 输入框
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 120,
                    minHeight: 40,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(color: AppColors.textHint),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      if (widget.controller.text.trim().isNotEmpty) {
                        widget.onSend();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 发送按钮
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _hasText ? 40 : 0,
                child: _hasText
                    ? IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        onPressed: widget.onSend,
                      )
                    : const SizedBox.shrink(),
              ),
              // 语音按钮（无文字时显示）
              if (!_hasText)
                IconButton(
                  icon: const Icon(Icons.mic_none_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () {
                    // TODO: 语音录制
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('语音功能开发中...')),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAction(
                  icon: Icons.photo_library,
                  label: '相册',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickImage(ctx, ImageSource.gallery);
                  },
                ),
                _buildAction(
                  icon: Icons.camera_alt,
                  label: '拍照',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickImage(ctx, ImageSource.camera);
                  },
                ),
                _buildAction(
                  icon: Icons.folder,
                  label: '文件',
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('文件功能开发中...')),
                    );
                  },
                ),
                _buildAction(
                  icon: Icons.person_add,
                  label: '联系人',
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: 分享联系人
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
