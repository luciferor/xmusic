import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 只做 AudioService <-> just_audio 桥接，不维护播放队列，所有业务逻辑交由 controller 统一管理
class XMusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // 外部播放器注入（可选）
  AudioPlayer? _externalPlayer;
  // 回调
  Function()? onSkipToNext;
  Function()? onSkipToPrevious;

  StreamSubscription? _playbackEventSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _processingStateSub;
  StreamSubscription? _audioSessionSub;

  XMusicAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // 移除重复的 AudioSession 配置，因为 main.dart 已经配置过了
    final session = await AudioSession.instance;

    // 监听音频会话状态变化
    _audioSessionSub = session.becomingNoisyEventStream.listen((_) {
      if (kDebugMode) {
        print('🎵 [AudioHandler] 音频会话变得嘈杂，暂停播放');
      }
      pause();
    });

    // 这里只初始化，不 setAudioSource，由 controller 负责
    _listenToPlayerEvents();
  }

  void _listenToPlayerEvents() {
    // 2024-07-18 注释掉内部 _player 的事件流监听，防止覆盖外部播放器状态
    // _playbackEventSub = _player.playbackEventStream.listen((event) {
    //   _broadcastCurrentState();
    // });
    // _processingStateSub = _player.processingStateStream.listen((state) {
    //   _broadcastCurrentState();
    // });
    // _positionSub = _player.positionStream
    //     .throttleTime(const Duration(milliseconds: 500))
    //     .listen((pos) {
    //       playbackState.add(
    //         playbackState.value.copyWith(
    //           updatePosition: pos,
    //           speed: _player.speed,
    //         ),
    //       );
    //     });
    // 2024-07-18 end
  }

  // 由 controller 调用，更新系统通知栏/锁屏的媒体信息
  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);

    // 确保音频会话保持活跃
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      if (kDebugMode) {
        print('🎵 [AudioHandler] 确保音频会话活跃');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AudioHandler] 音频会话激活失败: $e');
      }
    }
  }

  // 新增：更新歌词到系统通知栏
  Future<void> updateLyrics(
    String currentLyric,
    int currentLyricIndex,
    List<String> allLyrics,
  ) async {
    try {
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        // 创建包含歌词信息的 extras
        final extras = Map<String, dynamic>.from(currentItem.extras ?? {});
        extras['currentLyric'] = currentLyric;
        extras['currentLyricIndex'] = currentLyricIndex;
        extras['allLyrics'] = allLyrics;
        extras['lyricsUpdateTime'] = DateTime.now().millisecondsSinceEpoch;

        // 更新 MediaItem 并广播
        final updatedItem = currentItem.copyWith(extras: extras);
        mediaItem.add(updatedItem);

        if (kDebugMode) {
          print('🎵 [AudioHandler] 歌词已同步到系统通知栏: $currentLyric');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AudioHandler] 同步歌词失败: $e');
      }
    }
  }

  // 新增：清除歌词信息
  Future<void> clearLyrics() async {
    try {
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        final extras = Map<String, dynamic>.from(currentItem.extras ?? {});
        extras.remove('currentLyric');
        extras.remove('currentLyricIndex');
        extras.remove('allLyrics');
        extras.remove('lyricsUpdateTime');

        final updatedItem = currentItem.copyWith(extras: extras);
        mediaItem.add(updatedItem);

        if (kDebugMode) {
          print('🎵 [AudioHandler] 歌词信息已清除');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AudioHandler] 清除歌词失败: $e');
      }
    }
  }

  // 新增：获取当前歌词信息
  Map<String, dynamic>? getCurrentLyricsInfo() {
    try {
      final currentItem = mediaItem.value;
      if (currentItem != null && currentItem.extras != null) {
        final extras = currentItem.extras!;
        if (extras.containsKey('currentLyric')) {
          return {
            'currentLyric': extras['currentLyric'] as String? ?? '',
            'currentLyricIndex': extras['currentLyricIndex'] as int? ?? 0,
            'allLyrics': extras['allLyrics'] as List<String>? ?? [],
            'lyricsUpdateTime': extras['lyricsUpdateTime'] as int? ?? 0,
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AudioHandler] 获取歌词信息失败: $e');
      }
      return null;
    }
  }

  // 由 controller 调用，手动同步播放状态
  void broadcastState() {
    _broadcastCurrentState();
  }

  // 由 controller 调用，手动同步外部播放器状态
  void syncExternalPlayerState(AudioPlayer externalPlayer) {
    if (kDebugMode) {
      print(
        '🎵 [AudioHandler] 同步外部播放器状态: playing=${externalPlayer.playing}, processingState=${externalPlayer.processingState}',
      );
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          externalPlayer.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _mapProcessingState(externalPlayer.processingState),
        playing: externalPlayer.playing,
        updatePosition: externalPlayer.position,
        bufferedPosition: externalPlayer.bufferedPosition,
        speed: externalPlayer.speed,
        queueIndex: externalPlayer.currentIndex,
      ),
    );
  }

  // 由 controller 调用，手动同步当前索引
  void syncCurrentIndex(int index) {
    if (kDebugMode) {
      print('🎵 [AudioHandler] 同步当前索引: $index');
    }
    // 这里只同步 queueIndex，实际播放由 controller 控制
    playbackState.add(playbackState.value.copyWith(queueIndex: index));
  }

  // 支持外部播放器注入
  void setExternalPlayer(AudioPlayer player) {
    _externalPlayer = player;
    if (kDebugMode) {
      print('🎵 [AudioHandler] 设置外部播放器');
    }
  }

  // 支持设置回调
  void setCallbacks({Function()? onNext, Function()? onPrevious}) {
    onSkipToNext = onNext;
    onSkipToPrevious = onPrevious;
    if (kDebugMode) {
      print('🎵 [AudioHandler] 设置回调函数');
    }
  }

  // 播放控制
  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] play() 被调用');
    }

    // 确保音频会话活跃
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      if (kDebugMode) {
        print('🎵 [AudioHandler] 播放前确保音频会话活跃');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AudioHandler] 音频会话激活失败: $e');
      }
    }

    /* 2024-07-18 新增：优先操作外部播放器 */
    if (_externalPlayer != null) {
      if (kDebugMode) {
        print('[2024-07-18] play: 使用 externalPlayer');
      }
      await _externalPlayer!.play();
    } else {
      if (kDebugMode) {
        print('[2024-07-18] play: 使用内部 _player');
      }
      await _player.play();
    }
    _broadcastCurrentState();
    /* 2024-07-18 end */
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] pause() 被调用');
    }

    // 原有代码：
    // await _player.pause();
    // _broadcastCurrentState();
    /* 2024-07-18 新增：优先操作外部播放器 */
    if (_externalPlayer != null) {
      if (kDebugMode) {
        print('[2024-07-18] pause: 使用 externalPlayer');
      }
      await _externalPlayer!.pause();
    } else {
      if (kDebugMode) {
        print('[2024-07-18] pause: 使用内部 _player');
      }
      await _player.pause();
    }
    _broadcastCurrentState();
    /* 2024-07-18 end */
  }

  @override
  Future<void> stop() async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] stop() 被调用');
    }

    if (_externalPlayer != null) {
      await _externalPlayer!.stop();
    } else {
      await _player.stop();
    }
    _broadcastCurrentState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] seek() 被调用: $position');
    }

    if (_externalPlayer != null) {
      await _externalPlayer!.seek(position);
    } else {
      await _player.seek(position);
    }
    _broadcastCurrentState();
  }

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] skipToNext() 被调用');
    }

    if (onSkipToNext != null) {
      await onSkipToNext!();
    } else if (_externalPlayer != null) {
      await _externalPlayer!.seekToNext();
    } else {
      await _player.seekToNext();
    }
    _broadcastCurrentState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (kDebugMode) {
      print('🎵 [AudioHandler] skipToPrevious() 被调用');
    }

    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    } else if (_externalPlayer != null) {
      await _externalPlayer!.seekToPrevious();
    } else {
      await _player.seekToPrevious();
    }
    _broadcastCurrentState();
  }

  void _broadcastCurrentState() {
    // 使用外部播放器状态，如果没有则使用内部播放器
    final activePlayer = _externalPlayer ?? _player;

    if (kDebugMode) {
      print(
        '🎵 [AudioHandler] 广播播放状态: playing=${activePlayer.playing}, processingState=${activePlayer.processingState}',
      );
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          activePlayer.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _mapProcessingState(activePlayer.processingState),
        playing: activePlayer.playing,
        updatePosition: activePlayer.position,
        bufferedPosition: activePlayer.bufferedPosition,
        speed: activePlayer.speed,
        queueIndex: activePlayer.currentIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    // 由 controller 负责
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    // 由 controller 负责
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // 由 controller 负责
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // 由 controller 负责
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // 由 controller 负责
  }

  // 资源释放
  void dispose() {
    _playbackEventSub?.cancel();
    _positionSub?.cancel();
    _processingStateSub?.cancel();
    _audioSessionSub?.cancel();
    _player.dispose();
    if (kDebugMode) {
      print('🎵 [AudioHandler] 资源已释放');
    }
  }
}
