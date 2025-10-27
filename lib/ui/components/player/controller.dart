import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmusic/services/cover_controller.dart';
import 'package:xmusic/services/down_progress_service.dart';
import 'dart:convert';
import 'package:xmusic/services/music_metadata_service.dart';
import 'package:path/path.dart' as p;
import 'package:xmusic/ui/components/cloudmusic.dart' show FileUtils;
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:xmusic/ui/components/player/audiohandler.dart'
    show XMusicAudioHandler;
import 'package:xmusic/services/cache_download_manager.dart';
import 'package:xmusic/ui/components/player/audio_file_util.dart';
import 'package:audio_session/audio_session.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/ui/components/player/audiohandler.dart';
import 'package:xmusic/services/listening_stats_service.dart';

// 播放模式枚举
enum PlayMode {
  listLoop, // 列表循环
  singleLoop, // 单曲循
  shuffle, // 随机播放ƒ√
}

// 2. 工具类：音频文件检查（移到文件顶部）
// 移除原有的 AudioFileUtil 类定义

class PlayerUIController extends GetxController with WidgetsBindingObserver {
  late final AudioPlayer _audioPlayer;
  late final AudioHandler _audioHandler;
  late ConcatenatingAudioSource _playlistSource;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _durationSubscription;
  int _playerStateLogCount = 0; // 添加日志计数器
  DateTime? _lastPlayerStateLog; // 添加防抖时间戳

  // 统计听歌时长
  final ListeningStatsService _listeningStats = ListeningStatsService();
  int _lastCountedSecond = -1; // 去重：只在每个新秒计数一次
  int _pendingListeningSeconds = 0; // 聚合：累计满30秒再落盘

  // 统一的播放状态管理
  final isPlaying = false.obs;

  // 播放进度和时间
  final progress = 0.0.obs;
  final duration = 0.0.obs;

  // 播放列表和索引
  final playlist = <Map<String, dynamic>>[].obs;
  final currentIndex = 0.obs;

  // 获取当前播放的文件ID
  String? get currentPlayingFileId {
    if (playlist.isNotEmpty &&
        currentIndex.value >= 0 &&
        currentIndex.value < playlist.length) {
      final currentTrack = playlist[currentIndex.value];
      return currentTrack['file_id'] ?? currentTrack['id'] ?? '';
    }
    return null;
  }

  // 获取当前播放歌曲的完整信息
  Future<Map<String, dynamic>?> _getCurrentTrackInfo() async {
    if (playlist.isNotEmpty &&
        currentIndex.value >= 0 &&
        currentIndex.value < playlist.length) {
      final currentTrack = playlist[currentIndex.value];
      final coverPath = await getBestCoverPath(currentTrack);
      return {
        'fileId': currentTrack['file_id'] ?? currentTrack['id'] ?? '',
        'title': currentTrack['title'] ?? currentTrack['name'] ?? '未知歌曲',
        'artist': currentTrack['artist'] ?? '未知艺术家',
        'album': currentTrack['album'] ?? '未知专辑',
        'coverPath': coverPath,
      };
    }
    return null;
  }

  // 播放模式
  final currentPlayMode = PlayMode.listLoop.obs;

  // 歌词相关状态
  final lyrics = <LyricLine>[].obs;
  final currentLyric = ''.obs;
  final currentLyricIndex = 0.obs;
  final isLyricsLoading = false.obs;

  // 波形数据
  final waveformData = <double>[].obs;

  // 云盘播放回调
  Function(String fileId, String fileName)? onCloudPlayCallback;

  // 音乐元数据服务
  final MusicMetadataService _metadataService = MusicMetadataService();

  // 歌词更新相关
  double _lastLyricUpdateTime = 0.0;

  // 封面颜色
  final coverColor = Colors.white.obs;

  // 新增：后台播放状态检测
  final RxBool _isInBackground = false.obs;

  // 获取当前是否在后台播放
  bool get isInBackground => _isInBackground.value;

  // 获取后台状态的响应式变量
  RxBool get isInBackgroundObs => _isInBackground;

