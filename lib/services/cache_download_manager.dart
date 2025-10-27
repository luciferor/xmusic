import 'dart:io';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:queue/queue.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:xmusic/services/down_progress_service.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/ui/components/player/audio_file_util.dart';

// 解析下载链接中的过期时间
DateTime? _parseDownloadUrlExpiry(String url) {
  try {
    final uri = Uri.parse(url);
    final expiryParam = uri.queryParameters['x-oss-expires'];
    if (expiryParam != null) {
      final expiryTimestamp = int.tryParse(expiryParam);
      if (expiryTimestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ 解析下载链接过期时间失败: $e');
    }
  }
  return null;
}

// 检查下载链接是否过期
bool _isDownloadUrlExpired(String url) {
  final expiryTime = _parseDownloadUrlExpiry(url);
  if (expiryTime == null) {
    // 如果无法解析过期时间，默认认为已过期
    return true;
  }

  // 提前5分钟认为过期，避免边界情况
  final now = DateTime.now();
  final bufferTime = Duration(minutes: 5);

  return now.isAfter(expiryTime.subtract(bufferTime));
}

class CacheTask {
  final String fileId;
  final String fileName;
  final String url;
  final String filePath;
  final int expectedSize;
  CacheTask({
    required this.fileId,
    required this.fileName,
    required this.url,
    required this.filePath,
    required this.expectedSize,
  });

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fileName': fileName,
    'url': url,
    'filePath': filePath,
    'expectedSize': expectedSize,
  };

  static CacheTask fromJson(Map<String, dynamic> json) => CacheTask(
    fileId: json['fileId'],
    fileName: json['fileName'],
    url: json['url'],
    filePath: json['filePath'],
    expectedSize: json['expectedSize'],
  );
}

class CacheDownloadManager {
  static final CacheDownloadManager _instance =
      CacheDownloadManager._internal();
  factory CacheDownloadManager() => _instance;
  CacheDownloadManager._internal();

  final Queue _queue = Queue(parallel: 3);
  final Map<String, Future<void>> _activeTasks = {};
  late Box _taskBox;
  final StreamController<CacheTask> _taskCompleteController =
      StreamController.broadcast();
  Stream<CacheTask> get onTaskComplete => _taskCompleteController.stream;

  // 添加任务进度更新流
  final StreamController<void> _taskProgressController =
      StreamController.broadcast();
  Stream<void> get onTaskProgress => _taskProgressController.stream;

  // 下载进度服务
  DownProgressService get _progressService => DownProgressService();

  // 下载速度跟踪
  final Map<String, int> _downloadSpeeds = {};
  final Map<String, DateTime> _lastSpeedUpdate = {};
  final Map<String, int> _lastDownloadedBytes = {};

  // Dio实例，配置重试和超时
  late final Dio _dio;

