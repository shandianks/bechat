import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final int conversationType;
  final String targetId;
  final void Function(String imagePath) onSendImage;

  /// 语音发送回调（本地路径 + 时长秒）
  final void Function(String voicePath, int durationSeconds) onSendVoice;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.conversationType,
    required this.targetId,
    required this.onSendImage,
    required this.onSendVoice,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;
  bool _voiceMode = false;

  // ---- 录音相关 ----
  final AudioRecorder _recorder = AudioRecorder();
  final GlobalKey _holdBtnKey = GlobalKey();
  String? _recordPath;
  Stopwatch? _recordWatch;
  Timer? _recordTimer;
  bool _cancelArmed = false;
  bool _isRecording = false;
  bool _gestureActive = false;
  int _recordMillis = 0;
  OverlayEntry? _recordOverlay;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recordTimer?.cancel();
    _removeRecordOverlay();
    _cancelNotifier.dispose();
    _millisNotifier.dispose();
    _recorder.dispose();
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

  // ==================== 录音逻辑 ====================

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showToast('需要麦克风权限才能录音');
        return;
      }
      // 权限弹窗期间用户可能已松手
      if (!_gestureActive) return;

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!_gestureActive) {
        // 录音刚启动但手势已结束：直接停止并丢弃
        await _recorder.cancel();
        return;
      }

      _recordPath = path;
      _recordWatch = Stopwatch()..start();
      _recordMillis = 0;
      _cancelArmed = false;
      _isRecording = true;

      // 计时刷新
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _recordMillis = _recordWatch?.elapsedMilliseconds ?? 0);
        // 同步浮层计时（Overlay 独立于本 widget 树）
        _millisNotifier.value = _recordMillis;
      });

      _showRecordOverlay();
    } catch (e) {
      _isRecording = false;
      _showToast('录音启动失败');
    }
  }

  /// 结束录音：cancel=true 丢弃，否则走发送流程
  Future<void> _finishRecording({required bool cancel}) async {
    if (!_isRecording) return;
    _isRecording = false;
    _recordTimer?.cancel();
    _recordWatch?.stop();
    final durationMs = _recordWatch?.elapsedMilliseconds ?? 0;
    final path = _recordPath;
    _recordPath = null;
    _removeRecordOverlay();

    try {
      if (cancel) {
        await _recorder.cancel();
        _deleteFile(path);
        return;
      }

      final savedPath = await _recorder.stop();
      if (savedPath == null || savedPath.isEmpty) {
        _deleteFile(path);
        return;
      }

      final seconds = (durationMs / 1000).round();
      if (seconds < 1) {
        _deleteFile(savedPath);
        _showToast('说话时间太短');
        return;
      }
      widget.onSendVoice(savedPath, seconds);
    } catch (e) {
      _deleteFile(path);
      _showToast('录音发送失败');
    }
  }

  void _deleteFile(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ---- 录音浮层（Overlay） ----

  void _showRecordOverlay() {
    _removeRecordOverlay();
    final overlay = Overlay.of(context);
    _recordOverlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: _cancelNotifier,
              builder: (context, cancelArmed, _) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 160,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: cancelArmed
                        ? Colors.red.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cancelArmed
                            ? Icons.keyboard_arrow_up
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<int>(
                        valueListenable: _millisNotifier,
                        builder: (context, millis, _) {
                          final sec = (millis / 1000).floor();
                          return Text(
                            cancelArmed ? '松开 取消' : '${sec}s',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: cancelArmed ? 14 : 22,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_recordOverlay!);
  }

  void _removeRecordOverlay() {
    _recordOverlay?.remove();
    _recordOverlay = null;
  }

  // ValueNotifier 供 Overlay 内刷新（跨 build 树）
  final ValueNotifier<bool> _cancelNotifier = ValueNotifier(false);
  final ValueNotifier<int> _millisNotifier = ValueNotifier(0);

  // ---- 按住说话手势 ----

  void _onHoldStart(LongPressStartDetails details) {
    _gestureActive = true;
    setState(() => _cancelArmed = false);
    _cancelNotifier.value = false;
    _startRecording();
  }

  void _onHoldMove(LongPressMoveUpdateDetails details) {
    // 手指上滑超过按钮上方 ~90px 判定为取消区
    final box = _holdBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final armed = details.globalPosition.dy < top - 90;
    if (armed != _cancelArmed) {
      setState(() => _cancelArmed = armed);
      _cancelNotifier.value = armed;
    }
    _millisNotifier.value = _recordWatch?.elapsedMilliseconds ?? 0;
  }

  void _onHoldEnd(LongPressEndDetails details) {
    _gestureActive = false;
    _millisNotifier.value = 0;
    _finishRecording(cancel: _cancelArmed);
    setState(() => _cancelArmed = false);
    _cancelNotifier.value = false;
  }

  void _onHoldCancel() {
    _gestureActive = false;
    _millisNotifier.value = 0;
    _finishRecording(cancel: true);
    setState(() => _cancelArmed = false);
    _cancelNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _voiceMode ? _buildVoiceModeBar() : _buildTextModeBar(),
        ),
      ),
    );
  }

  // ---- 文字输入模式 ----

  Widget _buildTextModeBar() {
    return Row(
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
        // 发送按钮（有文字时）
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
              widget.focusNode.unfocus();
              setState(() => _voiceMode = true);
            },
          ),
      ],
    );
  }

  // ---- 语音模式 ----

  Widget _buildVoiceModeBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 更多功能按钮（保留，语音模式也可发图）
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.textSecondary,
          onPressed: () => _showMoreActions(context),
        ),
        // 按住说话按钮
        Expanded(
          child: GestureDetector(
            key: _holdBtnKey,
            onLongPressStart: _onHoldStart,
            onLongPressMoveUpdate: _onHoldMove,
            onLongPressEnd: _onHoldEnd,
            onLongPressCancel: _onHoldCancel,
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.inputBg,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: _isRecording ? AppColors.primary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                _isRecording
                    ? '松开发送 ${(_recordMillis / 1000).toStringAsFixed(1)}s'
                    : '按住 说话',
                style: TextStyle(
                  fontSize: 15,
                  color: _isRecording
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 切换回键盘
        IconButton(
          icon: const Icon(Icons.keyboard_alt_outlined),
          color: AppColors.textSecondary,
          onPressed: () => setState(() => _voiceMode = false),
        ),
      ],
    );
  }

  // ---- 更多操作面板 ----

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
                    await _pickImage(context, ImageSource.gallery);
                  },
                ),
                _buildAction(
                  icon: Icons.camera_alt,
                  label: '拍照',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickImage(context, ImageSource.camera);
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
