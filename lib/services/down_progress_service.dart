import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/services/cache_download_manager.dart';
import 'dart:async';
import 'dart:io'; // Added for File
import 'package:path_provider/path_provider.dart'; // Added for getTemporaryDirectory
import 'package:path_provider/path_provider.dart'; // Added for getApplicationDocumentsDirectory

class DownProgressService extends GetxController {
  static final DownProgressService _instance = DownProgressService._internal();
  factory DownProgressService() => _instance;
  DownProgressService._internal();

  DateTime? _lastProgressUpdate;

  // 全局下载进度状态管理
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;

  // 缓存任务列表
  final cacheTasks = <Map<String, dynamic>>[].obs;

  // 总下载大小
  final totalDownloadedSize = '0 B'.obs;
  final totalExpectedSize = '0 B'.obs;

  //缓存总大小
  final cacheTotalSize = '0 B'.obs;

  //音频文件总大小
  final audioTotalSize = '0 B'.obs;

  // 加载状态
  final isLoading = false.obs;

  // 监听器订阅
  StreamSubscription? _taskCompleteSubscription;
  StreamSubscription? _taskProgressSubscription;

  // 防抖机制
  DateTime? _lastRefreshTime;
  static const Duration _refreshDebounce = Duration(milliseconds: 500);

  // 缓存管理器
  CacheDownloadManager get _cacheManager => CacheDownloadManager();

  // 更新下载进度
  void updateProgress(String fileId, double progress) {
    downloadProgress[fileId] = progress.clamp(0.0, 1.0);
  }

  // 移除下载进度
  void removeProgress(String fileId) {
    downloadProgress.remove(fileId);
  }

  // 获取下载进度
  double getProgress(String fileId) {
    return downloadProgress[fileId] ?? 0.0;
  }

  // 检查是否有下载任务
  bool hasDownloadTask(String fileId) {
    return downloadProgress.containsKey(fileId);
  }

  // 清空所有进度
  void clearAllProgress() {
    downloadProgress.clear();
  }

  // 取消下载任务
  Future<void> cancelTask(String fileId) async {
    try {
      await CacheDownloadManager().cancelTask(fileId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 取消下载失败: $e');
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadCacheTasks();
    _setupListeners();
    // 初始化时获取缓存大小
    getCacheTotalSize();
    getAudioTotalSize();
  }

  @override
  void onClose() {
    _taskCompleteSubscription?.cancel();
    _taskProgressSubscription?.cancel();
    super.onClose();
  }

  // 加载缓存任务
  Future<void> _loadCacheTasks() async {
    // 防抖检查
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _refreshDebounce) {
      if (kDebugMode) {
        print('🎵 DownProgressService: 防抖跳过刷新');
      }
      return;
    }
    _lastRefreshTime = now;

    isLoading.value = true;
    try {
      final tasks = await _cacheManager.getCacheTasks();
      final totalDownloaded = await _cacheManager.getTotalDownloadedSize();
      final totalExpected = await _cacheManager.getTotalExpectedSize();

      if (kDebugMode) {
        print('🎵 DownProgressService: 加载任务完成，任务数量: ${tasks.length}');
      }

      cacheTasks.assignAll(tasks);
      totalDownloadedSize.value = _formatFileSize(totalDownloaded);
      totalExpectedSize.value = _formatFileSize(totalExpected);

      // 同时更新缓存总大小
      await getCacheTotalSize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载缓存任务失败: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // 设置监听器
  void _setupListeners() {
    // 取消之前的监听器
    _taskCompleteSubscription?.cancel();
    _taskProgressSubscription?.cancel();

    // 监听任务完成
    _taskCompleteSubscription = _cacheManager.onTaskComplete.listen((
      completedTask,
    ) {
      _loadCacheTasks();
      // 任务完成时更新缓存大小
      getCacheTotalSize();
      getAudioTotalSize();
    });

    // 监听进度更新
    _taskProgressSubscription = _cacheManager.onTaskProgress.listen((_) {
      // 防抖：1000ms 内只刷新一次
      final now = DateTime.now();
      if (_lastProgressUpdate != null &&
          now.difference(_lastProgressUpdate!) < Duration(milliseconds: 1000)) {
        return;
      }
      _lastProgressUpdate = now;
      _loadCacheTasks();
      // 进度更新时也更新缓存大小
      getCacheTotalSize();
      getAudioTotalSize();
    });
  }

  // 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 刷新缓存任务
  Future<void> refreshCacheTasks() async {
    await _loadCacheTasks();
  }

  //获取已缓存总大小
  Future<void> getCacheTotalSize() async {
    try {
      isLoading.value = true;
      int totalSize = 0;
      // 获取缓存目录
      final dir = await getApplicationDocumentsDirectory();
      final audioCacheDir = Directory('${dir.path}/audio_cache');

      if (await audioCacheDir.exists()) {
        // 递归扫描缓存目录中的所有文件
        totalSize = await _scanDirectoryForAllFiles(audioCacheDir);
      }
      cacheTotalSize.value = _formatFileSize(totalSize);
    } catch (e) {
      cacheTotalSize.value = '0 B';
    } finally {
      isLoading.value = false;
    }
  }

  // 递归扫描目录中的所有文件
  Future<int> _scanDirectoryForAllFiles(Directory dir) async {
    int totalSize = 0;
    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          // 计算所有文件的大小，包括音频文件和其他缓存文件
          final fileSize = await entity.length();
          totalSize += fileSize;
        } else if (entity is Directory) {
          // 递归扫描子目录
          totalSize += await _scanDirectoryForAllFiles(entity);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 扫描目录失败: ${dir.path}, 错误: $e');
      }
    }
    return totalSize;
  }

  //获取音频文件总大小
  Future<void> getAudioTotalSize() async {
    try {
      isLoading.value = true;
      int totalSize = 0;
      // 获取缓存目录
      final dir = await getApplicationDocumentsDirectory();
      final audioCacheDir = Directory('${dir.path}/audio_cache');
      if (await audioCacheDir.exists()) {
        // 递归扫描缓存目录中的所有文件
        totalSize = await _scanDirectoryForAudioFiles(audioCacheDir);
      }
      audioTotalSize.value = _formatFileSize(totalSize);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取音频文件总大小失败: $e');
      }
      audioTotalSize.value = '0 B';
    } finally {
      isLoading.value = false;
    }
  }

  // 递归扫描目录中的音频文件
  Future<int> _scanDirectoryForAudioFiles(Directory dir) async {
    int totalSize = 0;
    try {
      final entities = await dir.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          // 检查是否为音频文件
          if (_isAudioFile(entity.path)) {
            final fileSize = await entity.length();
            totalSize += fileSize;
          }
        } else if (entity is Directory) {
          // 递归扫描子目录
          totalSize += await _scanDirectoryForAudioFiles(entity);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 扫描目录失败: ${dir.path}, 错误: $e');
      }
    }
    return totalSize;
  }

  // 检查是否为音频文件
  bool _isAudioFile(String filePath) {
    final audioExtensions = [
      '.mp3',
      '.wav',
      '.flac',
      '.aac',
      '.ogg',
      '.m4a',
      '.wma',
      '.opus',
      '.amr',
      '.3gp',
      '.aiff',
      '.alac',
    ];

    final lowerFilePath = filePath.toLowerCase();
    return audioExtensions.any((ext) => lowerFilePath.endsWith(ext));
  }
}
