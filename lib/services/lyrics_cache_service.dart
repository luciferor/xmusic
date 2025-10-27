import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LyricsCacheService {
  static final LyricsCacheService _instance = LyricsCacheService._internal();
  factory LyricsCacheService() => _instance;
  LyricsCacheService._internal();

  // 内存缓存
  final Map<String, String> _memoryCache = {};

  // 缓存目录
  Directory? _cacheDir;

  // 最大内存缓存数量
  static const int _maxMemoryCacheSize = 200;

  // 最大缓存文件大小 (1MB)
  static const int _maxCacheFileSize = 1 * 1024 * 1024;

  /// 初始化缓存目录
  Future<void> _initCacheDir() async {
    if (_cacheDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/lyrics_cache');

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        if (kDebugMode) {
          print('⭐️ 歌词缓存目录已创建: ${_cacheDir!.path}');
        }
      }
    }
  }

  /// 生成缓存键（优先 fileId）
  String _generateCacheKey({String? fileId, String? title, String? artist}) {
    if (fileId != null && fileId.isNotEmpty) {
      return fileId;
    }
    final key = '${title?.trim() ?? ""}_${artist?.trim() ?? ""}'.toLowerCase();
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  Future<String> _getCacheFilePath({
    String? fileId,
    String? title,
    String? artist,
  }) async {
    await _initCacheDir();
    final cacheKey = _generateCacheKey(
      fileId: fileId,
      title: title,
      artist: artist,
    );
    return '${_cacheDir!.path}/$cacheKey.lrc';
  }

  /// 检查内存缓存
  String? _getFromMemoryCache({String? fileId, String? title, String? artist}) {
    final cacheKey = _generateCacheKey(
      fileId: fileId,
      title: title,
      artist: artist,
    );
    return _memoryCache[cacheKey];
  }

  /// 添加到内存缓存
  void _addToMemoryCache({
    String? fileId,
    String? title,
    String? artist,
    required String lyrics,
  }) {
    final cacheKey = _generateCacheKey(
      fileId: fileId,
      title: title,
      artist: artist,
    );
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[cacheKey] = lyrics;
  }

  /// 检查本地文件缓存
  Future<bool> _isCachedLocally({
    String? fileId,
    String? title,
    String? artist,
  }) async {
    try {
      final filePath = await _getCacheFilePath(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 检查本地歌词缓存失败: $e');
      }
      return false;
    }
  }

  /// 从本地缓存读取
  Future<String?> _getFromLocalCache({
    String? fileId,
    String? title,
    String? artist,
  }) async {
    try {
      final filePath = await _getCacheFilePath(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      final file = File(filePath);
      if (await file.exists()) {
        final data = await file.readAsString();
        if (data.isNotEmpty && data.length <= _maxCacheFileSize) {
          if (kDebugMode) {
            print('⭐️ 从本地缓存读取歌词: $fileId $title - $artist');
          }
          return data;
        } else {
          await file.delete();
          if (kDebugMode) {
            print('⚠️ 删除异常大小的歌词缓存文件: ${data.length} bytes');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 读取本地歌词缓存失败: $e');
      }
    }
    return null;
  }

  /// 保存到本地缓存
  Future<void> _saveToLocalCache({
    String? fileId,
    String? title,
    String? artist,
    required String lyrics,
  }) async {
    try {
      if (lyrics.length > _maxCacheFileSize) {
        if (kDebugMode) {
          print('⚠️ 歌词太大，跳过缓存: ${lyrics.length} bytes');
        }
        return;
      }
      final filePath = await _getCacheFilePath(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      final file = File(filePath);
      await file.writeAsString(lyrics, encoding: utf8);
      if (kDebugMode) {
        print('⭐️ 歌词已缓存到本地: $fileId $title - $artist');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存本地歌词缓存失败: $e');
      }
    }
  }

  /// 获取歌词（优先 fileId）
  Future<String?> getLyrics({
    String? fileId,
    String? title,
    String? artist,
  }) async {
    if ((fileId == null || fileId.isEmpty) && (title == null || title.isEmpty))
      return null;
    try {
      final memoryLyrics = _getFromMemoryCache(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      if (memoryLyrics != null) {
        if (kDebugMode) {
          print('⭐️ 从内存缓存获取歌词: $fileId $title - $artist');
        }
        return memoryLyrics;
      }
      final localLyrics = await _getFromLocalCache(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      if (localLyrics != null) {
        _addToMemoryCache(
          fileId: fileId,
          title: title,
          artist: artist,
          lyrics: localLyrics,
        );
        return localLyrics;
      }
      if (kDebugMode) {
        print('⭐️ 歌词未缓存，需要从网络获取: $fileId $title - $artist');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌词缓存失败: $e');
      }
      return null;
    }
  }

  /// 缓存歌词（优先 fileId）
  Future<void> cacheLyrics({
    String? fileId,
    String? title,
    String? artist,
    required String lyrics,
  }) async {
    if (((fileId == null || fileId.isEmpty) &&
            (title == null || title.isEmpty)) ||
        lyrics.isEmpty)
      return;
    try {
      await _saveToLocalCache(
        fileId: fileId,
        title: title,
        artist: artist,
        lyrics: lyrics,
      );
      _addToMemoryCache(
        fileId: fileId,
        title: title,
        artist: artist,
        lyrics: lyrics,
      );
      if (kDebugMode) {
        print('⭐️ 歌词已缓存: $fileId $title - $artist');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 缓存歌词失败: $e');
      }
    }
  }

  /// 检查歌词是否已缓存
  Future<bool> isLyricsCached({
    String? fileId,
    String? title,
    String? artist,
  }) async {
    if ((fileId == null || fileId.isEmpty) && (title == null || title.isEmpty))
      return false;
    if (_getFromMemoryCache(fileId: fileId, title: title, artist: artist) !=
        null) {
      return true;
    }
    return await _isCachedLocally(fileId: fileId, title: title, artist: artist);
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    if (kDebugMode) {
      print('⭐️ 歌词内存缓存已清除');
    }
  }

  /// 清除本地缓存
  Future<void> clearLocalCache() async {
    try {
      await _initCacheDir();
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create();
        if (kDebugMode) {
          print('⭐️ 歌词本地缓存已清除');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清除歌词本地缓存失败: $e');
      }
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    clearMemoryCache();
    await clearLocalCache();
    if (kDebugMode) {
      print('⭐️ 所有歌词缓存已清除');
    }
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
      if (kDebugMode) {
        print('❌ 获取歌词缓存大小失败: $e');
      }
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
      if (kDebugMode) {
        print('❌ 获取歌词缓存文件数量失败: $e');
      }
      return 0;
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final size = await getCacheSize();
      final count = await getCacheFileCount();
      final memoryCount = _memoryCache.length;

      return {
        'localSize': size,
        'localFileCount': count,
        'memoryCacheCount': memoryCount,
        'totalCacheCount': count + memoryCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌词缓存统计信息失败: $e');
      }
      return {
        'localSize': '0 B',
        'localFileCount': 0,
        'memoryCacheCount': 0,
        'totalCacheCount': 0,
      };
    }
  }
}
