import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // 内存缓存
  final Map<String, Uint8List> _memoryCache = {};

  // 缓存目录
  Directory? _cacheDir;

  // 最大内存缓存数量
  static const int _maxMemoryCacheSize = 100;

  // 最大缓存文件大小 (10MB)
  static const int _maxCacheFileSize = 10 * 1024 * 1024;

  // 缓存有效期 (7天)
  static const Duration _cacheValidDuration = Duration(days: 7);

  // 缓存统计
  int _memoryCacheHits = 0;
  int _localCacheHits = 0;
  int _networkDownloads = 0;

  // 阿里云盘服务实例
  final AliyunDriveService _aliyunService = AliyunDriveService();

  // Token刷新标志，防止重复刷新
  bool _isRefreshingToken = false;

  /// 初始化缓存目录
  Future<void> _initCacheDir() async {
    if (_cacheDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/image_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    }
  }

  /// 生成缓存文件名
  String _generateCacheFileName(String key) {
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  Future<String> _getCacheFilePath(String key) async {
    await _initCacheDir();
    final fileName = _generateCacheFileName(key);
    return '${_cacheDir!.path}/$fileName';
  }

  /// 检查内存缓存
  Uint8List? _getFromMemoryCache(String key) {
    return _memoryCache[key];
  }

  /// 公共方法：检查内存缓存
  Uint8List? getFromMemoryCache(String key) {
    return _memoryCache[key];
  }

  /// 添加到内存缓存
  void _addToMemoryCache(String key, Uint8List data) {
    // 如果内存缓存已满，删除最旧的条目
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = data;
  }

  /// 检查本地文件缓存
  Future<bool> _isCachedLocally(String key) async {
    try {
      final filePath = await _getCacheFilePath(key);
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      print('❌ 检查本地缓存失败: $e');
      return false;
    }
  }

  /// 公共方法：检查本地文件缓存
  Future<bool> isCachedLocally(String key) async {
    return await _isCachedLocally(key);
  }

  /// 公共方法：保存图片数据到缓存
  Future<void> saveImageDataToCache(String key, Uint8List data) async {
    try {
      await _saveToLocalCache(key, data);
      _addToMemoryCache(key, data);
      if (kDebugMode) {
        print('⭐️ 图片数据已保存到缓存: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存图片数据到缓存失败: $e');
      }
    }
  }

  /// 从本地缓存读取
  Future<Uint8List?> _getFromLocalCache(String key) async {
    try {
      final filePath = await _getCacheFilePath(key);
      final file = File(filePath);

      if (await file.exists()) {
        // 检查文件是否过期
        final stat = await file.stat();
        final now = DateTime.now();
        final age = now.difference(stat.modified);

        if (age > _cacheValidDuration) {
          // 文件已过期，删除缓存文件
          print('⚠️ 缓存文件已过期，删除: $key (${age.inDays}天前)');
          await file.delete();
          return null;
        }

        final data = await file.readAsBytes();

        // 检查文件大小是否合理
        if (data.length > 0 && data.length <= _maxCacheFileSize) {
          return data;
        } else {
          // 文件大小异常，删除缓存文件
          await file.delete();
        }
      }
    } catch (e) {
      print('❌ 读取本地缓存失败: $e');
    }
    return null;
  }

  /// 公共方法：从本地缓存读取
  Future<Uint8List?> getFromLocalCache(String key) async {
    return await _getFromLocalCache(key);
  }

  /// 保存到本地缓存
  Future<void> _saveToLocalCache(String key, Uint8List data) async {
    try {
      // 检查数据大小
      if (data.length > _maxCacheFileSize) {
        print('⚠️ 图片太大，跳过缓存: ${data.length} bytes');
        return;
      }

      final filePath = await _getCacheFilePath(key);
      final file = File(filePath);

      // 检查文件是否已存在
      if (await file.exists()) {
        print('⭐️ 图片已存在于本地缓存，跳过重复存储: key=$key');
        return;
      }

      await file.writeAsBytes(data);
      print('⭐️ 图片已缓存到本地: key=$key');
    } catch (e) {
      print('❌ 保存本地缓存失败: $e');
    }
  }

  /// 检查是否为阿里云盘图片URL
  bool _isAliyunImageUrl(String url) {
    return url.contains('aliyundrive.net') ||
        url.contains('aliyun.com') ||
        url.contains('security-token=');
  }

  /// 刷新阿里云盘token
  Future<bool> _refreshAliyunToken() async {
    if (_isRefreshingToken) {
      print('⚠️ Token刷新正在进行中，跳过重复请求');
      return false;
    }

    try {
      _isRefreshingToken = true;
      print('🔄 开始刷新阿里云盘token...');

      final success = await _aliyunService.manualRefreshToken();

      if (success) {
        print('✅ 阿里云盘token刷新成功');
        return true;
      } else {
        print('❌ 阿里云盘token刷新失败');
        return false;
      }
    } catch (e) {
      print('❌ 刷新阿里云盘token异常: $e');
      return false;
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// 获取图片数据（支持自定义cacheKey，优先用fileId）
  Future<Uint8List?> getImageData(String url, {String? cacheKey}) async {
    final key = cacheKey ?? url;
    try {
      // 1. 优先检查内存缓存（最快）
      final memoryData = _getFromMemoryCache(key);
      if (memoryData != null) {
        _memoryCacheHits++;
        return memoryData;
      }

      // 2. 检查本地缓存（次快）
      final isCachedLocally = await _isCachedLocally(key);
      if (isCachedLocally) {
        final localData = await _getFromLocalCache(key);
        if (localData != null) {
          // 添加到内存缓存，下次访问更快
          _addToMemoryCache(key, localData);
          _localCacheHits++;
          return localData;
        }
      }

      // 3. 本地没有缓存，从网络下载（最慢）
      return await _handleAliyunImageUrl(url, cacheKey: key);
    } catch (e) {
      print('❌ getImageData 错误: $e');
      return null;
    }
  }

  /// 处理阿里云盘图片URL的特殊逻辑（支持cacheKey）
  Future<Uint8List?> _handleAliyunImageUrl(
    String url, {
    required String cacheKey,
  }) async {
    if (_isAliyunImageUrl(url)) {
      print('⚠️ 检测到阿里云盘图片URL，可能需要特殊处理');
    }
    return await _downloadImageWithRetry(url, cacheKey: cacheKey);
  }

  /// 带重试机制的图片下载（支持cacheKey）
  Future<Uint8List?> _downloadImageWithRetry(
    String url, {
    required String cacheKey,
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
            'Accept-Language': 'zh,en;q=0.9',
            'Cache-Control': 'no-cache',
          },
        );

        if (response.statusCode == 200) {
          final data = response.bodyBytes;

          if (data.length > 0 && data.length <= _maxCacheFileSize) {
            final existingData = await _getFromLocalCache(cacheKey);
            if (existingData != null) {
              _addToMemoryCache(cacheKey, existingData);
              return existingData;
            }
            await _saveToLocalCache(cacheKey, data);
            _addToMemoryCache(cacheKey, data);
            _networkDownloads++;
            return data;
          } else {
            print('❌ 图片数据大小异常: ${data.length} bytes');
            return null;
          }
        } else if (response.statusCode == 403) {
          print('❌ 阿里云盘图片访问被拒绝(403)，可能是令牌过期: $url');
          if (_isAliyunImageUrl(url) && attempt == 1) {
            print('🔄 尝试刷新阿里云盘token...');
            final refreshSuccess = await _refreshAliyunToken();
            if (refreshSuccess) {
              continue;
            }
          }
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          return null;
        } else {
          print('❌ 图片下载失败，状态码: ${response.statusCode}');
          return null;
        }
      } catch (e) {
        print('❌ 图片下载异常 (尝试 $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  /// 预加载图片（支持cacheKey）
  Future<void> preloadImage(String url, {String? cacheKey}) async {
    await getImageData(url, cacheKey: cacheKey);
  }

  /// 预加载多张图片（支持cacheKey）
  Future<void> preloadImages(
    List<String> urls, {
    List<String?>? cacheKeys,
  }) async {
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final key = cacheKeys != null && i < cacheKeys.length
          ? cacheKeys[i]
          : null;
      await preloadImage(url, cacheKey: key);
    }
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    print('⭐️ 内存缓存已清除');
  }

  /// 清除本地缓存
  Future<void> clearLocalCache() async {
    try {
      await _initCacheDir();
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create();
        print('⭐️ 本地缓存已清除');
      }
    } catch (e) {
      print('❌ 清除本地缓存失败: $e');
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    clearMemoryCache();
    await clearLocalCache();
    _resetCacheStats();
    print('⭐️ 所有缓存已清除');
  }

  /// 清除指定URL的缓存
  Future<void> clearCacheForUrl(String url) async {
    try {
      final key = url;

      // 清除内存缓存
      _memoryCache.remove(key);

      // 清除本地缓存
      final filePath = await _getCacheFilePath(key);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('⭐️ 已清除缓存: $url');
      }
    } catch (e) {
      print('❌ 清除指定缓存失败: $e');
    }
  }

  /// 强制刷新头像缓存（当用户修改头像时调用）
  Future<void> refreshAvatarCache(String avatarUrl) async {
    try {
      await clearCacheForUrl(avatarUrl);
      // 重新下载并缓存
      await getImageData(avatarUrl);
      print('⭐️ 头像缓存已刷新: $avatarUrl');
    } catch (e) {
      print('❌ 刷新头像缓存失败: $e');
    }
  }

  /// 重置缓存统计
  void _resetCacheStats() {
    _memoryCacheHits = 0;
    _localCacheHits = 0;
    _networkDownloads = 0;
  }

  /// 获取缓存统计信息
  Map<String, int> getCacheStats() {
    return {
      'memoryHits': _memoryCacheHits,
      'localHits': _localCacheHits,
      'networkDownloads': _networkDownloads,
      'memoryCacheSize': _memoryCache.length,
    };
  }

  /// 打印缓存统计信息
  void printCacheStats() {
    final stats = getCacheStats();
    print('📊 图片缓存统计:');
    print('  内存缓存命中: ${stats['memoryHits']} 次');
    print('  本地缓存命中: ${stats['localHits']} 次');
    print('  网络下载次数: ${stats['networkDownloads']} 次');
    print('  当前内存缓存: ${stats['memoryCacheSize']} 张图片');
  }

  /// 获取缓存大小
  Future<String> getCacheSize() async {
    try {
      await _initCacheDir();
      if (!await _cacheDir!.exists()) {
        return '0 B';
      }

      int totalSize = 0;
      int fileCount = 0;

      await for (final file in _cacheDir!.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }

      return _formatFileSize(totalSize);
    } catch (e) {
      print('❌ 获取缓存大小失败: $e');
      return '0 B';
    }
  }

  /// 获取缓存文件数量
  Future<int> getCacheFileCount() async {
    try {
      await _initCacheDir();
      if (!await _cacheDir!.exists()) {
        return 0;
      }

      int fileCount = 0;
      await for (final file in _cacheDir!.list(recursive: true)) {
        if (file is File) {
          fileCount++;
        }
      }

      return fileCount;
    } catch (e) {
      print('❌ 获取缓存文件数量失败: $e');
      return 0;
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 清理过期缓存（可选功能）
  Future<void> cleanExpiredCache({Duration? maxAge}) async {
    try {
      await _initCacheDir();
      if (!await _cacheDir!.exists()) {
        return;
      }

      final now = DateTime.now();
      final ageLimit = maxAge ?? _cacheValidDuration;
      int cleanedCount = 0;

      await for (final file in _cacheDir!.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age > ageLimit) {
            await file.delete();
            cleanedCount++;
          }
        }
      }

      if (cleanedCount > 0) {
        print('⭐️ 清理了 $cleanedCount 个过期缓存文件');
      }
    } catch (e) {
      print('❌ 清理过期缓存失败: $e');
    }
  }

  /// 获取缓存文件信息（包括过期时间）
  Future<Map<String, dynamic>> getCacheFileInfo(String key) async {
    try {
      final filePath = await _getCacheFilePath(key);
      final file = File(filePath);

      if (await file.exists()) {
        final stat = await file.stat();
        final now = DateTime.now();
        final age = now.difference(stat.modified);
        final isExpired = age > _cacheValidDuration;
        final remainingDays = _cacheValidDuration.inDays - age.inDays;

        return {
          'exists': true,
          'size': stat.size,
          'modified': stat.modified,
          'age': age,
          'isExpired': isExpired,
          'remainingDays': remainingDays > 0 ? remainingDays : 0,
        };
      } else {
        return {'exists': false};
      }
    } catch (e) {
      print('❌ 获取缓存文件信息失败: $e');
      return {'exists': false, 'error': e.toString()};
    }
  }
}