  Future<void> init() async {
    _taskBox = await Hive.openBox('cache_tasks');

    // 初始化Dio
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    // 添加重试拦截器
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: kDebugMode ? print : null,
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ],
      ),
    );

    await _restoreTasks();
  }

  Future<void> _restoreTasks() async {
    for (var json in _taskBox.values) {
      final task = CacheTask.fromJson(Map<String, dynamic>.from(json));
      if (!_activeTasks.containsKey(task.fileId)) {
        // 恢复任务时初始化进度状态
        try {
          final file = File(task.filePath);
          final fileExists = await file.exists();
          final fileLen = fileExists ? await file.length() : 0;
          if (kDebugMode) {
            print(
              '恢复任务: fileId=${task.fileId}, filePath=${task.filePath}, 文件存在=$fileExists, 已下载=$fileLen, 期望大小=${task.expectedSize}',
            );
          }
          if (fileExists) {
            _progressService.updateProgress(
              task.fileId,
              fileLen / task.expectedSize,
            );
          } else {
            _progressService.updateProgress(task.fileId, 0.0);
          }
        } catch (e) {
          _progressService.updateProgress(task.fileId, 0.0);
        }
        addTask(task);
      }
    }
  }

  Future<void> addTask(CacheTask task) async {
    // 检查本地文件是否存在且未完成
    final file = File(task.filePath);
    if (await file.exists()) {
      final downloaded = await file.length();
      const int sizeTolerance = 1024; // 允许1KB误差
      if ((downloaded - task.expectedSize).abs() <= sizeTolerance) {
        // 文件已完整，无需重新下载
        if (kDebugMode) {
          print('缓存已完整，无需重新下载:  [32m [1m [4m${task.fileId} [0m');
        }
        return;
      }
      if (downloaded < task.expectedSize) {
        // 文件未完成，直接断点续传
        if (kDebugMode) {
          print('断点续传: ${task.fileId}, 已下载: $downloaded/${task.expectedSize}');
        }
        // _queue.add(() => _download(task));
        final future = _queue.add(() => _download(task)).whenComplete(() {
          _activeTasks.remove(task.fileId);
        });
        _activeTasks[task.fileId] = future;
        return;
      }
    }
    if (_activeTasks.containsKey(task.fileId)) return;
    await _taskBox.put(task.fileId, task.toJson());
    final future = _queue.add(() => _download(task)).whenComplete(() {
      _activeTasks.remove(task.fileId);
    });
    _activeTasks[task.fileId] = future;
  }

  Future<void> _download(CacheTask task) async {
    try {
      final file = File(task.filePath);
      // 确保父目录存在
      await file.parent.create(recursive: true);

      // 检查已下载的大小
      int downloaded = await file.exists() ? await file.length() : 0;
      // 断点续传前，truncate到已下载长度，防止重复追加内容
      if (await file.exists()) {
        final raf = await file.open(mode: FileMode.append);
        await raf.truncate(downloaded);
        await raf.close();
      }
      if (kDebugMode) {
        print(
          '下载前: fileId=${task.fileId}, filePath=${task.filePath}, 已下载=$downloaded, 期望大小=${task.expectedSize}',
        );
      }

      // 初始化下载进度
      _progressService.updateProgress(
        task.fileId,
        downloaded / task.expectedSize,
      );

      if (kDebugMode) {
        // print('📥 开始下载: ${task.fileId}, 已下载: $downloaded/${task.expectedSize}');
      }

      // 检查下载链接是否过期
      if (_isDownloadUrlExpired(task.url)) {
        if (kDebugMode) {
          print('🔄 下载链接已过期，重新获取: ${task.fileId}');
        }

        // 获取全局driveId
        final driveId = await AliyunDriveService.getGlobalDriveId();

        if (driveId != null && driveId.isNotEmpty) {
          try {
            // 重新获取下载链接
            final aliyunService = AliyunDriveService();
            final newUrl = await aliyunService.getDownloadUrl(
              driveId: driveId,
              fileId: task.fileId,
            );

            if (newUrl != null && newUrl.isNotEmpty) {
              if (kDebugMode) {
                print('✅ 重新获取下载链接成功: ${task.fileId}');
              }

              // 更新现有任务的下载链接
              // final updatedTask = CacheTask(
              //   fileId: task.fileId,
              //   url: newUrl,
              //   filePath: task.filePath,
              //   expectedSize: task.expectedSize,
              // );

              final cachePath = await getCacheFilePath(
                task.fileName,
                task.fileId,
              );
              final updatedTask = CacheTask(
                fileId: task.fileId,
                fileName: task.fileName,
                url: newUrl,
                filePath: cachePath,
                expectedSize: task.expectedSize,
              );

              // 更新任务存储
              await _taskBox.put(task.fileId, updatedTask.toJson());

              // 继续使用更新后的任务进行下载
              task = updatedTask;
            } else {
              if (kDebugMode) {
                print('❌ 重新获取下载链接失败: ${task.fileId}');
              }
            }
          } catch (refreshError) {
            if (kDebugMode) {
              print('❌ 重新获取下载链接异常: $refreshError');
            }
          }
        } else {
          if (kDebugMode) {
            print('❌ 无法获取全局driveId，无法重新获取下载链接: ${task.fileId}');
          }
        }
      }

      // 使用Dio下载，支持断点续传
      await downloadWithResume(_dio, task.url, task.filePath, downloaded, (
        received,
        total,
      ) {
        final progress = total > 0 ? received / total : 0.0;
        _progressService.updateProgress(task.fileId, progress);

        // 计算下载速度 - 改进版本
        final now = DateTime.now();
        final lastUpdate = _lastSpeedUpdate[task.fileId];
        final lastBytes =
            _lastDownloadedBytes[task.fileId] ?? downloaded; // 使用初始下载量作为基准

        if (lastUpdate != null) {
          final timeDiff = now.difference(lastUpdate).inMilliseconds;
          // 至少间隔500ms才计算速度，避免过于频繁的计算
          if (timeDiff >= 500) {
            final bytesDiff = received - lastBytes;
            if (bytesDiff > 0) {
              // 确保有实际下载
              final speedBytesPerSecond = (bytesDiff * 1000 / timeDiff).round();
              _downloadSpeeds[task.fileId] = speedBytesPerSecond;
            }
            // 更新基准值
            _lastSpeedUpdate[task.fileId] = now;
            _lastDownloadedBytes[task.fileId] = received;
          }
        } else {
          // 第一次计算，初始化基准值
          _lastSpeedUpdate[task.fileId] = now;
          _lastDownloadedBytes[task.fileId] = received;
        }

        // 触发进度更新回调
        _taskProgressController.add(null);
        if (kDebugMode) {
          final percentage = (progress * 100).toStringAsFixed(1);
          // print('📥 ${task.fileId}: $percentage% ($received/$total)');
        }
      });

      // 验证文件大小
      final finalSize = await file.length();
      if (kDebugMode) {
        print(
          '下载后校验: fileId=${task.fileId}, 期望大小=${task.expectedSize}, 实际大小=$finalSize',
        );
      }
      const int sizeTolerance = 1024; // 允许1KB误差
      if ((finalSize - task.expectedSize).abs() <= sizeTolerance) {
        await _taskBox.delete(task.fileId);
        // 下载完成，移除进度和速度数据
        _progressService.removeProgress(task.fileId);
        _downloadSpeeds.remove(task.fileId);
        _lastSpeedUpdate.remove(task.fileId);
        _lastDownloadedBytes.remove(task.fileId);
        if (kDebugMode) {
          print('✅ 下载完成: ${task.fileId}');
        }

        _taskCompleteController.add(task);
      } else if (finalSize == 0) {
        // 明显损坏，0字节才删
        if (await file.exists()) {
          await file.delete();
        }
        _progressService.removeProgress(task.fileId);
        if (kDebugMode) {
          print('❌ 文件为0字节，已删除: ${task.fileId}');
        }
        throw Exception('文件为0字节，已删除');
      } else {
        // 其它情况都保留用于断点续传
        if (kDebugMode) {
          print('⚠️ 文件大小不匹配，保留文件用于断点续传: ${task.fileId}');
        }
        throw Exception('文件大小不匹配');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ 下载失败: ${task.fileId}, 错误: $e');
        print('堆栈: $stack');
      }
      // 下载失败时删除不完整的文件（如果是写入异常/覆盖异常）
      final file = File(task.filePath);
      if (e is FileSystemException ||
          e.toString().contains('write') ||
          e.toString().contains('覆盖') ||
          e.toString().contains('permission')) {
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            print('❌ 检测到写入/覆盖异常，已删除损坏文件: ${task.fileId}');
          }
        }
      }
      // 移除进度
      _progressService.removeProgress(task.fileId);
      rethrow;
    }
  }

  Future<bool> resumeOrDownloadTask(CacheTask task) async {
    try {
      final file = File(task.filePath);
      await file.parent.create(recursive: true);

      int downloaded = await file.exists() ? await file.length() : 0;

      // 初始化下载进度
      _progressService.updateProgress(
        task.fileId,
        downloaded / task.expectedSize,
      );

      if (kDebugMode) {
        print('🔄 断点续传: ${task.fileId}, 已下载: $downloaded/${task.expectedSize}');
      }

      final response = await _dio.download(
        task.url,
        task.filePath,
        options: Options(
          headers: downloaded > 0 ? {'Range': 'bytes=$downloaded-'} : null,
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          final progress = (downloaded + received) / task.expectedSize;
          _progressService.updateProgress(task.fileId, progress);

          if (kDebugMode) {
            final percentage = (progress * 100).toStringAsFixed(1);
            print(
              '🔄 ${task.fileId}: $percentage% (${downloaded + received}/${task.expectedSize})',
            );
          }
        },
      );

      final finalSize = await file.length();
      if (finalSize == task.expectedSize) {
        await _taskBox.delete(task.fileId);
        // 下载完成，移除进度
        _progressService.removeProgress(task.fileId);
        _taskCompleteController.add(task);
        if (kDebugMode) {
          print('✅ 断点续传完成: ${task.fileId}');
        }
        return true;
      }
      // 移除进度
      _progressService.removeProgress(task.fileId);
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 断点续传失败: ${task.fileId}, 错误: $e');
      }
      // 移除进度
      _progressService.removeProgress(task.fileId);
      return false;
    }
  }

  bool isTaskActive(String fileId) => _activeTasks.containsKey(fileId);

  // 获取下载进度
  Future<double> getDownloadProgress(String fileId) async {
    try {
      // 从进度服务获取进度
      return _progressService.getProgress(fileId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取下载进度失败: $e');
      }
      return 0.0;
    }
  }

  // 取消下载任务
  Future<void> cancelTask(String fileId) async {
    if (_activeTasks.containsKey(fileId)) {
      _activeTasks[fileId]?.ignore();
      _activeTasks.remove(fileId);
      await _taskBox.delete(fileId);

      // 删除不完整的文件
      final taskJson = _taskBox.get(fileId);
      if (taskJson != null) {
        final task = CacheTask.fromJson(Map<String, dynamic>.from(taskJson));
        final file = File(task.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // 清理进度状态和速度数据
      _progressService.removeProgress(fileId);
      _downloadSpeeds.remove(fileId);
      _lastSpeedUpdate.remove(fileId);
      _lastDownloadedBytes.remove(fileId);

      if (kDebugMode) {
        print('❌ 取消下载: $fileId');
      }
    }
  }

  // 获取所有缓存任务列表
  Future<List<Map<String, dynamic>>> getCacheTasks() async {
    final List<Map<String, dynamic>> tasks = [];

    // 获取所有任务
    for (var json in _taskBox.values) {
      final task = CacheTask.fromJson(Map<String, dynamic>.from(json));
      final progress = _progressService.getProgress(task.fileId);
      final isActive = _activeTasks.containsKey(task.fileId);

      // 计算已下载大小
      int downloadedSize = 0;
      try {
        final file = File(task.filePath);
        if (await file.exists()) {
          downloadedSize = await file.length();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 获取文件大小失败: $e');
        }
      }

      tasks.add({
        'fileId': task.fileId,
        'fileName': task.fileName,
        'url': task.url,
        'filePath': task.filePath,
        'expectedSize': task.expectedSize,
        'downloadedSize': downloadedSize,
        'progress': progress,
        'isActive': isActive,
        'percentage': (progress * 100).toStringAsFixed(1),
        'downloadSpeed': _downloadSpeeds[task.fileId] ?? 0,
      });
    }

    return tasks;
  }

  // 获取缓存任务总数
  int getTaskCount() {
    return _taskBox.length;
  }

  // 获取活跃任务数
  int getActiveTaskCount() {
    return _activeTasks.length;
  }

  // 计算已下载的总容量
  Future<int> getTotalDownloadedSize() async {
    int totalSize = 0;

    for (var json in _taskBox.values) {
      final task = CacheTask.fromJson(Map<String, dynamic>.from(json));
      try {
        final file = File(task.filePath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 计算总容量时获取文件大小失败: $e');
        }
      }
    }

    return totalSize;
  }

  // 计算期望的总容量
  Future<int> getTotalExpectedSize() async {
    int totalSize = 0;

    for (var json in _taskBox.values) {
      final task = CacheTask.fromJson(Map<String, dynamic>.from(json));
      totalSize += task.expectedSize;
    }

    return totalSize;
  }

  //获取缓存总大小
  Future<int> getCacheSize() async {
    int totalSize = 0;

    try {
      for (var json in _taskBox.values) {
        final task = CacheTask.fromJson(Map<String, dynamic>.from(json));

        // 检查文件是否存在
        final file = File(task.filePath);
        if (await file.exists()) {
          // 如果文件存在，使用实际文件大小
          final fileSize = await file.length();
          totalSize += fileSize;

          if (kDebugMode) {
            print('📁 文件 ${task.fileName} 实际大小: ${_formatFileSize(fileSize)}');
          }
        } else {
          // 如果文件不存在，检查是否有部分下载的文件
          final partialFile = File('${task.filePath}.part');
          if (await partialFile.exists()) {
            final partialSize = await partialFile.length();
            totalSize += partialSize;

            if (kDebugMode) {
              print(
                '📁 部分下载文件 ${task.fileName} 大小: ${_formatFileSize(partialSize)}',
              );
            }
          }
        }
      }

      if (kDebugMode) {
        print('📊 缓存总大小: ${_formatFileSize(totalSize)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取缓存大小失败: $e');
      }
    }

    return totalSize;
  }

  // 格式化文件大小（用于调试输出）
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// 重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Function(String)? logPrint;
  final int retries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.logPrint,
    this.retries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    var extra = err.requestOptions.extra;
    var retryCount = extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && retryCount < retries) {
      extra['retryCount'] = retryCount + 1;

      if (logPrint != null) {
        logPrint!(
          '🔄 重试请求 (${retryCount + 1}/$retries): ${err.requestOptions.uri}',
        );
      }

      await Future.delayed(retryDelays[retryCount]);

      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}

Future<void> downloadWithResume(
  Dio dio,
  String url,
  String filePath,
  int downloaded,
  void Function(int, int)? onReceiveProgress,
) async {
  final file = File(filePath);
  // 断点续传前，强制 truncate 文件到 downloaded 长度，防止多写
  if (await file.exists()) {
    final raf = await file.open(mode: FileMode.append);
    await raf.truncate(downloaded);
    await raf.close();
  }
  final raf = await file.open(mode: FileMode.append);
  int received = 0;
  try {
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: downloaded > 0 ? {'Range': 'bytes=$downloaded-'} : null,
      ),
    );
    final isPartialContent = response.statusCode == 206;
    if (downloaded > 0 && !isPartialContent) {
      // 服务器未返回206，Range无效，删除原有文件重新下载
      await raf.close();
      await file.delete();
      final raf2 = await file.open(mode: FileMode.write);
      final stream = response.data!.stream;
      await for (final chunk in stream) {
        await raf2.writeFrom(chunk);
      }
      await raf2.close();
      return;
    }
    final total = response.headers.value(HttpHeaders.contentRangeHeader) != null
        ? int.tryParse(
                response.headers[HttpHeaders.contentRangeHeader]![0]
                        .split('/')
                        .last ??
                    '',
              ) ??
              0
        : (response.headers[HttpHeaders.contentLengthHeader]?.first != null
              ? int.parse(
                      response.headers[HttpHeaders.contentLengthHeader]!.first,
                    ) +
                    downloaded
              : 0);
    final stream = response.data!.stream;
    await for (final chunk in stream) {
      await raf.writeFrom(chunk);
      received += chunk.length;
      if (onReceiveProgress != null) {
        onReceiveProgress(received + downloaded, total);
      }
    }
  } finally {
    await raf.close();
  }
}
