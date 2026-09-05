import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 语音播放服务（全局单例）
/// 保证同一时刻只有一条语音在播放
class VoicePlayerService extends ChangeNotifier {
  VoicePlayerService._internal();
  static final VoicePlayerService instance = VoicePlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// 当前正在播放的消息 ID
  String? playingMessageId;

  /// 本次会话内已播放过的消息 ID（用于未播放红点）
  final Set<String> playedMessageIds = {};

  /// 播放回调：开始播放某条语音时触发（供上层持久化"已播放"标记，重启后红点不复活）
  void Function(String messageId)? onVoicePlayed;

  bool get isPlaying => _player.state == PlayerState.playing;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  /// 播放完成后的回调（供 UI 清理状态）
  bool _initialized = false;

  void _ensureListener() {
    if (_initialized) return;
    _initialized = true;

    _player.onPositionChanged.listen((pos) {
      position = pos;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      duration = dur;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      playingMessageId = null;
      position = Duration.zero;
      duration = Duration.zero;
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (playingMessageId != null) {
          playingMessageId = null;
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    });
  }

  /// 点击语音气泡：切换播放/停止
  Future<void> toggle({
    required String messageId,
    required String source,
  }) async {
    _ensureListener();

    // 点击的是正在播放的消息 → 停止
    if (playingMessageId == messageId && isPlaying) {
      await _player.stop();
      playingMessageId = null;
      position = Duration.zero;
      notifyListeners();
      return;
    }

    // 正在播其他消息 → 先停掉
    if (isPlaying) {
      await _player.stop();
    }

    playingMessageId = messageId;
    playedMessageIds.add(messageId);
    onVoicePlayed?.call(messageId);
    position = Duration.zero;
    notifyListeners();

    try {
      final Source src = source.startsWith('http')
          ? UrlSource(source)
          : DeviceFileSource(source);
      await _player.play(src);
    } catch (e) {
      // 播放失败，清理状态
      playingMessageId = null;
      notifyListeners();
      debugPrint('VoicePlayerService.play error: $e');
    }
  }

  /// 停止播放（页面退出等场景）
  Future<void> stop() async {
    await _player.stop();
    playingMessageId = null;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