  // 新增：清理歌词状态的私有方法
  void _clearLyricsState() {
    lyrics.clear();
    currentLyric.value = '';
    currentLyricIndex.value = 0;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).clearLyrics();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 清理 audio_service 歌词失败: $e');
        }
      }
    }
  }

  // 处理播放完成事件
  Future<void> _handleTrackCompletion() async {
    if (playlist.isEmpty) return;

    if (kDebugMode) {
      print('🎵 [Controller] 处理播放完成事件，当前模式: ${currentPlayMode.value}');
    }

    switch (currentPlayMode.value) {
      case PlayMode.listLoop:
        // 如果是最后一首，回到第一首
        if (currentIndex.value >= playlist.length - 1) {
          if (kDebugMode) {
            print('🔄 [Controller] 列表循环：最后一首 -> 第一首');
          }

          // 确保音频会话活跃 - 在切换前激活，确保后台播放正常
          try {
            final session = await AudioSession.instance;
            await session.setActive(true);
            if (kDebugMode) {
              print('🎵 [Controller] 后台播放：确保音频会话活跃');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ [Controller] 音频会话激活失败: $e');
            }
          }

          // 与手动切歌保持一致，直接使用 smartSwitchToTrack
          if (kDebugMode) {
            print('🎵 [Controller] 最后一首到第一首，使用 smartSwitchToTrack 播放');
          }
          await smartSwitchToTrack(0);
          await updatePlaybackState();
          final track = currentTrackInfo;
          if (track != null) {
            final dur = _audioPlayer.duration;
            await setMediaItemForTrack(track, dur);
            // 新增：确保在播放完成时使用正确的信息
            String artistOrLyric = currentLyric.value;
            if (artistOrLyric.isEmpty) {
              artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
            }
            await _pushLyricToMediaItem(artistOrLyric);
          }

          // 再次确保音频会话活跃 - 双重保险
          await AudioSession.instance.then(
            (session) => session.setActive(true),
          );
        } else {
          // 否则播放下一首
          if (kDebugMode) {
            print('⏭️ [Controller] 列表循环：播放下一首');
          }
          // 新增：在循环播放时清理歌词状态
          _clearLyricsState();
          await playTrack(currentIndex.value + 1);
        }
        break;

      case PlayMode.singleLoop:
        // 单曲循环，重新播放当前歌曲
        if (kDebugMode) {
          print('🔁 [Controller] 单曲循环：重新播放当前歌曲');
        }
        // 新增：在单曲循环时清理歌词状态
        _clearLyricsState();
        await playTrack(currentIndex.value);
        break;

      case PlayMode.shuffle:
        // 随机播放，随机选择一首（避开当前歌曲）
        if (playlist.length > 1) {
          int nextIndex;
          do {
            nextIndex = Random().nextInt(playlist.length);
          } while (nextIndex == currentIndex.value);
          if (kDebugMode) {
            print('🎲 [Controller] 随机播放：选择索引 $nextIndex');
          }
          // 新增：在随机播放时清理歌词状态
          _clearLyricsState();
          await playTrack(nextIndex);
        } else {
          // 只有一首歌时重复播放
          if (kDebugMode) {
            print('🔁 [Controller] 随机播放：只有一首歌，重复播放');
          }
          // 新增：在重复播放时清理歌词状态
          _clearLyricsState();
          await playTrack(0);
        }
        break;
    }
  }

  // 时间格式化方法
  String formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) {
      return '00:00:00';
    }

    final totalSeconds = seconds.toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final remainingSeconds = totalSeconds % 60;

    if (hours > 0) {
      // 有小时时显示完整格式：HH:MM:SS
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      // 没有小时时显示：MM:SS
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  // 获取当前播放时间字符串
  String get currentTimeString => formatTime(progress.value);

  // 获取总时长字符串
  String get durationString => formatTime(duration.value);

  // 获取播放进度百分比
  double get progressPercentage => duration.value > 0
      ? (progress.value / duration.value).clamp(0.0, 1.0)
      : 0.0;

  // 获取播放器实际时长（秒）
  double get actualDurationSeconds {
    final actualDuration = _audioPlayer.duration;
    return actualDuration?.inSeconds.toDouble() ?? 0.0;
  }

  // 获取当前歌曲信息
  Map<String, dynamic>? get currentTrackInfo {
    if (playlist.isEmpty ||
        currentIndex.value < 0 ||
        currentIndex.value >= playlist.length) {
      return null;
    }
    return playlist[currentIndex.value];
  }

  // 确保 currentIndex 在有效范围内
  void _ensureValidCurrentIndex() {
    if (playlist.isEmpty) {
      currentIndex.value = 0;
    } else if (currentIndex.value < 0) {
      currentIndex.value = 0;
    } else if (currentIndex.value >= playlist.length) {
      currentIndex.value = playlist.length - 1;
    }
  }

  // 假设 _playlistSource 是 controller 的成员变量，类型为 ConcatenatingAudioSource
  // 在 controller 初始化时已 setAudioSource(_playlistSource)

  Future<void> playTrack(int index, {bool isCached = false}) async {
    // 2024-07-18 修复：手动切歌时立即更新索引，避免跳过
    final previousIndex = currentIndex.value;
    currentIndex.value = index;

    // 新增：当索引改变时立即清理歌词状态，避免显示上一首歌的歌词
    if (previousIndex != index) {
      _clearLyricsState();
    }

    // 2024-07-18 end
    final track = playlist[index];
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final fileName = getAudioFileName(track);
    final cachePath = await getCacheFilePath(fileName, fileId);

    // 缓存触发逻辑：只有在确实是当前播放歌曲且缓存完整时才强制使用本地文件
    if (isCached && index == currentIndex.value) {
      if (await checkCatchandler(
        cachePath,
        expectedSize: track['size'] as int? ?? 0,
      )) {
        if (kDebugMode) print('⭐️ 缓存触发，强制用本地文件: $cachePath');
        // 记录当前进度
        final currentPosition = _audioPlayer.position;
        // 获取本地音频时长
        Duration? audioDuration;
        try {
          final tempPlayer = AudioPlayer();
          audioDuration = await tempPlayer.setFilePath(cachePath);
          await tempPlayer.dispose();
        } catch (_) {}
        // 构建新的 MediaItem，带 duration
        final coverPath = await getBestCoverPath(track);
        final mediaItem = MediaItem(
          id: fileId,
          album: track['album'] ?? '',
          title: track['title'] ?? track['name'] ?? '',
          artist: track['artist'] ?? '',
          artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
          duration: audioDuration,
        );

        // 直接使用缓存文件播放
        final newSource = AudioSource.file(cachePath, tag: mediaItem);
        // 替换 ConcatenatingAudioSource 的 children
        if (kDebugMode) {
          print(
            'xxxxxxxxplayTrack: removeAt/insert 前 sequence: ${_audioPlayer.sequence}',
          );
        }
        await _audioPlayer.stop();
        await _playlistSource.removeAt(index);
        await _playlistSource.insert(index, newSource);
        if (kDebugMode) {
          print(
            'xxxxxxxxplayTrack: removeAt/insert 后 sequence: ${_audioPlayer.sequence}',
          );
        }
        await _audioPlayer.seek(currentPosition, index: index); // 恢复进度
        if (kDebugMode) {
          print(
            'xxxxxxxxplayTrack: seek 后 currentIndex: ${_audioPlayer.currentIndex}',
          );
        }
        if (Platform.isAndroid || Platform.isIOS) {
          await _audioHandler.play();
          // 同步当前 MediaItem 和索引到 audioHandler
          await _audioHandler.updateMediaItem(mediaItem);
          if (_audioHandler is XMusicAudioHandler) {
            (_audioHandler).syncCurrentIndex(index);
          }
        } else {
          await _audioPlayer.play();
        }
        // 通知 audioHandler
        await setMediaItemForTrack(track, audioDuration);
        // 延迟推送歌词到artist
        Future.delayed(Duration(milliseconds: 300), () {
          _pushLyricToMediaItem(currentLyric.value);
        });

        return;
      }
    }

    // 优化：如果当前index和tag已是本地缓存文件，直接return
    final playingIndex = _audioPlayer.currentIndex;
    final sequence = _audioPlayer.sequence;
    if (kDebugMode) {
      print(
        'xxxxxxxxxxxplayTrack: 当前 sequence 长度: ${sequence.length}, 内容: ${sequence}',
      );
    }
    if (kDebugMode) {
      print(
        'xxxxxxxxxxxplayTrack: 当前 playingIndex: ${playingIndex}, 目标 index: ${index}',
      );
    }
    if (playingIndex == index && index < sequence.length) {
      final tag = sequence[index].tag;
      if (tag is MediaItem) {
        final currentPath = tag.extras?['path'] ?? tag.id;
        if (currentPath == cachePath) {
          if (kDebugMode) {
            print('⭐️ 已经是本地缓存文件，无需重复切换');
          }
          if (!_audioPlayer.playing) {
            if (Platform.isAndroid || Platform.isIOS) {
              await _audioHandler.play();
            } else {
              await _audioPlayer.play();
            }
          }
          return;
        }
      }
    }

    final expectedSize = track['size'] as int? ?? 0;
    final cacheManager = CacheDownloadManager();

    await _audioPlayer.stop();

    // 检查缓存文件是否完整
    if (await checkCatchandler(cachePath, expectedSize: expectedSize)) {
      if (kDebugMode) {
        print('🎵 使用本地缓存文件: $cachePath');
      }
      // 获取本地音频时长
      Duration? audioDuration;
      try {
        // 2024-07-18 修复：使用临时 AudioPlayer 获取时长，避免影响主播放器
        final tempPlayer = AudioPlayer();
        audioDuration = await tempPlayer.setFilePath(cachePath);
        await tempPlayer.dispose(); // 及时释放临时播放器
      } catch (_) {}
      // 构建新的 MediaItem，带 duration
      final coverPath = await getBestCoverPath(track);
      final mediaItem = MediaItem(
        id: fileId,
        album: track['album'] ?? '',
        title: track['title'] ?? track['name'] ?? '',
        artist: track['artist'] ?? '',
        artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
        duration: audioDuration,
      );
      // 直接使用缓存文件播放
      final newSource = AudioSource.file(cachePath, tag: mediaItem);
      // 替换 ConcatenatingAudioSource 的 children
      if (kDebugMode) {
        print(
          'xxxxxxxxplayTrack: removeAt/insert 前 sequence: ${_audioPlayer.sequence}',
        );
      }
      await _playlistSource.removeAt(index);
      await _playlistSource.insert(index, newSource);
      if (kDebugMode) {
        print(
          'xxxxxxxxplayTrack: removeAt/insert 后 sequence: ${_audioPlayer.sequence}',
        );
      }
      await _audioPlayer.seek(Duration.zero, index: index);
      if (kDebugMode) {
        print(
          'xxxxxxxxplayTrack: seek 后 currentIndex: ${_audioPlayer.currentIndex}',
        );
      }
      if (Platform.isAndroid || Platform.isIOS) {
        // 先更新 MediaItem，确保系统通知栏显示正确的歌曲信息
        final coverPath = await getBestCoverPath(track);
        await _audioHandler.updateMediaItem(
          MediaItem(
            id: track['file_id'] ?? track['id'] ?? '',
            album: track['album'] ?? '',
            title: track['title'] ?? track['name'] ?? '',
            artist: track['artist'] ?? '',
            artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
            duration: audioDuration,
          ),
        );

        // 同步当前索引
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).syncCurrentIndex(index);
        }

        // 然后开始播放
        await _audioHandler.play();

        // 确保播放状态同步
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).syncExternalPlayerState(_audioPlayer);
        }
      } else {
        await _audioPlayer.play();
      }
      // 通知 audioHandler
      await setMediaItemForTrack(track, audioDuration);
      // 延迟推送歌词到artist
      Future.delayed(Duration(milliseconds: 300), () {
        _pushLyricToMediaItem(currentLyric.value);
      });
      return;
    }

    // 检查是否有不完整的音频文件，优先断点续传
    final file = File(cachePath);
    if (await file.exists()) {
      if (!await checkCatchandler(cachePath, expectedSize: expectedSize)) {
        if (kDebugMode) {
          print('⚠️ 检测到不完整的音频文件，尝试断点续传: $cachePath');
        }
        final url = await getAudioUrlWithCache(track);
        if (url != null) {
          // final task = CacheTask(
          //   fileId: fileId,
          //   url: url,
          //   filePath: cachePath,
          //   expectedSize: expectedSize,
          // );
          final cachePath = await getCacheFilePath(fileName, fileId);
          final task = CacheTask(
            fileId: fileId,
            fileName: fileName,
            url: url,
            filePath: cachePath,
            expectedSize: expectedSize,
          );

          if (!cacheManager.isTaskActive(fileId)) {
            final success = await cacheManager.resumeOrDownloadTask(task);
            if (!success) {
              await file.delete();
              cacheManager.addTask(task);
            }
            await playOnline(track, providedUrl: url);
          } else {
            // 已有任务在进行，不重复操作
            await playOnline(track, providedUrl: url);
          }
        } else {
          if (kDebugMode) {
            print('❌ 无法获取下载链接，无法续传');
          }
          await file.delete();
        }
        // 断点续传或重下后直接返回，等待下次播放时再检测
        return;
      }
    }

    // 没有本地文件，且没有下载任务，才新建任务
    if (!cacheManager.isTaskActive(fileId)) {
      final url = await getAudioUrlWithCache(track);
      if (url != null) {
        // final task = CacheTask(
        //   fileId: fileId,
        //   url: url,
        //   filePath: cachePath,
        //   expectedSize: expectedSize,
        // );
        final cachePath = await getCacheFilePath(fileName, fileId);
        final task = CacheTask(
          fileId: fileId,
          fileName: fileName,
          url: url,
          filePath: cachePath,
          expectedSize: expectedSize,
        );
        cacheManager.addTask(task);
        // 网络播放
        await playOnline(track, providedUrl: url);
        if (kDebugMode) {
          print('BBBBBBBBBBBBBBBBBBBBBBBB$url');
        }
      }
    } else {
      // 有任务在缓存，直接获取下载链接网络播放
      final url = await getAudioUrlWithCache(track);
      if (url != null) {
        await playOnline(track, providedUrl: url);
        if (kDebugMode) {
          print('CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC$url');
        }
      }
    }
  }

  /// 设置当前媒体信息到 audioHandler
  Future<void> setMediaItemForTrack(
    Map<String, dynamic> track,
    Duration? dur,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final fileId = track['file_id'] ?? track['id'] ?? '';
      final coverPath = await getBestCoverPath(track);
      await _audioHandler.updateMediaItem(
        MediaItem(
          id: fileId,
          album: track['album'] ?? '',
          title: track['title'] ?? track['name'] ?? '',
          artist: track['artist'] ?? '',
          artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
          duration: dur,
        ),
      );
    }
  }

  /// 实时同步播放状态到 audioHandler（包括进度、播放/暂停、上一首/下一首控制等）
  Future<void> updatePlaybackState() async {
    // 使用 syncExternalPlayerState 确保状态一致
    if (Platform.isAndroid || Platform.isIOS) {
      if (_audioHandler is XMusicAudioHandler) {
        (_audioHandler).syncExternalPlayerState(_audioPlayer);
      }
    }
  }

  // AudioHandler 响应上一首/下一首的实现
  // 现在直接调用 AudioHandler 的方法，它会通过回调调用 controller 的 next/previous
  Future<void> handleSkipToNext() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _audioHandler.skipToNext();
    } else {
      await next();
    }
  }

  Future<void> handleSkipToPrevious() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _audioHandler.skipToPrevious();
    } else {
      await previous();
    }
  }

  /// 检查缓存文件是否为音频文件且完整
  /// 返回 true 表示文件存在且完整，false 表示不存在或不完整
  // Future<bool> checkCatchandler(String filePath, {int? expectedSize}) async {
  //   final file = File(filePath);
  //   // 1. 判断是否为音频文件
  //   final isAudio = await AudioFileUtil.isAudioFile(file);
  //   if (!isAudio) return false;
  //   if (expectedSize != null) {
  //     final fileSize = await file.length();
  //     const int sizeTolerance = 1024; // 允许1KB误差
  //     if ((fileSize - expectedSize).abs() > sizeTolerance) return false;
  //   }
  //   return true;
  // }

  Future<bool> checkCatchandler(String filePath, {int? expectedSize}) async {
    final file = File(filePath);
    // 1. 判断是否为音频文件
    final isAudio = await AudioFileUtil.isAudioFile(file);
    if (!isAudio) return false;
    // 2. 判断文件大小是否完整（允许1KB误差）
    if (expectedSize != null) {
      final fileSize = await file.length();
      const int sizeTolerance = 1024; // 1KB
      if ((fileSize - expectedSize).abs() > sizeTolerance) return false;
    }
    return true;
  }

  // 只返回本地封面路径，不请求网络封面（避免403错误）
  Future<String> getBestCoverPath(Map<String, dynamic> track) async {
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final fileName = track['title'] ?? track['name'] ?? '';

    // 如果没有fileId，无法进行缓存
    if (fileId.isEmpty) {
      if (kDebugMode) {
        print('🖼️ getBestCoverPath: 没有fileId，无法获取封面');
      }
      return '';
    }
    // 新增：fileName 为空时不保存图片，直接返回
    if (fileName.trim().isEmpty) {
      if (kDebugMode) {
        print('🖼️ getBestCoverPath: fileName 为空，不保存封面 fileId=$fileId');
      }
      return '';
    }

    // 1. 先检查image_cache目录中的本地文件缓存
    final dir = await getApplicationDocumentsDirectory();
    final imageCacheDir = Directory(p.join(dir.path, 'image_cache'));
    final base = FileUtils.getCacheFileName(fileId, fileName);

    for (final ext in ['jpg', 'png', 'jpeg', 'webp']) {
      final localCover = File(p.join(imageCacheDir.path, '$base.$ext'));
      if (await localCover.exists()) {
        // 使用本地封面缓存
        if (kDebugMode) {
          print('🖼️ getBestCoverPath: 找到image_cache中的封面: ${localCover.path}');
        }
        return localCover.path;
      }
    }

    // 2. 兼容旧版本：检查audio_cache目录中的缓存
    final audioCacheDir = Directory(p.join(dir.path, 'audio_cache'));
    for (final ext in ['jpg', 'png', 'jpeg', 'webp']) {
      final localCover = File(p.join(audioCacheDir.path, '$base.$ext'));
      if (await localCover.exists()) {
        // 使用本地封面缓存，并迁移到image_cache
        if (kDebugMode) {
          print('🖼️ getBestCoverPath: 找到audio_cache中的封面，迁移到image_cache');
        }
        // 迁移到image_cache目录
        final newCoverPath = p.join(imageCacheDir.path, '$base.$ext');
        await imageCacheDir.create(recursive: true);
        await localCover.copy(newCoverPath);
        return newCoverPath;
      }
    }

    // 3. 检查ImageCacheService的本地缓存（基于fileId）
    final imageCacheService = ImageCacheService();
    final imageData = await imageCacheService.getFromLocalCache(fileId);
    if (imageData != null && imageData.isNotEmpty) {
      // 保存到image_cache目录
      await imageCacheDir.create(recursive: true); // 确保目录存在
      final imageFile = File(p.join(imageCacheDir.path, '$base.jpg'));
      if (await imageFile.exists()) {
        // 检查文件头是否为图片格式（JPEG/PNG/WEBP）
        final bytes = await imageFile.openRead(0, 8).first;
        final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
        final isPng = bytes[0] == 0x89 && bytes[1] == 0x50;
        final isWebp = String.fromCharCodes(bytes).contains('WEBP');
        if (!(isJpeg || isPng || isWebp)) {
          // 不是图片，删除旧文件
          await imageFile.delete();
        }
      }
      await imageFile.writeAsBytes(imageData);
      if (kDebugMode) {
        print(
          '🖼️ getBestCoverPath: 从ImageCacheService保存封面到image_cache: ${imageFile.path}',
        );
      }

      return imageFile.path;
    }

    return '';
  }

  // 等待音频准备就绪
  Future<void> _waitForAudioReady() async {
    if (_audioPlayer.processingState == ProcessingState.ready) {
      return;
    }

    // 等待音频加载完成，最多等待5秒
    int attempts = 0;
    const maxAttempts = 50; // 5秒 = 50 * 100ms

    while (_audioPlayer.processingState != ProcessingState.ready &&
        attempts < maxAttempts) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
      if (kDebugMode) {
        print(
          '等待音频准备就绪... 状态: ${_audioPlayer.processingState}, 尝试次数: $attempts',
        );
      }
    }

    if (_audioPlayer.processingState != ProcessingState.ready) {
      if (kDebugMode) {
        print('⚠️ 音频准备超时，当前状态: ${_audioPlayer.processingState}');
      }
    } else {
      if (kDebugMode) {
        print('✅ 音频准备就绪');
      }
    }
  }

  // 公共方法：等待音频准备就绪
  Future<void> waitForAudioReady() async {
    await _waitForAudioReady();
  }

  // 直接播放本地文件（用于缓存逻辑）
  Future<void> _playLocalFileDirect(
    String fileId,
    String path,
    String fileName,
  ) async {
    try {
      if (kDebugMode) {
        print('🎵 直接播放本地文件: $path');
      }
      // 用 fileId 精准查找索引
      int targetIndex = playlist.indexWhere(
        (track) => (track['file_id'] ?? track['id'] ?? '') == fileId,
      );
      if (targetIndex < 0 || targetIndex >= playlist.length) {
        if (kDebugMode) {
          print('playlist中未找到本地音频，跳过无缝切换');
        }
        return;
      }

      // 判断当前播放的是否就是这首歌
      // 2024-07-18 修复：允许手动切歌时也能无缝切换，但需要更新索引
      if (currentIndex.value != targetIndex) {
        if (kDebugMode) {
          print('当前播放的不是这首歌，更新索引并继续切换');
        }
        currentIndex.value = targetIndex;
      }
      // 2024-07-18 end

      // 重要：再次验证 fileId 是否匹配当前播放歌曲
      if (currentIndex.value < playlist.length) {
        final currentTrack = playlist[currentIndex.value];
        final currentFileId =
            currentTrack['file_id'] ?? currentTrack['id'] ?? '';
        if (currentFileId != fileId) {
          if (kDebugMode) {
            print('⚠️ fileId 不匹配，当前播放: $currentFileId, 缓存文件: $fileId，跳过切换');
          }
          return;
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 当前索引超出播放列表范围，跳过切换');
        }
        return;
      }

      // 记录当前播放进度
      final currentPosition = _audioPlayer.position;
      await _audioPlayer.stop();

      final track = playlist[targetIndex];
      final coverPath = await getBestCoverPath(track);
      final mediaItem = MediaItem(
        id: fileId,
        album: track['album'] ?? '',
        title: track['title'] ?? track['name'] ?? '',
        artist: track['artist'] ?? '',
        artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
      );
      // 直接使用本地文件播放嘻嘻嘻嘻嘻嘻嘻嘻寻寻寻寻寻寻寻寻寻寻寻寻寻寻寻寻寻
      // 检查是否在后台
      if (isInBackground) {
        print('______________应用当前在后台_____________');
        // 执行后台相关逻辑
      } else {
        print(
          '______________应用当前在前台______________${targetIndex}__${currentIndex.value}xxxxxxx',
        );
        // 执行前台相关逻辑
      }
      final newSource = AudioSource.file(path, tag: mediaItem);
      await _playlistSource.removeAt(targetIndex);
      await _playlistSource.insert(targetIndex, newSource);

      // 修复：只有在无缝切换（同一首歌）时才恢复播放位置
      // 需要同时验证索引和 fileId，确保是同一首歌
      if (currentIndex.value == targetIndex) {
        // 再次验证 fileId 是否匹配当前播放歌曲
        final currentTrack = playlist[currentIndex.value];
        final currentFileId =
            currentTrack['file_id'] ?? currentTrack['id'] ?? '';

        if (currentFileId == fileId) {
          // 无缝切换：恢复之前的播放位置
          await _audioPlayer.seek(currentPosition, index: targetIndex);
          if (kDebugMode) {
            print('⭐️ 无缝切换到本地文件并恢复进度: ${currentPosition.inSeconds}秒');
          }
        } else {
          // fileId 不匹配，从头开始播放
          if (kDebugMode) {
            print('⚠️ 索引相同但 fileId 不匹配，从头开始播放');
          }
        }
      } else {
        // 手动切歌：从头开始播放
        if (kDebugMode) {
          print('⭐️ 切换到本地文件，从头开始播放');
        }
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await _audioHandler.play();
      } else {
        await _audioPlayer.play();
      }

      // 根据播放方式推送歌词
      if (currentIndex.value == targetIndex) {
        final currentTrack = playlist[currentIndex.value];
        final currentFileId =
            currentTrack['file_id'] ?? currentTrack['id'] ?? '';

        if (currentFileId == fileId) {
          // 无缝切换：推送当前歌词位置
          Future.delayed(Duration(milliseconds: 300), () {
            _pushLyricToMediaItem(currentLyric.value);
          });
        } else {
          // fileId 不匹配：从头开始推送歌词
          Future.delayed(Duration(milliseconds: 300), () {
            _pushLyricToMediaItem('');
            currentLyricIndex.value = 0;
          });
        }
      } else {
        // 手动切歌：从头开始推送歌词
        Future.delayed(Duration(milliseconds: 300), () {
          _pushLyricToMediaItem('');
          currentLyricIndex.value = 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ _playLocalFileDirect 错误: $e');
      }
    }
  }

  int? extractOssExpires(String url) {
    final uri = Uri.parse(url);
    final expiresStr = uri.queryParameters['x-oss-expires'];
    if (expiresStr == null) return null;
    return int.tryParse(expiresStr);
  }

  bool isOssUrlExpired(String url) {
    final expires = extractOssExpires(url);
    if (expires == null) return true;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return now > expires;
  }

  Future<void> curlCheckUrl(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      // 可选：添加header
      // request.headers.add('User-Agent', 'curl/7.64.1');
      final response = await request.close();

      if (kDebugMode) {
        print('Status code: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Content-Type: ${response.headers.value('content-type')}');
      }
      if (kDebugMode) {
        print('Content-Length: ${response.headers.value('content-length')}');
      }

      // 只读取前1KB内容，避免下载大文件
      final bytes = await response.fold<List<int>>([], (prev, element) {
        prev.addAll(element);
        return prev;
      });
      if (kDebugMode) {
        print('First 1024 bytes: ${bytes.take(1024).toList()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('curlCheckUrl error: $e');
      }
    }
  }

  String buildAliYunAudioUrl(String originalUrl) {
    Uri uri = Uri.parse(originalUrl);

    // 提取文件名和扩展名
    String? fileName;
    String? extension;
    if (uri.queryParameters.containsKey('response-content-disposition')) {
      final disposition = uri.queryParameters['response-content-disposition']!;
      final regex = RegExp(r"filename\*?=UTF-8''(.+)");
      final match = regex.firstMatch(disposition);
      if (match != null) {
        fileName = Uri.decodeFull(match.group(1)!);
        extension = fileName.split('.').last;
      }
    }

    // 把原始参数都保留，并额外加上 response-content-type
    final newParams = Map<String, String>.from(uri.queryParameters);
    if (extension != null) {
      newParams['response-content-type'] = 'audio/$extension';
    } else {
      newParams['response-content-type'] = 'audio/mpeg'; // 默认
    }

    // 构建新的 URL
    final newUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      queryParameters: newParams,
    );

    return newUri.toString();
  }

  /// 在线播放音频
  Future<void> playOnline(
    Map<String, dynamic> file, {
    String? providedUrl,
    bool retried = false,
  }) async {
    final url = buildAliYunAudioUrl(providedUrl!);
    if (kDebugMode) {
      print('111111111111111111111111$url');
    }
    if (isOssUrlExpired(url)) {
      if (kDebugMode) {
        print('❌ playOnline: 音频URL已过期，自动获取新地址');
      }
      if (retried) {
        if (kDebugMode) {
          print('❌ playOnline: 已重试过一次，仍然失败，放弃播放');
        }
        return;
      }
      final newUrl = await getAudioUrlWithCache(file);
      if (kDebugMode) {
        print('2222222222222222222222222$newUrl');
      }
      if (newUrl == null) {
        if (kDebugMode) {
          print('❌ playOnline: 无法获取新的音频URL');
        }
        return;
      }
      // 只重试一次
      return await playOnline(file, providedUrl: newUrl, retried: true);
    }
    try {
      // 找到对应的播放列表索引
      int targetIndex = -1;
      final fileId = file['file_id'] ?? file['id'] ?? '';
      for (int i = 0; i < playlist.length; i++) {
        final track = playlist[i];
        final tid = track['file_id'] ?? track['id'] ?? '';
        if (tid == fileId) {
          targetIndex = i;
          break;
        }
      }
      if (kDebugMode) {
        print('playOnline: targetIndex=$targetIndex');
      }
      if (kDebugMode) {
        print('playOnline: providedUrl=$url');
      }
      await _audioPlayer.stop();
      final coverPath = await getBestCoverPath(file);
      final mediaItem = MediaItem(
        id: fileId,
        album: file['album'] ?? '',
        title: file['title'] ?? file['name'] ?? '',
        artist: file['artist'] ?? '',
        artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
      );
      if (kDebugMode) {
        print(
          '3333333333333333333333333333playOnline: before AudioSource.uri, url=$providedUrl',
        );
      }
      if (kDebugMode) {
        print('处理过后的真正的播放地址: before AudioSource.uri, url=$url');
      }
      final newSource = AudioSource.uri(Uri.parse(providedUrl), tag: mediaItem);
      // await curlCheckUrl(providedUrl);
      if (kDebugMode) {
        print(
          '4444444444444444444444444444playOnline: after AudioSource.uri, url=$providedUrl',
        );
      }
      if (kDebugMode) {
        print('playOnline: before replace, sequence=${_audioPlayer.sequence}');
      }
      await _playlistSource.removeAt(targetIndex);
      await _playlistSource.insert(targetIndex, newSource);
      if (kDebugMode) {
        print('playOnline: after replace, sequence=${_audioPlayer.sequence}');
      }
      await _audioPlayer.seek(Duration.zero, index: targetIndex);
      if (kDebugMode) {
        print('playOnline: after seek');
      }
      // await _audioPlayer.play(); // 改为通过 AudioHandler 控制
      if (Platform.isAndroid || Platform.isIOS) {
        await _audioHandler.play();
        // 新增：同步当前 MediaItem 和索引到 audioHandler
        final dur = _audioPlayer.duration;
        final coverPath = await getBestCoverPath(file);
        await _audioHandler.updateMediaItem(
          MediaItem(
            id: file['file_id'] ?? file['id'] ?? '',
            album: file['album'] ?? '',
            title: file['title'] ?? file['name'] ?? '',
            artist: file['artist'] ?? '',
            artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
            duration: dur,
          ),
        );
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).syncCurrentIndex(targetIndex);
        }
      } else {
        await _audioPlayer.play();
      }
      if (kDebugMode) {
        print('playOnline: after play');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ playOnline 错误: $e\n$stack');
      }
    }
  }

  // 配置 AudioSession
  Future<void> _configureAudioSession() async {
    try {
      // 移除重复的 AudioSession 配置，因为 main.dart 已经配置过了
      // 只保留事件监听和状态管理
      final session = await AudioSession.instance;

      if (kDebugMode) {
        print('✅ AudioSession 已从 main.dart 配置，跳过重复配置');
      }

      // 新增：记录是否因打断而暂停
      bool _wasInterrupted = false;
      // 监听打断事件
      session.interruptionEventStream.listen((event) {
        if (kDebugMode) {
          print(
            'AudioSession interruption: type= {event.type}, begin= {event.begin}',
          );
        }
        if (event.begin) {
          // 被打断时自动暂停
          if (isPlaying.value) {
            togglePlay();
            _wasInterrupted = true;
          }
        } else {
          // 打断结束，自动恢复播放
          if (_wasInterrupted) {
            togglePlay();
            _wasInterrupted = false;
          }
        }
      });
      // 监听噪音事件（如耳机拔出）
      session.becomingNoisyEventStream.listen((_) {
        if (kDebugMode) {
          print('AudioSession becoming noisy (e.g. headphones disconnected)');
        }
        if (isPlaying.value) {
          togglePlay();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ AudioSession 配置失败: $e');
      }
    }
  }

  // 页面初始化时调用
  @override
  void onInit() async {
    super.onInit();
    _audioPlayer = AudioPlayer();

    // 配置 AudioSession
    await _configureAudioSession();

    // 确保播放器循环模式设置正确
    // 注意：这里先设置一个默认值，后面会根据保存的设置更新
    await _audioPlayer.setLoopMode(LoopMode.all);
    print('🎵 [Controller] 初始化播放器循环模式: ${_audioPlayer.loopMode}');

    // 只在支持的平台上初始化 audio_service
    if (Platform.isAndroid || Platform.isIOS) {
      // _playlistSource = ConcatenatingAudioSource(children: []);
      // await _audioPlayer.setAudioSource(_playlistSource);
      try {
        _audioHandler = await AudioService.init(
          builder: () => XMusicAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.dsnbc.xmusic.channel.audio',
            androidNotificationChannelName: '荧惑音乐',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        );

        // 设置 AudioHandler 的回调函数和外部播放器
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).setCallbacks(
            onNext: () async {
              if (kDebugMode) {
                print('🎵 Controller: AudioHandler requested next track');
              }
              await next();
            },
            onPrevious: () async {
              if (kDebugMode) {
                print('🎵 Controller: AudioHandler requested previous track');
              }
              await previous();
            },
          );
          // 设置外部 AudioPlayer，确保 AudioHandler 操作的是同一个播放器实例
          (_audioHandler).setExternalPlayer(_audioPlayer);

          // 初始化时同步状态到 audio_service
          (_audioHandler).syncExternalPlayerState(_audioPlayer);
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AudioService 初始化失败: $e');
        }
        // 如果 AudioService 初始化失败，继续使用基本的 just_audio
      }
    } else {
      if (kDebugMode) {
        print('ℹ️ 当前平台不支持 AudioService，使用基本播放功能');
      }
    }
    await _loadPlayModeFromPrefs(); // 启动时恢复播放模式
    //监听播放状态
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((
      state,
    ) async {
      final bool wasPlayingBefore = isPlaying.value;
      // 记录状态变化时间（仅用于日志）
      final now = DateTime.now();
      _lastPlayerStateLog = now;
      _playerStateLogCount++;
      if (kDebugMode) {
        print(
          '[2024-07-18 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 10).toString().padLeft(2, '0')}] playerStateStream #$_playerStateLogCount: playing=${state.playing}, processingState=${state.processingState}, currentIndex=${_audioPlayer.currentIndex}, sequence.length=${_audioPlayer.sequence.length}',
        );
      }

      // 更准确的播放状态检查
      bool shouldBePlaying = false;
      if (state.playing) {
        // 只要 playing 为 true，就认为在播放（包括缓冲状态）
        shouldBePlaying = true;
        if (kDebugMode) {
          print('✅ 播放状态确认：正在播放 (processingState=${state.processingState})');
        }
      } else {
        // playing 为 false 时认为没有在播放
        shouldBePlaying = false;
        if (kDebugMode) {
          print(
            '⏸️ 播放状态确认：未播放 (playing=${state.playing}, processingState=${state.processingState})',
          );
        }
      }

      // 立即更新播放状态
      if (isPlaying.value != shouldBePlaying) {
        if (kDebugMode) {
          print(
            '🔄 播放状态更新: ${isPlaying.value} -> $shouldBePlaying (playing=${state.playing}, processingState=${state.processingState})',
          );
        }
        isPlaying.value = shouldBePlaying;

        // 当从播放切换到未播放时，立即落盘剩余的统计秒数
        if (!shouldBePlaying && _pendingListeningSeconds > 0) {
          final trackId = currentPlayingFileId;
          final trackInfo = await _getCurrentTrackInfo();
          _listeningStats.addSeconds(
            seconds: _pendingListeningSeconds,
            trackId: trackId,
            trackInfo: trackInfo,
          );
          _pendingListeningSeconds = 0;
        }

        // 根据播放状态边界触发歌词加载/停止
        try {
          final boController = Get.find<BlurOpacityController>();
          final bool lyricsEnabled = boController.isEnabled.value;
          // 刚从非播放切到播放
          if (!wasPlayingBefore && shouldBePlaying) {
            if (lyricsEnabled && currentLyric.value.isEmpty) {
              await _waitForAudioReady();
              await loadLyrics();
            }
          }
          // 刚从播放切到未播放
          if (wasPlayingBefore && !shouldBePlaying) {
            _clearLyricsState();
            await _pushLyricToMediaItem('');
          }
        } catch (_) {}
      } else {
        if (kDebugMode) {
          print(
            'ℹ️ 播放状态无需更新: ${isPlaying.value} (playing=${state.playing}, processingState=${state.processingState})',
          );
        }
      }

      // 同步到AudioHandler
      if (Platform.isAndroid || Platform.isIOS) {
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).syncExternalPlayerState(_audioPlayer);
        }
      }
      // 同步到 AudioHandler
      // if (Platform.isAndroid || Platform.isIOS) {
      //   if (_audioHandler is XMusicAudioHandler) {
      //     (_audioHandler).syncExternalPlayerState(
      //       _audioPlayer,
      //     );
      //   }
      // }
      switch (state.processingState) {
        case ProcessingState.idle:
          if (kDebugMode) {
            print('播放器空闲');
          }
          break;
        case ProcessingState.loading:
          // 正在加载音频
          // isPlaying.value = false;
          if (kDebugMode) {
            print('正在加载音频...');
          }
          break;
        case ProcessingState.buffering:
          // 正在缓冲
          // isPlaying.value = false;
          if (kDebugMode) {
            print('正在缓冲...');
          }
          break;
        case ProcessingState.ready:
          // 已经可以播放
          // isPlaying.value = true;
          if (kDebugMode) {
            print('可以播放');
          }
          // 2024-07-18 新增：ready 时同步 MediaItem 到 audio_service
          final track = currentTrackInfo;
          if (track != null) {
            final dur = _audioPlayer.duration;
            await setMediaItemForTrack(track, dur);
          }
          // 2024-07-18 end
          break;
        case ProcessingState.completed:
          if (kDebugMode) {
            print('🏁 播放完成事件触发');
            print(
              '🎵 [Controller] 当前索引: ${currentIndex.value}, 播放列表长度: ${playlist.length}',
            );
            print('🎵 [Controller] 播放器循环模式: ${_audioPlayer.loopMode}');
            print('🎵 [Controller] 播放器当前索引: ${_audioPlayer.currentIndex}');
          }
          // 锁屏播放时，确保音频会话保持活跃
          try {
            final session = await AudioSession.instance;
            await session.setActive(true);
            if (kDebugMode) {
              print('🎵 [Controller] 播放完成时确保音频会话活跃');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ [Controller] 音频会话激活失败: $e');
            }
          }
          // await _handleTrackCompletion(); // 直接调用内部方法处理下一首歌播放
          await next();
          break;
      }
    });
    // 新增：监听 playbackEventStream 捕获 native 层错误
    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen((
      event,
    ) async {
      // 检查是否有错误
      if (event.errorCode != null || event.errorMessage != null) {
        if (kDebugMode) {
          print(
            '❌ PlaybackEvent 错误: code=${event.errorCode}, message=${event.errorMessage}',
          );
        }
        // 自动检测并处理完整但无法播放的音频文件
        final currentTrack = currentTrackInfo;
        if (currentTrack != null) {
          final fileId = currentTrack['file_id'] ?? currentTrack['id'] ?? '';
          final fileName = getAudioFileName(currentTrack);
          final cachePath = await getCacheFilePath(fileName, fileId);
          final expectedSize = currentTrack['size'] as int? ?? 0;
          await handleCorruptAudioFile(
            fileId: fileId,
            fileName: fileName,
            filePath: cachePath,
            expectedSize: expectedSize,
            track: currentTrack,
          );
        }
        Fluttertoast.showToast(
          // msg: '播放错误: ${event.errorMessage ?? '未知错误'}',
          msg: '播放失败，请等待缓存完成再尝试播放',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        );
      }

      // 检查异常状态
      if (event.processingState == ProcessingState.idle &&
          event.updatePosition == Duration.zero &&
          event.currentIndex != null) {
        if (kDebugMode) {
          print(
            '⚠️ PlaybackEvent: idle at index ${event.currentIndex}, event: $event',
          );
        }
      }
    });
    //监听播放进度
    _positionSubscription = _audioPlayer.positionStream.listen((
      position,
    ) async {
      progress.value = position.inMilliseconds / 1000.0; // 秒，带小数
      // 听歌时长统计：仅在播放中且每经过一个新秒时累加；每满30秒再落盘
      try {
        if (isPlaying.value) {
          final currentSec = position.inSeconds;
          if (currentSec != _lastCountedSecond) {
            _lastCountedSecond = currentSec;
            _pendingListeningSeconds += 1;
            if (_pendingListeningSeconds >= 30) {
              final trackId = currentPlayingFileId;
              final trackInfo = await _getCurrentTrackInfo();
              _listeningStats.addSeconds(
                seconds: _pendingListeningSeconds,
                trackId: trackId,
                trackInfo: trackInfo,
              );
              _pendingListeningSeconds = 0;
            }
          }
        }
      } catch (_) {}

      // 减少同步频率，只在必要时同步到 audioHandler
      if (Platform.isAndroid || Platform.isIOS) {
        if (_audioHandler is XMusicAudioHandler) {
          // 每秒同步一次，而不是每次位置更新都同步
          if (position.inMilliseconds % 1000 < 100) {
            (_audioHandler).syncExternalPlayerState(_audioPlayer);
          }
        }
      }

      // 优化歌词更新频率
      if (lyrics.isNotEmpty) {
        // 每500ms更新一次歌词，而不是每次位置更新都更新
        if (position.inMilliseconds % 500 < 100) {
          try {
            final boController = Get.find<BlurOpacityController>();
            if (boController.isEnabled.value) {
              _updateLyricsBasedOnProgress(progress.value);
            }
          } catch (e) {
            // 如果获取开关状态失败，默认更新歌词
            _updateLyricsBasedOnProgress(progress.value);
          }
        }
      }
    });

    // 监听播放器当前索引变化（用于同步）
    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((
      index,
    ) async {
      if (index != null && index != currentIndex.value) {
        if (kDebugMode) {
          print('🎵 播放器索引变化:  ${currentIndex.value} -> $index');
        }
        // 切歌前将未落盘的时长计入上一首
        if (_pendingListeningSeconds > 0) {
          final prevTrackId = currentPlayingFileId;
          final trackInfo = await _getCurrentTrackInfo();
          _listeningStats.addSeconds(
            seconds: _pendingListeningSeconds,
            trackId: prevTrackId,
            trackInfo: trackInfo,
          );
          _pendingListeningSeconds = 0;
          _lastCountedSecond = -1;
        }
        currentIndex.value = index;

        // 自动同步 MediaItem 到系统通知栏
        final sequence = _audioPlayer.sequence;
        if (index < sequence.length) {
          final source = sequence[index];
          final mediaItem = source.tag;
          if (mediaItem is MediaItem &&
              (Platform.isAndroid || Platform.isIOS)) {
            await _audioHandler.updateMediaItem(mediaItem);
          }
        }

        // 2024-07-18 新增：根据开关控制歌词加载
        try {
          final boController = Get.find<BlurOpacityController>();
          if (boController.isEnabled.value) {
            if (kDebugMode) {
              print('🎵 歌词开关已启用，开始加载歌词');
            }
            await loadLyrics();
          } else {
            if (kDebugMode) {
              print('🎵 歌词开关已关闭，跳过歌词加载');
            }
            // 清空歌词
            lyrics.clear();
            currentLyric.value = '';
            currentLyricIndex.value = 0;
            // 清除 audio_service 中的歌词
            if (Platform.isAndroid || Platform.isIOS) {
              try {
                if (_audioHandler is XMusicAudioHandler) {
                  (_audioHandler).clearLyrics();
                }
              } catch (e) {
                if (kDebugMode) {
                  print('❌ 清除 audio_service 歌词失败: $e');
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('🎵 获取歌词开关状态失败: $e，默认加载歌词');
          }
          await loadLyrics();
        }
        // 2024-07-18 end
      }
    });
    // 监听 durationStream，自动更新总时长
    _durationSubscription = _audioPlayer.durationStream.listen((d) async {
      if (kDebugMode) {
        print(
          '🎵 durationStream: ${d?.inSeconds}秒, 当前显示时长: ${duration.value}秒',
        );
      }

      if (d != null) {
        duration.value = d.inMilliseconds / 1000.0;
        // duration 变化时同步 MediaItem
        final track = currentTrackInfo;
        if (track != null && (Platform.isAndroid || Platform.isIOS)) {
          final coverPath = await getBestCoverPath(track);
          await _audioHandler.updateMediaItem(
            MediaItem(
              id: track['file_id'] ?? track['id'] ?? '',
              album: track['album'] ?? '',
              title: track['title'] ?? track['name'] ?? '',
              artist: track['artist'] ?? '',
              artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
              duration: d,
            ),
          );
        }
      } else {
        // 只有在当前duration也为0时才重置，避免音频切换时的闪烁
        if (duration.value == 0.0) {
          duration.value = 0.0;
        }
      }
    });
    // 2024-07-18 注释：移除重复的 playerStateStream 监听器，避免重复打印
    // 监听 playerStateStream，ready 时同步 MediaItem 到 audio_service
    // _audioPlayer.playerStateStream.listen((state) async {
    //   if (state.processingState == ProcessingState.ready) {
    //     final track = currentTrackInfo;
    //     if (track != null) {
    //       final dur = _audioPlayer.duration;
    //       await setMediaItemForTrack(track, dur);
    //     }
    //   }
    // });
    // 2024-07-18 end

    _loadWaveform();

    ever(currentIndex, (idx) {
      if (playlist.isNotEmpty && idx >= 0 && idx < playlist.length) {
        final track = playlist[idx];
        final fileId = track['file_id'] ?? track['fileId'] ?? track['id'] ?? '';
        Get.find<CoverController>().updateFileId(fileId);
      }
    });
  }

  @override
  void onClose() {
    // 2024-08-04：优化资源清理
    try {
      // 先落盘统计剩余秒数
      if (_pendingListeningSeconds > 0) {
        final trackId = currentPlayingFileId;
        _listeningStats.addSeconds(
          seconds: _pendingListeningSeconds,
          trackId: trackId,
        );
        _pendingListeningSeconds = 0;
      }
      // 停止播放
      _audioPlayer.stop();

      // 取消所有事件订阅
      _playerStateSubscription?.cancel();
      _positionSubscription?.cancel();
      _playbackEventSubscription?.cancel();
      _currentIndexSubscription?.cancel();
      _durationSubscription?.cancel();

      // 释放播放器资源
      _audioPlayer.dispose();

      // 处理音频处理器
      if (Platform.isAndroid || Platform.isIOS) {
        if (_audioHandler is XMusicAudioHandler) {
          _audioHandler.stop();
          (_audioHandler).dispose();
        }
      }

      // 提交统计到服务端（尽最大努力，静默失败）
      _listeningStats.submitStatsOnExit();

      // 清理音频会话
      AudioSession.instance.then((session) => session.setActive(false));
    } catch (e) {
      if (kDebugMode) {
        print('❌ 资源清理异常: $e');
      }
    }

    super.onClose();
  }

  // 公开方法，用于外部调用（目前未被使用，保留以备将来需要）
  Future<void> handleTrackCompletion() async {
    if (kDebugMode) {
      print('🎵 播放完成，开始自动切歌处理');
    }
    await _handleTrackCompletion(); // 调用内部处理方法
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('🎵 ____________________________________前台');
        _isInBackground.value = false; // 前台
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        print('🎵 ____________________________________后台');
        _isInBackground.value = true; // 后台
        // 切后台前落盘并上报
        try {
          if (_pendingListeningSeconds > 0) {
            final trackId = currentPlayingFileId;
            _listeningStats.addSeconds(
              seconds: _pendingListeningSeconds,
              trackId: trackId,
            );
            _pendingListeningSeconds = 0;
          }
          _listeningStats.submitStatsOnExit();
        } catch (_) {}
        break;
    }
  }

  // 初始化 audio_service

  // 优化的播放/暂停方法
  Future<void> togglePlay() async {
    if (kDebugMode) {
      print(
        'togglePlay called, isPlaying=${isPlaying.value}, processingState=${_audioPlayer.processingState}',
      );
    }

    // 检查播放器是否已准备好
    if (_audioPlayer.processingState == ProcessingState.idle) {
      if (kDebugMode) {
        print('🎵 播放器未加载音频，尝试加载当前索引的音频文件');
      }

      // 如果有播放列表且当前索引有效，尝试加载音频
      if (playlist.isNotEmpty &&
          currentIndex.value >= 0 &&
          currentIndex.value < playlist.length) {
        try {
          await playTrack(currentIndex.value);
          // 加载成功后继续播放
          if (Platform.isAndroid || Platform.isIOS) {
            await _audioHandler.play();
          } else {
            await _audioPlayer.play();
          }
          if (kDebugMode) {
            print('✅ 音频加载成功并开始播放');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 音频加载失败: $e');
          }
          Fluttertoast.showToast(msg: '音频加载失败: $e');
        }
        return;
      } else {
        if (kDebugMode) {
          print('❌ 播放器未加载音频，且没有有效的播放列表');
        }
        Fluttertoast.showToast(msg: '播放器未准备好');
        return;
      }
    }

    // 获取当前实际播放状态
    bool currentPlayingState;
    if (Platform.isAndroid || Platform.isIOS) {
      currentPlayingState = _audioHandler.playbackState.value.playing;
    } else {
      currentPlayingState = _audioPlayer.playing;
    }

    if (currentPlayingState) {
      if (kDebugMode) {
        print('togglePlay: pause');
      }
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          await _audioHandler.pause();
        } else {
          await _audioPlayer.pause();
        }
        if (kDebugMode) {
          print('✅ 暂停成功');
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('❌ pause 异常: $e\n$stack');
        }
        Fluttertoast.showToast(msg: '暂停异常: $e');
        return;
      }
    } else {
      if (kDebugMode) {
        print('togglePlay: play');
      }
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          await _audioHandler.play();
        } else {
          await _audioPlayer.play();
        }
        if (kDebugMode) {
          print('✅ 播放成功');
        }

        // 新增：播放成功后加载歌词
        if (playlist.isNotEmpty &&
            currentIndex.value >= 0 &&
            currentIndex.value < playlist.length) {
          Future.delayed(Duration(milliseconds: 200), () async {
            try {
              final boController = Get.find<BlurOpacityController>();
              if (boController.isEnabled.value) {
                await loadLyrics();
              }
            } catch (e) {
              // 如果获取开关状态失败，不加载歌词
            }
          });
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('❌ play 异常: $e\n$stack');
        }
        Fluttertoast.showToast(msg: '播放异常: $e');
        return;
      }
    }

    // 立即同步状态到 audio_service
    if (Platform.isAndroid || Platform.isIOS) {
      if (_audioHandler is XMusicAudioHandler) {
        (_audioHandler).syncExternalPlayerState(_audioPlayer);
      }
    }
  }

  // 如果需要同步播放状态的逻辑，请使用 updatePlaybackState() 方法

  // 判断指定索引的歌曲是否为本地缓存
  Future<bool> _isCachedFile(int index) async {
    if (index < 0 || index >= playlist.length) return false;
    final track = playlist[index];
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final fileName = getAudioFileName(track);
    final cachePath = await getCacheFilePath(fileName, fileId);
    final expectedSize = track['size'] as int? ?? 0;
    return await checkCatchandler(cachePath, expectedSize: expectedSize);
  }

  // 统一的切歌方法
  Future<void> switchToTrack(int index) async {
    // 新增：立即清理歌词状态，避免显示上一首歌的歌词
    _clearLyricsState();

    await playTrack(index);
    if (Platform.isAndroid || Platform.isIOS) {
      if (_audioHandler is XMusicAudioHandler) {
        (_audioHandler).syncCurrentIndex(index);
      }
    }
    final track = currentTrackInfo;
    if (track != null) {
      final dur = _audioPlayer.duration;
      await setMediaItemForTrack(track, dur);
    }
  }

  // 优化的下一首方法
  Future<void> next() async {
    if (playlist.isEmpty) return;

    // 新增：立即清理歌词状态，避免显示上一首歌的歌词
    _clearLyricsState();

    int baseIndex = currentIndex.value;
    int nextIndex;
    switch (currentPlayMode.value) {
      case PlayMode.listLoop:
        nextIndex = (baseIndex + 1) % playlist.length;
        // 到最后一首，手动切歌时用定位切歌
        // if (baseIndex == playlist.length - 1) {
        //   if (kDebugMode) {
        //     print('======= NEXT 边界，直接切到第一首 =======');
        //   }
        //   await smartSwitchToTrack(nextIndex);
        //   await updatePlaybackState();
        //   final track = currentTrackInfo;
        //   if (track != null) {
        //     final dur = _audioPlayer.duration;
        //     await setMediaItemForTrack(track, dur);
        //     String artistOrLyric = currentLyric.value;
        //     if (artistOrLyric.isEmpty) {
        //       artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        //     }
        //     await _pushLyricToMediaItem(artistOrLyric);
        //   }
        //   await AudioSession.instance.then(
        //     (session) => session.setActive(true),
        //   );
        //   return;
        // }
        break;
      case PlayMode.singleLoop:
        nextIndex = baseIndex;
        break;
      case PlayMode.shuffle:
        nextIndex = Random().nextInt(playlist.length);
        break;
    }
    if (kDebugMode) {
      print('================= NEXT 目标索引: $nextIndex =================');
    }
    final isNextCached = await _isCachedFile(nextIndex);
    if (isNextCached) {
      if (isInBackground) {
        print('______________应用当前在后台_____________');
        // 执行后台相关逻辑
      } else {
        print(
          '______________应用当前在前台______________${nextIndex}____${currentIndex.value}yyyyy',
        );
        // 执行前台相关逻辑
      }
      await _audioPlayer.seekToNext();
      await _audioPlayer.play();
      await updatePlaybackState();
      final track = currentTrackInfo;
      if (track != null) {
        // 切歌后推送进度为0，因为新歌曲刚开始播放
        await setMediaItemForTrack(track, Duration.zero);
        String artistOrLyric = currentLyric.value;
        if (artistOrLyric.isEmpty) {
          artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        }
        await _pushLyricToMediaItem(artistOrLyric);
      }
      await AudioSession.instance.then((session) => session.setActive(true));
    } else {
      await smartSwitchToTrack(nextIndex);
      await updatePlaybackState();
      final track = currentTrackInfo;
      if (track != null) {
        // 切歌后推送进度为0，因为新歌曲刚开始播放
        await setMediaItemForTrack(track, Duration.zero);
        String artistOrLyric = currentLyric.value;
        if (artistOrLyric.isEmpty) {
          artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        }
        await _pushLyricToMediaItem(artistOrLyric);
      }
      await AudioSession.instance.then((session) => session.setActive(true));
    }
  }

  // 优化的上一首方法
  Future<void> previous() async {
    if (playlist.isEmpty) return;

    // 新增：立即清理歌词状态，避免显示上一首歌的歌词
    _clearLyricsState();

    int baseIndex = currentIndex.value;
    int prevIndex;
    switch (currentPlayMode.value) {
      case PlayMode.listLoop:
        prevIndex = (baseIndex - 1 + playlist.length) % playlist.length;
        // 到第一首，手动切歌时用定位切歌
        // if (baseIndex == 0) {
        //   if (kDebugMode) {
        //     print('======= PREV 边界，直接切到最后一首 =======');
        //   }
        //   await smartSwitchToTrack(prevIndex);

        //   await updatePlaybackState();
        //   final track = currentTrackInfo;
        //   if (track != null) {
        //     final dur = _audioPlayer.duration;
        //     await setMediaItemForTrack(track, dur);
        //     String artistOrLyric = currentLyric.value;
        //     if (artistOrLyric.isEmpty) {
        //       artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        //     }
        //     await _pushLyricToMediaItem(artistOrLyric);
        //   }
        //   await AudioSession.instance.then(
        //     (session) => session.setActive(true),
        //   );
        //   return;
        // }
        break;
      case PlayMode.singleLoop:
        prevIndex = baseIndex;
        break;
      case PlayMode.shuffle:
        prevIndex = Random().nextInt(playlist.length);
        break;
    }
    if (kDebugMode) {
      print('================= PREV 目标索引: $prevIndex =================');
    }
    final isPrevCached = await _isCachedFile(prevIndex);
    if (isPrevCached) {
      await _audioPlayer.seekToPrevious();
      await _audioPlayer.play();
      await updatePlaybackState();
      final track = currentTrackInfo;
      if (track != null) {
        // 切歌后推送进度为0，因为新歌曲刚开始播放
        await setMediaItemForTrack(track, Duration.zero);
        String artistOrLyric = currentLyric.value;
        if (artistOrLyric.isEmpty) {
          artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        }
        await _pushLyricToMediaItem(artistOrLyric);
      }
      await AudioSession.instance.then((session) => session.setActive(true));
    } else {
      await smartSwitchToTrack(prevIndex);
      await updatePlaybackState();
      final track = currentTrackInfo;
      if (track != null) {
        // 切歌后推送进度为0，因为新歌曲刚开始播放
        await setMediaItemForTrack(track, Duration.zero);
        String artistOrLyric = currentLyric.value;
        if (artistOrLyric.isEmpty) {
          artistOrLyric = track['artist'] ?? track['album'] ?? '未知艺术家';
        }
        await _pushLyricToMediaItem(artistOrLyric);
      }
      await AudioSession.instance.then((session) => session.setActive(true));
    }
  }

  // 智能切歌方法，自动优先本地、断点续传、网络播放
  Future<void> smartSwitchToTrack(int index) async {
    if (playlist.isEmpty || index < 0 || index >= playlist.length) return;

    // 新增：立即清理歌词状态，避免显示上一首歌的歌词
    _clearLyricsState();

    // 确保音频会话活跃 - 特别是在后台播放时
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      if (kDebugMode) {
        print('🎵 [smartSwitchToTrack] 确保音频会话活跃');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [smartSwitchToTrack] 音频会话激活失败: $e');
      }
    }

    final nextTrack = playlist[index];
    final fileId = nextTrack['file_id'] ?? nextTrack['id'] ?? '';
    final fileName = getAudioFileName(nextTrack);
    final cachePath = await getCacheFilePath(fileName, fileId);
    final expectedSize = nextTrack['size'] as int? ?? 0;
    final cacheManager = CacheDownloadManager();
    final file = File(cachePath);

    // 1. 优先本地完整缓存
    if (await checkCatchandler(cachePath, expectedSize: expectedSize)) {
      if (kDebugMode) {
        print('【智能切歌】本地已缓存完整，优先本地播放: $fileName');
      }
      await _playLocalFileDirect(fileId, cachePath, fileName);
      return;
    }

    // 2. 本地有但不完整，优先断点续传
    if (await file.exists()) {
      if (!await checkCatchandler(cachePath, expectedSize: expectedSize)) {
        if (!cacheManager.isTaskActive(fileId)) {
          final url = await getAudioUrlWithCache(nextTrack);
          if (url != null) {
            final cachePath = await getCacheFilePath(fileName, fileId);
            final task = CacheTask(
              fileId: fileId,
              fileName: fileName,
              url: url,
              filePath: cachePath,
              expectedSize: expectedSize,
            );
            final success = await cacheManager.resumeOrDownloadTask(task);
            if (!success) {
              await file.delete();
              cacheManager.addTask(task);
              if (kDebugMode) {
                print('【智能切歌】断点续传失败，重新新建任务: $fileName');
              }
            } else {
              if (kDebugMode) {
                print('【智能切歌】已断点续传: $fileName');
              }
            }
            await playOnline(nextTrack, providedUrl: url);
            return;
          }
        }
      }
    } else {
      // 3. 没有本地文件，且没有任务才新建
      if (!cacheManager.isTaskActive(fileId)) {
        final url = await getAudioUrlWithCache(nextTrack);
        if (url != null) {
          final cachePath = await getCacheFilePath(fileName, fileId);
          final task = CacheTask(
            fileId: fileId,
            fileName: fileName,
            url: url,
            filePath: cachePath,
            expectedSize: expectedSize,
          );
          cacheManager.addTask(task);
          if (kDebugMode) {
            print('【智能切歌】新建缓存任务: $fileName');
          }
          await playOnline(nextTrack, providedUrl: url);
          return;
        }
      }
    }
    // 兜底：直接切歌（比如 asset 或网络）
    await switchToTrack(index);
  }

  // 后台下载音频文件
  void startPlayerBackgroundDownload(
    String url,
    String fileId,
    String fileName,
  ) {
    // 使用 isolate 在后台下载
    () async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory(p.join(dir.path, 'audio_cache'));

        // 直接使用真实文件名
        final finalFile = File(p.join(cacheDir.path, '$fileId-$fileName'));

        // 使用 HttpClient 直接下载
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();

        final sink = finalFile.openWrite();
        await for (var chunk in response) {
          sink.add(chunk);
        }
        await sink.close();

        // 下载完成
        if (await finalFile.exists()) {
          if (kDebugMode) {
            print(
              '⭐️ _startPlayerBackgroundDownload: 后台下载完成 fileId=$fileId ⭐️',
            );
          }

          // 检查当前播放的是否是同一首歌，如果是则无缝切换到本地文件
          _checkAndSwitchToLocalFile(fileId, fileName, finalFile.path);
        }
      } catch (e) {
        if (kDebugMode) {
          print('_startPlayerBackgroundDownload 错误: $e');
        }
      }
    }();
  }

  // 音频缓存与切换相关方法

  // 检查并切换到本地文件播放（无缝切换）
  void _checkAndSwitchToLocalFile(
    String fileId,
    String fileName,
    String localPath,
  ) {
    if (currentIndex.value < playlist.length) {
      final currentTrack = playlist[currentIndex.value];
      final currentFileId = currentTrack['file_id'] ?? currentTrack['id'] ?? '';
      if (currentFileId == fileId) {
        if (kDebugMode) {
          print('⭐️ _checkAndSwitchToLocalFile: 检测到当前播放歌曲缓存完成，准备无缝切换 ⭐️');
        }
        Future.delayed(Duration(milliseconds: 500), () async {
          try {
            if (currentIndex.value < playlist.length) {
              final checkTrack = playlist[currentIndex.value];
              final checkFileId =
                  checkTrack['file_id'] ?? checkTrack['id'] ?? '';
              if (checkFileId == fileId) {
                final currentPosition = _audioPlayer.position;
                if (kDebugMode) {
                  print(
                    '⭐️ _checkAndSwitchToLocalFile: 当前播放位置: ${currentPosition.inSeconds}秒 ⭐️',
                  );
                }
                await _playLocalFileDirect(fileId, localPath, fileName);
                if (currentPosition.inSeconds > 0) {
                  await Future.delayed(Duration(milliseconds: 200));
                  await _audioPlayer.seek(currentPosition);
                  if (kDebugMode) {
                    print('⭐️ _checkAndSwitchToLocalFile: 无缝切换完成，恢复播放位置 ⭐️');
                  }
                }
              } else {
                if (kDebugMode) {
                  print(
                    '⭐️ _checkAndSwitchToLocalFile: 索引已变化，不再切换 fileId=$fileId, currentFileId=$checkFileId ⭐️',
                  );
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('_checkAndSwitchToLocalFile: 无缝切换失败: $e ⭐️');
            }
          }
        });
      } else {
        if (kDebugMode) {
          print(
            '⭐️ _checkAndSwitchToLocalFile: 当前播放的不是同一首歌，不进行切换 fileId=$fileId, currentFileId=$currentFileId ⭐️',
          );
        }
      }
    }
  }

  // 健壮的 fileId 提取方法
  String extractFileId(dynamic file) {
    if (file is Map) {
      return file['file_id'] ?? file['id'] ?? '';
    }
    return '';
  }

  // 统一的播放方法 - 使用最新的 just_audio API
  Future<void> playLocalAudio(
    String path,
    String fileName, {
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    String? fileId,
  }) async {
    if (kDebugMode) {
      print('👹👹👹👹👹👹👹👹👹👹👹👹👹👹进入了');
    }

    try {
      // 找到对应的播放列表索引
      int targetIndex = -1;
      for (int i = 0; i < playlist.length; i++) {
        if (playlist[i]['path'] == path) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex == -1) {
        // 如果没找到，使用当前索引
        targetIndex = currentIndex.value;
        if (targetIndex >= 0 && targetIndex < playlist.length) {
          playlist[targetIndex]['path'] = path;
        }
      }

      if (targetIndex < 0 || targetIndex >= playlist.length) {
        throw Exception('playlist中未找到本地音频');
      }

      // 使用统一的播放入口
      await playTrack(targetIndex);
    } on PlayerException catch (e) {
      if (kDebugMode) {
        print("PlayerException: code=${e.code}, message=${e.message}");
      }
      throw Exception('播放器错误: ${e.message}');
    } on PlayerInterruptedException catch (e) {
      if (kDebugMode) {
        print("PlayerInterruptedException: ${e.message}");
      }
      throw Exception('播放被中断: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('playLocalAudio: 未知错误: $e');
      }
      throw Exception('播放本地音频失败: $e');
    }
  }

  // 优化的缓存清理方法
  Future<void> cleanIncompleteCache() async {
    try {
      if (kDebugMode) {
        print('⭐️ cleanIncompleteCache: 开始清理不完整的缓存文件 ⭐️');
      }
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
      if (!await cacheDir.exists()) {
        if (kDebugMode) {
          print('⭐️ cleanIncompleteCache: 缓存目录不存在，无需清理 ⭐️');
        }
        return;
      }

      final files = await cacheDir.list().toList();
      int cleanedCount = 0;
      final now = DateTime.now();

      for (final file in files) {
        if (file is File) {
          final fileSize = await file.length();
          final stat = await file.stat();
          final fileName = file.path.split('/').last;

          // 清理条件：小于1MB且24小时未变化
          if (fileSize < 1048576 &&
              now.difference(stat.modified).inHours > 24) {
            try {
              await file.delete();
              cleanedCount++;
              if (kDebugMode) {
                print(
                  '⭐️ cleanIncompleteCache: 删除文件: $fileName (${fileSize} bytes) ⭐️',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                print('cleanIncompleteCache: 删除文件失败: $fileName - $e ⭐️');
              }
            }
          }
        }
      }
      if (kDebugMode) {
        print('⭐️ cleanIncompleteCache: 清理完成，共删除 $cleanedCount 个文件 ⭐️');
      }
    } catch (e) {
      if (kDebugMode) {
        print('cleanIncompleteCache 错误: $e');
      }
    }
  }

  // 检查并切换到完整文件

  // 保存当前播放列表和索引到本地
  Future<void> saveCurrentPlaylistToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_playlist', jsonEncode(playlist));
    await prefs.setInt('last_played_index', currentIndex.value);
    if (kDebugMode) {
      print('⭐️ 保存本地last_playlist=' + jsonEncode(playlist));
    }
    if (playlist.isNotEmpty &&
        currentIndex.value >= 0 &&
        currentIndex.value < playlist.length) {
      if (kDebugMode) {
        print('⭐️ 保存本地当前歌曲信息=' + jsonEncode(playlist[currentIndex.value]));
      }
    }
  }

  // 新增：恢复本地播放列表和索引
  Future<void> loadLastPlayedPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistStr = prefs.getString('last_playlist');

    if (playlistStr != null) {
      final list = (jsonDecode(playlistStr) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isNotEmpty) {
        playlist.assignAll(list);
      }
    }
  }

  // 新增：获取歌词（测试阶段显示QQ和网易云歌词）
  Future<void> loadLyrics() async {
    isLyricsLoading.value = true;
    try {
      final track = playlist[currentIndex.value];
      final title = track['title'] ?? track['name'] ?? '';
      final artist = track['artist'] ?? '';
      final fileId = track['file_id'] ?? track['id'] ?? '';

      // 检查是否有有效的歌曲信息
      if (title.isEmpty && fileId.isEmpty) {
        this.lyrics.clear();
        return;
      }

      final lyricsData = await _metadataService.getLyrics(
        title,
        artist,
        fileId: fileId,
      );

      if (lyricsData != null && lyricsData.isNotEmpty) {
        final parsedLyrics = LyricsParser.parseLrc(lyricsData);
        this.lyrics.assignAll(parsedLyrics);

        // 歌词加载完成后立即更新一次
        _updateLyricsBasedOnProgress(progress.value);

        // 新增：如果当前时间是0，强制设置第一行歌词
        if (progress.value == 0.0 && parsedLyrics.isNotEmpty) {
          currentLyric.value = parsedLyrics[0].text;
          currentLyricIndex.value = 0;
          // 同步初始歌词到 audio_service
          _syncLyricsToAudioService(parsedLyrics[0].text, 0);
        }
      } else {
        // 新增：确保在没有歌词时清空所有歌词相关状态
        lyrics.clear();
        currentLyric.value = '';
        currentLyricIndex.value = 0;
        // 同步空歌词到 audio_service
        _syncLyricsToAudioService('', 0);
      }
    } catch (e) {
      // 新增：确保在异常时也清空所有歌词相关状态
      lyrics.clear();
      currentLyric.value = '';
      currentLyricIndex.value = 0;
      // 同步空歌词到 audio_service
      _syncLyricsToAudioService('', 0);
    } finally {
      isLyricsLoading.value = false;
    }
  }

  // 新增：更新当前歌词（兼容旧接口）
  void updateCurrentLyric() {
    _updateLyricsBasedOnProgress(progress.value);
  }

  // 新增：强制更新歌词高亮（用于调试）
  void forceUpdateLyricHighlight() {
    if (lyrics.isNotEmpty) {
      final index = LyricsParser.getCurrentLyricIndex(lyrics, progress.value);
      final lyric = LyricsParser.getCurrentLyric(lyrics, progress.value);

      currentLyric.value = lyric;
      currentLyricIndex.value = index;
      _lastLyricUpdateTime = progress.value;
    }
  }

  // 新增：获取 audio_service 中的歌词信息
  Map<String, dynamic>? getAudioServiceLyricsInfo() {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (_audioHandler is XMusicAudioHandler) {
          return (_audioHandler).getCurrentLyricsInfo();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 获取 audio_service 歌词信息失败: $e');
        }
      }
    }
    return null;
  }

  // 基于播放进度更新歌词
  void _updateLyricsBasedOnProgress(double currentTime) {
    if (lyrics.isEmpty) {
      return;
    }

    // 避免重复更新相同时间的歌词（放宽时间限制）
    if ((currentTime - _lastLyricUpdateTime).abs() < 0.05) {
      return;
    }

    final index = LyricsParser.getCurrentLyricIndex(lyrics, currentTime);
    final lyric = LyricsParser.getCurrentLyric(lyrics, currentTime);

    // 只有当歌词真正改变时才更新
    if (currentLyric.value != lyric || currentLyricIndex.value != index) {
      currentLyric.value = lyric;
      currentLyricIndex.value = index;
      _lastLyricUpdateTime = currentTime;

      // 减少同步频率，避免卡顿
      // 每2秒同步一次歌词到 audio_service
      _syncLyricsToAudioService(lyric, index);
      // 每3秒推送一次歌词到控制中心
      _pushLyricToMediaItem(lyric);
    }
  }

  // 新增：同步歌词到 audio_service
  void _syncLyricsToAudioService(String currentLyric, int currentLyricIndex) {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (_audioHandler is XMusicAudioHandler) {
          // 转换歌词列表为字符串列表
          final allLyrics = lyrics.map((line) => line.text).toList();

          (_audioHandler).updateLyrics(
            currentLyric,
            currentLyricIndex,
            allLyrics,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 同步歌词到 audio_service 失败: $e');
        }
      }
    }
  }

  // 新增：推送歌词到MediaItem.artist
  Future<void> _pushLyricToMediaItem(String lyric) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final track = currentTrackInfo;
        if (track == null) return;
        final fileId = track['file_id'] ?? track['id'] ?? '';
        final coverPath = await getBestCoverPath(track);
        final dur = _audioPlayer.duration;

        // 如果歌词为空，使用艺术家信息
        String displayText = lyric;
        if (lyric.isEmpty) {
          displayText = track['artist'] ?? track['album'] ?? '未知艺术家';
        }

        await _audioHandler.updateMediaItem(
          MediaItem(
            id: fileId,
            album: track['album'] ?? '',
            title: track['title'] ?? track['name'] ?? '',
            artist: displayText, // 歌词或艺术家信息推送到artist
            artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
            duration: dur,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('推送歌词到MediaItem.artist失败: $e');
        }
      }
    }
  }

  // 清理损坏的缓存文件
  Future<void> cleanCorruptedCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(dir.path, 'audio_cache'));

    if (!await cacheDir.exists()) {
      if (kDebugMode) {
        print('⭐️ cleanCorruptedCache: 缓存目录不存在，无需清理 ⭐️');
      }
      return;
    }

    final files = await cacheDir.list().toList();
    // ignore: unused_local_variable
    int cleanedCount = 0;

    for (final file in files) {
      if (file is File) {
        final fileSize = await file.length();
        final fileName = file.path.split('/').last;

        // 跳过封面图片文件
        if (_isImageFile(fileName)) {
          continue;
        }

        // 检查文件格式
        try {
          final bytes = await file.openRead(0, 4).first;
          final header = String.fromCharCodes(bytes.take(4));

          if (kDebugMode) {
            print('⭐️ cleanCorruptedCache: 检查文件 $fileName, 头部: $header ⭐️');
          }

          // 检查是否是音频文件格式
          final isAudioFile =
              header.startsWith('RIFF') || // WAV
              header.startsWith('ID3') || // MP3
              header.startsWith('fLaC') || // FLAC
              header.startsWith('OggS') || // OGG
              header.startsWith('\xFF\xFB') || // MP3 (无ID3标签)
              header.startsWith('\xFF\xF3') || // MP3 (无ID3标签)
              header.startsWith('\xFF\xF2'); // MP3 (无ID3标签)

          if (!isAudioFile) {
            try {
              await file.delete();
              cleanedCount++;
            } catch (e) {
              if (kDebugMode) {
                print('cleanCorruptedCache: 删除文件失败: $fileName - $e ⭐️');
              }
            }
          }
        } catch (e) {
          // 如果无法读取文件，也删除它
          try {
            await file.delete();
            cleanedCount++;
          } catch (deleteError) {
            if (kDebugMode) {
              print('cleanCorruptedCache: 删除文件失败: $fileName - $deleteError ⭐️');
            }
          }
        }
      }
    }
  }

  /// 清空所有音频缓存文件
  // Future<bool> clearAllCachedFiles() async {
  //   try {
  //     final dir = await getApplicationDocumentsDirectory();
  //     final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
  //     if (await cacheDir.exists()) {
  //       int deletedCount = 0;
  //       int failedCount = 0;

  //       // 先停止当前播放，避免文件被占用
  //       try {
  //         await _audioPlayer.stop();
  //       } catch (e) {
  //         if (kDebugMode) {
  //           print('⭐️ clearAllCachedFiles: 停止播放时出错: $e');
  //         }
  //       }

  //       // 等待一下确保文件释放
  //       await Future.delayed(Duration(milliseconds: 500));

  //       // 只删除音频文件，保留封面图片
  //       await for (final file in cacheDir.list()) {
  //         if (file is File) {
  //           final fileName = file.path.split(Platform.pathSeparator).last;

  //           // 只删除音频文件，保留封面图片
  //           if (!_isImageFile(fileName)) {
  //             try {
  //               await file.delete();
  //               deletedCount++;
  //               if (kDebugMode) {
  //                 print('⭐️ clearAllCachedFiles: 已删除音频文件 $fileName');
  //               }
  //             } catch (deleteError) {
  //               failedCount++;
  //               if (kDebugMode) {
  //                 print(
  //                   '❌ clearAllCachedFiles: 删除文件失败 $fileName: $deleteError',
  //                 );
  //               }
  //             }
  //           }
  //         }
  //       }

  //       if (kDebugMode) {
  //         print(
  //           '⭐️ clearAllCachedFiles: 音频缓存清理完成，成功删除 $deletedCount 个文件，失败 $failedCount 个文件',
  //         );
  //       }

  //       // 如果有文件删除失败，返回 false
  //       return failedCount == 0;
  //     } else {
  //       if (kDebugMode) {
  //         print('⭐️ clearAllCachedFiles: 缓存目录不存在，无需清理');
  //       }
  //     }
  //     return true;
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('❌ clearAllCachedFiles: 清理缓存失败: $e');
  //     }
  //     return false;
  //   }
  // }

  Future<bool> clearAllCachedFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
      if (await cacheDir.exists()) {
        int deletedCount = 0;
        int failedCount = 0;

        // 先停止当前播放，避免文件被占用
        try {
          await _audioPlayer.stop();
        } catch (e) {
          if (kDebugMode) {
            print('⭐️ clearAllCachedFiles: 停止播放时出错: $e');
          }
        }

        // 等待一下确保文件释放
        await Future.delayed(Duration(milliseconds: 500));

        // 获取所有正在下载的 fileId
        final downloadingFileIds = DownProgressService().cacheTasks
            .map((task) => task['fileId']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet();

        // 只删除音频文件，保留封面图片
        await for (final file in cacheDir.list()) {
          if (file is File) {
            final fileName = file.path.split(Platform.pathSeparator).last;

            // 提取 fileId（假设 fileId-xxx.mp3 结构）
            String? fileId;
            if (fileName.contains('-')) {
              fileId = fileName.split('-').first;
            }

            // 跳过正在下载的文件
            if (fileId != null && downloadingFileIds.contains(fileId)) {
              if (kDebugMode) {
                print('⏩ clearAllCachedFiles: 跳过正在下载的文件 $fileName');
              }
              continue;
            }

            // 只删除音频文件，保留封面图片
            if (!_isImageFile(fileName)) {
              try {
                await file.delete();
                deletedCount++;
                if (kDebugMode) {
                  print('⭐️ clearAllCachedFiles: 已删除音频文件 $fileName');
                }
              } catch (deleteError) {
                failedCount++;
                if (kDebugMode) {
                  print(
                    '❌ clearAllCachedFiles: 删除文件失败 $fileName: $deleteError',
                  );
                }
              }
            }
          }
        }

        if (kDebugMode) {
          print(
            '⭐️ clearAllCachedFiles: 音频缓存清理完成，成功删除 $deletedCount 个文件，失败 $failedCount 个文件',
          );
        }

        // 如果有文件删除失败，返回 false
        return failedCount == 0;
      } else {
        if (kDebugMode) {
          print('⭐️ clearAllCachedFiles: 缓存目录不存在，无需清理');
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ clearAllCachedFiles: 清理缓存失败: $e');
      }
      return false;
    }
  }

  /// 获取所有已缓存的音频文件列表
  Future<List<Map<String, dynamic>>> getCachedAudioFiles() async {
    final List<Map<String, dynamic>> files = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
      if (!await cacheDir.exists()) {
        return files;
      }
      await for (final file in cacheDir.list()) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;

          // 过滤掉封面图片文件
          if (_isImageFile(fileName)) {
            continue;
          }

          String? fileId;
          if (fileName.contains('-')) {
            fileId = fileName.split('-').first;
          }
          files.add({
            'fileName': fileName,
            'fileId': fileId ?? '',
            'fullPath': file.path,
            'size': await file.length(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('getCachedAudioFiles: 获取缓存文件失败: $e');
      }
    }
    return files;
  }

  /// 判断是否为图片文件
  bool _isImageFile(String fileName) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.tiff',
    ];
    final lowerFileName = fileName.toLowerCase();
    return imageExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  /// 删除指定缓存音频文件
  Future<bool> deleteCachedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('⭐️ deleteCachedFile: 已删除缓存文件 $filePath');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('⭐️ deleteCachedFile: 文件不存在 $filePath');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('deleteCachedFile: 删除缓存文件失败: $e');
      }
      return false;
    }
  }

  /// 获取音频缓存总大小（格式化字符串）
  Future<String> getCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
      if (!await cacheDir.exists()) {
        return '0 B';
      }
      int totalSize = 0;

      // 计算已完成的缓存文件大小
      await for (final file in cacheDir.list()) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;

          // 只计算音频文件大小，不包括封面图片
          if (!_isImageFile(fileName)) {
            totalSize += await file.length();
          }
        }
      }

      // 加上正在下载的文件大小
      try {
        final cacheManager = CacheDownloadManager();
        final downloadedSize = await cacheManager.getTotalDownloadedSize();
        totalSize += downloadedSize;
      } catch (e) {
        if (kDebugMode) {
          print('getCacheSize: 获取下载中文件大小失败: $e');
        }
      }

      return _formatFileSize(totalSize);
    } catch (e) {
      if (kDebugMode) {
        print('getCacheSize: 获取缓存大小失败: $e');
      }
      return '0 B';
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 补全/恢复缺失的播放器方法
  Future<void> _loadWaveform() async {
    try {
      final track = currentTrackInfo;
      if (track == null) {
        waveformData.assignAll(
          List.generate(150, (_) => Random().nextDouble() * 0.6 + 0.2),
        );
        return;
      }

      final path = track['path'] ?? '';
      if (path.isEmpty) {
        waveformData.assignAll(
          List.generate(150, (_) => Random().nextDouble() * 0.6 + 0.2),
        );
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        waveformData.assignAll(
          List.generate(150, (_) => Random().nextDouble() * 0.6 + 0.2),
        );
        return;
      }

      // 简单模拟真实波形数据
      final fileSize = await file.length();
      final sampleCount = min(150, fileSize ~/ 10000);
      final peaks = List<double>.generate(sampleCount, (i) {
        final base = sin(i / sampleCount * pi * 2) * 0.3 + 0.5;
        return max(0.1, min(1.0, base + Random().nextDouble() * 0.2 - 0.1));
      });

      waveformData.assignAll(peaks);
    } catch (e) {
      waveformData.assignAll(
        List.generate(150, (_) => Random().nextDouble() * 0.6 + 0.2),
      );
    }
  }

  Future<void> seekTo(double position) async {
    try {
      if (kDebugMode) {
        print('🎯 开始跳转到: ${position}秒');
      }

      // 确保位置在有效范围内
      final maxDuration = duration.value > 0
          ? duration.value
          : _audioPlayer.duration?.inSeconds.toDouble() ?? 0.0;

      position = position.clamp(0.0, maxDuration);

      // 更新本地进度值
      progress.value = position;

      // 跳转播放器位置
      if (Platform.isAndroid || Platform.isIOS) {
        await _audioHandler.seek(Duration(seconds: position.toInt()));
      } else {
        await _audioPlayer.seek(Duration(seconds: position.toInt()));
      }

      // 同步 MediaItem
      final track = currentTrackInfo;
      if (track != null) {
        final dur = _audioPlayer.duration;
        await setMediaItemForTrack(track, dur);
      }

      if (kDebugMode) {
        print('✅ 跳转完成，当前位置: ${progress.value}秒');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ seekTo错误: $e');
      }
    }
  }

  Future<void> resetPlaylist(
    List<Map<String, dynamic>> newList, {
    bool isFav = false,
  }) async {
    // 判断两个列表的文件是否能对得上，如果是一样的就不操作
    if (_isPlaylistSame(playlist, newList)) {
      return;
    }
    playlist.assignAll(newList);
    // 同步到 ConcatenatingAudioSource
    final sources = await Future.wait(
      newList.map((track) async {
        final coverPath = await getBestCoverPath(track);
        final mediaItem = MediaItem(
          id: track['file_id'] ?? track['id'] ?? '',
          album: track['album'] ?? '',
          title: track['title'] ?? track['name'] ?? '',
          artist: track['artist'] ?? '',
          artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
        );
        return await getAudioSourceForTrack(track, mediaItem);
      }).toList(),
    );

    // 初始化 ConcatenatingAudioSource
    _playlistSource = ConcatenatingAudioSource(children: sources);
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _audioPlayer
            .setAudioSource(_playlistSource)
            .timeout(Duration(seconds: 5));
      } on TimeoutException catch (e) {
        if (kDebugMode) {
          print('加载歌单超时: $e');
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('加载歌单异常: $e\n$stack');
        }
      }
      // 新增：同步 MediaItem 队列到 audioHandler
      final mediaItems = newList
          .map(
            (track) => MediaItem(
              id: track['file_id'] ?? track['id'] ?? '',
              album: track['album'] ?? '',
              title: track['title'] ?? track['name'] ?? '',
              artist: track['artist'] ?? '',
            ),
          )
          .toList();
      await _audioHandler.updateQueue(mediaItems);
    }
    _ensureValidCurrentIndex(); // 确保 currentIndex 有效
    _loadWaveform();

    // 在播放器初始化后
    if (playlist.isNotEmpty &&
        currentIndex.value >= 0 &&
        currentIndex.value < playlist.length) {
      final track = playlist[currentIndex.value];
      final fileId = track['file_id'] ?? track['fileId'] ?? track['id'] ?? '';
      Get.find<CoverController>().updateFileId(fileId);

      //如果是播放全部，从第一首开始播放
      if (isFav) {
        switchToTrack(0);
      }
    }
  }

  // 判断两个播放列表是否相同
  bool _isPlaylistSame(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final fileIdA = a[i]['file_id'] ?? a[i]['id'] ?? '';
      final fileIdB = b[i]['file_id'] ?? b[i]['id'] ?? '';
      if (fileIdA != fileIdB) return false;
    }
    return true;
  }

  IconData getPlayModeIcon() {
    switch (currentPlayMode.value) {
      case PlayMode.listLoop:
        return CupertinoIcons.repeat;
      case PlayMode.singleLoop:
        return CupertinoIcons.repeat_1;
      case PlayMode.shuffle:
        return CupertinoIcons.shuffle;
    }
  }

  void togglePlayMode() async {
    switch (currentPlayMode.value) {
      case PlayMode.listLoop:
        currentPlayMode.value = PlayMode.singleLoop;
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.setShuffleModeEnabled(false);
        break;
      case PlayMode.singleLoop:
        currentPlayMode.value = PlayMode.shuffle;
        await _audioPlayer.setLoopMode(LoopMode.all);
        await _audioPlayer.setShuffleModeEnabled(true);
        break;
      case PlayMode.shuffle:
        currentPlayMode.value = PlayMode.listLoop;
        await _audioPlayer.setLoopMode(LoopMode.all);
        await _audioPlayer.setShuffleModeEnabled(false);
        break;
    }
    _savePlayModeToPrefs(); // 切换后保存到缓存
  }

  // 文件名过滤工具
  String sanitizeFileName(String input) {
    // 只允许字母、数字、下划线、点、横杠
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  // 获取带后缀的音频文件名
  String getAudioFileName(Map<String, dynamic> track) {
    final name = sanitizeFileName(track['title'] ?? track['name'] ?? '');
    final ext = sanitizeFileName(track['file_extension'] ?? '');
    if (ext.isNotEmpty && !name.endsWith('.$ext')) {
      return '$name.$ext';
    }
    return name;
  }

  // 获取音频直链及过期时间（缓存优先）
  Future<String?> getAudioUrlWithCache(Map<String, dynamic> track) async {
    final fileId = track['file_id'] ?? track['id'] ?? '';
    if (fileId.isEmpty) return null;
    final driveId = track['drive_id'] ?? track['driveId'];
    if (driveId == null) return null;
    final aliyun = AliyunDriveService();
    final urlResp = await aliyun.getDownloadUrl(
      driveId: driveId,
      fileId: fileId,
    );
    if (urlResp == null) return null;
    // 同步到playlist
    final idx = playlist.indexWhere((t) => (t['file_id'] ?? t['id']) == fileId);
    if (idx >= 0) {
      playlist[idx]['audioUrl'] = urlResp;
    }
    return urlResp;
  }

  /// 获取音频播放源：优先本地缓存，否则用占位asset
  Future<AudioSource> getAudioSourceForTrack(
    Map<String, dynamic> track,
    MediaItem mediaItem,
  ) async {
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final fileName = getAudioFileName(track);
    final cachePath = await getCacheFilePath(fileName, fileId);
    if (await checkCatchandler(
      cachePath,
      expectedSize: track['size'] as int?,
    )) {
      // 有本地缓存，优先用本地文件
      return AudioSource.file(cachePath, tag: mediaItem);
    } else {
      // 没有本地缓存，用占位音频
      return AudioSource.asset('assets/audio/space.wav', tag: mediaItem);
    }
  }

  // 优化后的点击播放某一首音乐的方法（带防抖）
  Future<void> onMusicItemTap(int index) async {
    if (index == currentIndex.value && isPlaying.value) {
      if (kDebugMode) {
        print('⏳ 已经是当前播放的歌曲且正在播放，忽略点击');
      }
      return;
    }
    if (kDebugMode) {
      print('⭐️ onMusicItemTap: index=$index');
    }
    await playTrack(index);
  }

  /// 尝试以本地文件直连播放当前索引的曲目
  /// 返回 true 表示已处理（完成本地播放），返回 false 表示未处理（应继续走原有在线/缓存流程）
  Future<bool> tryPlayLocalTrack(int index) async {
    if (index < 0 || index >= playlist.length) return false;
    final track = playlist[index];
    final isLocal =
        (track['is_local'] == true) || (track['drive_id'] == 'local');
    final localPath = (track['path'] as String?) ?? '';
    final hasLocalPath = localPath.isNotEmpty && await File(localPath).exists();
    if (!isLocal && !hasLocalPath) return false;

    try {
      final fileId = track['file_id'] ?? track['id'] ?? '';
      await _audioPlayer.stop();

      // 计算本地文件时长
      Duration? audioDuration;
      try {
        final temp = AudioPlayer();
        audioDuration = await temp.setFilePath(localPath);
        await temp.dispose();
      } catch (_) {}

      final coverPath = await getBestCoverPath(track);
      final mediaItem = MediaItem(
        id: fileId,
        album: track['album'] ?? '',
        title: track['title'] ?? track['name'] ?? '',
        artist: track['artist'] ?? '',
        artUri: coverPath.isNotEmpty ? Uri.file(coverPath) : null,
        duration: audioDuration,
      );

      final newSource = AudioSource.file(localPath, tag: mediaItem);
      await _playlistSource.removeAt(index);
      await _playlistSource.insert(index, newSource);

      // 同步到系统媒体控制
      if (Platform.isAndroid || Platform.isIOS) {
        await _audioHandler.updateMediaItem(mediaItem);
        if (_audioHandler is XMusicAudioHandler) {
          (_audioHandler).syncCurrentIndex(index);
        }
        await _audioHandler.play();
      } else {
        await _audioPlayer.play();
      }

      await setMediaItemForTrack(track, audioDuration);
      Future.delayed(const Duration(milliseconds: 300), () {
        _pushLyricToMediaItem(currentLyric.value);
      });

      if (kDebugMode) {
        print('⭐️ tryPlayLocalTrack: 本地直连播放 $localPath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ tryPlayLocalTrack 本地播放失败，继续走原流程: $e');
      }
      return false;
    }
  }

  // 同步播放列表并处理当前播放索引
  Future<void> syncPlaylistWithCurrentTrack(
    List<Map<String, dynamic>> tracks,
  ) async {
    if (tracks.isEmpty) {
      if (kDebugMode) {
        print('⚠️ 新播放列表为空，不进行同步');
      }
      return;
    }
    List<Map<String, dynamic>> newList = tracks;

    if (newList.isEmpty) {
      if (kDebugMode) {
        print('⚠️ 重建后的播放列表为空，不进行同步');
      }
      return;
    }

    // 获取当前正在播放的歌曲信息（优先从播放器状态获取）
    String? currentPlayingFileId;
    // 方法1：从当前播放索引获取
    if (playlist.isNotEmpty &&
        currentIndex.value >= 0 &&
        currentIndex.value < playlist.length) {
      final currentTrack = playlist[currentIndex.value];
      currentPlayingFileId =
          currentTrack['file_id'] ?? currentTrack['id'] ?? '';
      if (kDebugMode) {
        print('🎵 从当前索引获取播放文件ID: $currentPlayingFileId');
      }
    }
    // 方法2：如果播放器正在播放，从播放器状态获取
    if ((currentPlayingFileId == null || currentPlayingFileId.isEmpty) &&
        isPlaying.value &&
        _audioPlayer.currentIndex != null) {
      final currentIdx = _audioPlayer.currentIndex;
      if (currentIdx != null &&
          currentIdx >= 0 &&
          currentIdx < playlist.length) {
        final currentTrack = playlist[currentIdx];
        currentPlayingFileId =
            currentTrack['file_id'] ?? currentTrack['id'] ?? '';
        if (kDebugMode) {
          print('🎵 从播放器状态获取播放文件ID: $currentPlayingFileId');
        }
      }
    }

    if (kDebugMode) {
      print(
        '🔄 同步播放列表: 当前播放文件ID=$currentPlayingFileId, 新列表长度=${newList.length}',
      );
    }

    // 重置播放列表
    await resetPlaylist(newList, isFav: true);

    // 如果之前有播放的歌曲，尝试在新列表中找到并设置正确的索引
    if (currentPlayingFileId != null && currentPlayingFileId.isNotEmpty) {
      final newIndex = newList.indexWhere((track) {
        final trackFileId = track['file_id'] ?? track['id'] ?? '';
        return trackFileId == currentPlayingFileId;
      });

      if (newIndex != -1) {
        // 找到了当前播放的歌曲，设置正确的索引
        currentIndex.value = newIndex;
        if (kDebugMode) {
          print('✅ 在新列表中找到当前播放歌曲，设置索引为: $newIndex');
        }
      } else {
        // 当前播放的歌曲不在新列表中，重置为第一首
        currentIndex.value = 0;
        if (kDebugMode) {
          print('⚠️ 当前播放歌曲不在新列表中，重置索引为: 0');
        }
      }
    }
  }

  // 预加载下一首（本地优先）
  void setupPreloadNext() {
    // 2024-07-18 注释：移除重复的 currentIndexStream 监听器，避免重复日志
    // _audioPlayer.currentIndexStream.listen((index) async {
    //   if (index == null) return;
    //   final nextIndex = index + 1;
    //   if (nextIndex < playlist.length) {
    //     final t = playlist[nextIndex];
    //     final fileId = t['file_id'] ?? t['id'] ?? '';
    //     final fileName = getAudioFileName(t);
    //     final cachePath = await getCacheFilePath( fileName,fileId);

    //     // 使用与 playTrack 相同的检查逻辑
    //     if (await checkCatchandler(
    //       cachePath,
    //       expectedSize: t['size'] as int?,
    //     )) {
    //       t['path'] = cachePath;
    //       print('🎵 预加载: 使用本地缓存文件');
    //     } else {
    //       final url = await getAudioUrlWithCache(t);
    //       if (url != null) {
    //         t['path'] = url;
    //         print('🎵 预加载: 使用网络URL');
    //       }
    //     }
    //   }
    // });
    // 2024-07-18 end
  }

  // 只替换某一首AudioSource（点击后获取到真实path时用）
  Future<void> replaceAudioSourceAt(int index, String newPath) async {
    // 只保留track和newPath参数逻辑，移除MediaItem相关内容
    final track = (index < playlist.length) ? playlist[index] : null;
    if (track != null) {
      // 这里可以根据需要实现替换逻辑
      // 例如更新playlist[index]['path'] = newPath;
      playlist[index]['path'] = newPath;
    }
  }

  // 保存播放模式到本地缓存
  Future<void> _savePlayModeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('play_mode', currentPlayMode.value.index);
  }

  // 从本地缓存读取播放模式
  Future<void> _loadPlayModeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('play_mode');
    if (idx != null && idx >= 0 && idx < PlayMode.values.length) {
      currentPlayMode.value = PlayMode.values[idx];
      // 同步播放器循环模式
      await _syncPlayModeToPlayer();
    }
  }

  // 同步播放模式到播放器
  Future<void> _syncPlayModeToPlayer() async {
    try {
      switch (currentPlayMode.value) {
        case PlayMode.listLoop:
          await _audioPlayer.setLoopMode(LoopMode.all);
          await _audioPlayer.setShuffleModeEnabled(false);
          if (kDebugMode) {
            print('🎵 [Controller] 同步播放模式: 列表循环 (LoopMode.all)');
          }
          break;
        case PlayMode.singleLoop:
          await _audioPlayer.setLoopMode(LoopMode.one);
          await _audioPlayer.setShuffleModeEnabled(false);
          if (kDebugMode) {
            print('🎵 [Controller] 同步播放模式: 单曲循环 (LoopMode.one)');
          }
          break;
        case PlayMode.shuffle:
          await _audioPlayer.setLoopMode(LoopMode.all);
          await _audioPlayer.setShuffleModeEnabled(true);
          if (kDebugMode) {
            print('🎵 [Controller] 同步播放模式: 随机播放 (LoopMode.all + shuffle)');
          }
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Controller] 同步播放模式失败: $e');
      }
    }
  }

  PlayerUIController() {
    // 监听缓存任务完成，自动更新playlist缓存路径
    CacheDownloadManager().onTaskComplete.listen((completedTask) {
      // 使用 Future.microtask 确保在主线程执行
      Future.microtask(() async {
        if (kDebugMode) {
          print('🎵 缓存任务完成: ${completedTask.fileId}');
        }

        try {
          // 查找播放列表中对应的歌曲
          final trackIndex = playlist.indexWhere((track) {
            final fileId = track['file_id'] ?? track['id'] ?? '';
            return fileId == completedTask.fileId;
          });

          if (trackIndex == -1) {
            if (kDebugMode) {
              print('⚠️ 未找到对应的播放列表项: ${completedTask.fileId}');
            }
            return;
          }

          final track = playlist[trackIndex];
          final cachePath = completedTask.filePath;

          // 验证文件完整性
          if (await checkCatchandler(
            cachePath,
            expectedSize: completedTask.expectedSize,
          )) {
            track['path'] = cachePath;
            if (kDebugMode) {
              print('🎵 下载完成，更新播放源: $cachePath');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ 缓存文件验证失败: $cachePath');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 缓存任务完成处理失败: $e');
          }
        }
      });
    });
  }

  Future<void> handleCorruptAudioFile({
    required String fileId,
    required String fileName,
    required String filePath,
    required int expectedSize,
    required Map<String, dynamic> track,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      final fileSize = await file.length();
      const int sizeTolerance = 1024;
      // 判断文件大小是否完整
      if ((fileSize - expectedSize).abs() <= sizeTolerance) {
        // 再用 isAudioFile 检查文件头
        final isAudio = await AudioFileUtil.isAudioFile(file);
        if (!isAudio) {
          print('⚠️ 文件完整但无法播放，自动删除并重新下载: $filePath');
          await file.delete();
          final cacheManager = CacheDownloadManager();
          if (!cacheManager.isTaskActive(fileId)) {
            // 重新下载
            final url = await getAudioUrlWithCache(track);
            if (url != null) {
              final task = CacheTask(
                fileId: fileId,
                fileName: fileName,
                url: url,
                filePath: filePath,
                expectedSize: expectedSize,
              );
              cacheManager.addTask(task);
            }
          }
        }
      }
    }
  }

  /// 对比 controller.playlist 和传入的列表是否一致
  ///
  /// [targetTracks] 目标列表数组
  /// 返回 true 表示两个列表完全一致，false 表示不一致
  bool isPlaylistConsistent(List<Map<String, dynamic>> targetTracks) {
    // 如果长度不同，直接返回 false
    if (playlist.length != targetTracks.length) {
      return false;
    }

    // 如果其中一个为空，另一个不为空，不一致
    if (playlist.isEmpty || targetTracks.isEmpty) {
      return false;
    }

    // 遍历对比每个元素
    for (int i = 0; i < playlist.length; i++) {
      final playlistTrack = playlist[i];
      final targetTrack = targetTracks[i];

      // 获取唯一标识符
      final playlistFileId =
          playlistTrack['file_id'] ?? playlistTrack['id'] ?? '';
      final targetFileId = targetTrack['file_id'] ?? targetTrack['id'] ?? '';

      // 如果唯一标识符不同，返回 false
      if (playlistFileId != targetFileId) {
        return false;
      }
    }

    // 所有元素都匹配，返回 true
    return true;
  }
}
