import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/ui/components/player/audio_file_util.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:xmusic/services/image_cache_service.dart';

class LocalAudioService {
  static LocalAudioService? _instance;
  static LocalAudioService get instance {
    _instance ??= LocalAudioService._internal();
    return _instance!;
  }

  LocalAudioService._internal();

  Directory? _localAudioDir;
  Directory? _imageCacheDir;
  static const String _prefsKey = 'local_audio_tracks';
  static const String _fileHashesKey = 'local_audio_file_hashes';
  
  // 图片缓存服务
  final ImageCacheService _imageCacheService = ImageCacheService();

  /// 获取本地音频目录
  Future<Directory> get localAudioDir async {
    if (_localAudioDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _localAudioDir = Directory('${appDir.path}/local_audios');

      if (!await _localAudioDir!.exists()) {
        await _localAudioDir!.create(recursive: true);
        if (kDebugMode) {
          print('⭐️ 本地音频目录已创建: ${_localAudioDir!.path}');
        }
      }
    }
    return _localAudioDir!;
  }

  /// 获取图片缓存目录
  Future<Directory> get imageCacheDir async {
    if (_imageCacheDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _imageCacheDir = Directory('${appDir.path}/image_cache');

      if (!await _imageCacheDir!.exists()) {
        await _imageCacheDir!.create(recursive: true);
        if (kDebugMode) {
          print('⭐️ 图片缓存目录已创建: ${_imageCacheDir!.path}');
        }
      }
    }
    return _imageCacheDir!;
  }

  /// 保存封面图到本地缓存
  Future<String?> _saveCoverToLocalCache(
    Uint8List coverBytes,
    String fileId,
    String fileName,
  ) async {
    try {
      // 使用ImageCacheService保存封面图，这样CachedImage就能找到
      await _imageCacheService.saveImageDataToCache(fileId, coverBytes);
      
      if (kDebugMode) {
        print('⭐️ 封面图已保存到ImageCacheService: $fileId');
      }
      
      // 返回fileId作为标识，这样CachedImage就能通过cacheKey找到
      return fileId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存封面图到ImageCacheService失败: $e');
      }
      return null;
    }
  }

  /// 计算文件哈希值（用于重复检测）
  Future<String> _calculateFileHash(File file) async {
    try {
      // 读取文件的前1MB和后1MB来计算哈希值，提高性能
      final fileSize = await file.length();
      final int chunkSize = 1024 * 1024; // 1MB
      
      List<int> hashBytes = [];
      
      if (fileSize <= chunkSize * 2) {
        // 文件较小，读取整个文件
        final bytes = await file.readAsBytes();
        hashBytes = bytes;
      } else {
        // 文件较大，读取前1MB和后1MB
        final bytes = await file.readAsBytes();
        hashBytes.addAll(bytes.take(chunkSize)); // 前1MB
        hashBytes.addAll(bytes.skip(fileSize - chunkSize)); // 后1MB
      }
      
      // 简单的哈希算法，实际项目中可以使用更安全的哈希算法
      int hash = 0;
      for (int i = 0; i < hashBytes.length; i++) {
        hash = ((hash << 5) - hash + hashBytes[i]) & 0xFFFFFFFF;
      }
      
      return hash.toRadixString(16).padLeft(8, '0');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 计算文件哈希值失败: $e');
      }
      // 如果哈希计算失败，使用文件名和大小作为备选
      final fileName = p.basename(file.path);
      final fileSize = await file.length();
      return '${fileName}_${fileSize}'.hashCode.toRadixString(16);
    }
  }

  /// 检查文件是否重复
  Future<Map<String, dynamic>> _checkDuplicateFile(File sourceFile, String fileName) async {
    try {
      final existingFiles = await _loadCache();
      final sourceFileSize = await sourceFile.length();
      final sourceFileHash = await _calculateFileHash(sourceFile);
      
      // 1. 检查文件名是否完全相同
      final exactNameMatch = existingFiles.where((file) => 
        file['name'] == fileName
      ).toList();
      
      if (exactNameMatch.isNotEmpty) {
        return {
          'isDuplicate': true,
          'duplicateType': 'exact_name',
          'existingFiles': exactNameMatch,
          'message': '发现同名文件，跳过导入'
        };
      }
      
      // 2. 检查文件大小是否相同
      final sameSizeFiles = existingFiles.where((file) => 
        file['size'] == sourceFileSize
      ).toList();
      
      if (sameSizeFiles.isNotEmpty) {
        // 3. 如果大小相同，进一步检查哈希值
        for (final existingFile in sameSizeFiles) {
          final existingPath = existingFile['path'] as String?;
          if (existingPath != null) {
            final existingFileObj = File(existingPath);
            if (await existingFileObj.exists()) {
              final existingHash = await _calculateFileHash(existingFileObj);
              if (existingHash == sourceFileHash) {
                return {
                  'isDuplicate': true,
                  'duplicateType': 'content_identical',
                  'existingFiles': [existingFile],
                  'message': '发现内容完全相同的文件，跳过导入'
                };
              }
            }
          }
        }
      }
      
      // 4. 检查是否有相似文件名（忽略扩展名）
      final sourceNameWithoutExt = p.basenameWithoutExtension(fileName).toLowerCase();
      final similarNameFiles = existingFiles.where((file) {
        final existingName = p.basenameWithoutExtension(file['name'] as String).toLowerCase();
        return existingName == sourceNameWithoutExt;
      }).toList();
      
      if (similarNameFiles.isNotEmpty) {
        return {
          'isDuplicate': false,
          'duplicateType': 'similar_name',
          'existingFiles': similarNameFiles,
          'message': '发现相似文件名，建议检查后导入',
          'warning': true
        };
      }
      
      return {
        'isDuplicate': false,
        'duplicateType': 'none',
        'existingFiles': [],
        'message': '文件无重复，可以导入'
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 检查重复文件失败: $e');
      }
      return {
        'isDuplicate': false,
        'duplicateType': 'error',
        'existingFiles': [],
        'message': '检查重复文件时出错，建议手动确认'
      };
    }
  }

  /// 选择并导入音频文件
  Future<List<Map<String, dynamic>>> importAudioFiles() async {
    try {
      if (kDebugMode) {
        print('⭐️ 开始选择音频文件...');
      }
      
      // 使用自定义类型，显式包含 flac 等格式，解决 Windows 下对 FileType.audio 过滤不全的问题
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'mp3',
          'flac',
          'wav',
          'aac',
          'ogg',
          'm4a',
          'ape',
          'alac',
          'wma',
          'amr',
          'aiff',
          'au',
          'opus',
          'mid',
          'midi',
        ],
        allowMultiple: true,
        // ignore: deprecated_member_use
        allowCompression: false,
      );

      if (kDebugMode) {
        print('⭐️ 文件选择结果: ${result?.files.length ?? 0} 个文件');
      }

      if (result == null || result.files.isEmpty) {
        if (kDebugMode) {
          print('⚠️ 未选择任何文件');
        }
        return [];
      }

      final List<Map<String, dynamic>> importedFiles = [];
      final List<Map<String, dynamic>> skippedFiles = [];
      final List<Map<String, dynamic>> warningFiles = [];
      final dir = await localAudioDir;

      for (final file in result.files) {
        if (kDebugMode) {
          print('⭐️ 处理文件: ${file.name}, 路径: ${file.path}');
        }

        if (file.path != null) {
          final sourceFile = File(file.path!);
          if (await sourceFile.exists()) {
            if (kDebugMode) {
              print('⭐️ 文件存在，开始验证音频格式...');
            }

            // 检查是否为有效的音频文件
            if (await AudioFileUtil.isAudioFile(sourceFile)) {
              if (kDebugMode) {
                print('⭐️ 文件验证通过，开始检查重复...');
              }

              // 检查重复文件
              final duplicateCheck = await _checkDuplicateFile(sourceFile, file.name);
              
              if (duplicateCheck['isDuplicate'] == true) {
                // 跳过重复文件
                skippedFiles.add({
                  'name': file.name,
                  'path': file.path,
                  'reason': duplicateCheck['message'],
                  'duplicateType': duplicateCheck['duplicateType'],
                  'existingFiles': duplicateCheck['existingFiles']
                });
                
                if (kDebugMode) {
                  print('⚠️ 跳过重复文件: ${file.name} - ${duplicateCheck['message']}');
                }
                continue;
              }
              
              // 如果有警告（相似文件名），记录但不阻止导入
              if (duplicateCheck['warning'] == true) {
                warningFiles.add({
                  'name': file.name,
                  'path': file.path,
                  'warning': duplicateCheck['message'],
                  'similarFiles': duplicateCheck['existingFiles']
                });
                
                if (kDebugMode) {
                  print('⚠️ 文件导入警告: ${file.name} - ${duplicateCheck['message']}');
                }
              }

              if (kDebugMode) {
                print('⭐️ 文件无重复，开始复制...');
              }

              final fileName = file.name;
              final targetFile = File('${dir.path}/$fileName');

              // 如果文件已存在，添加时间戳避免覆盖
              String finalFileName = fileName;
              if (await targetFile.exists()) {
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final nameWithoutExt = p.basenameWithoutExtension(fileName);
                final ext = p.extension(fileName);
                finalFileName = '${nameWithoutExt}_$timestamp$ext';
                if (kDebugMode) {
                  print('⭐️ 文件已存在，重命名为: $finalFileName');
                }
              }

              final finalTargetFile = File('${dir.path}/$finalFileName');

              // 复制文件到本地音频目录
              await sourceFile.copy(finalTargetFile.path);

              // 获取文件信息（包含元数据）
              final fileInfo = await _getAudioFileInfo(
                finalTargetFile,
                finalFileName,
              );
              importedFiles.add(fileInfo);

              if (kDebugMode) {
                print('⭐️ 音频文件已导入: $finalFileName');
              }
            } else {
              if (kDebugMode) {
                print('⚠️ 跳过非音频文件: ${file.name}');
              }
            }
          } else {
            if (kDebugMode) {
              print('⚠️ 文件不存在: ${file.path}');
            }
          }
        } else {
          if (kDebugMode) {
            print('⚠️ 文件路径为空: ${file.name}');
          }
        }
      }

      // 合并并保存到本地缓存
      if (importedFiles.isNotEmpty) {
        final existing = await _loadCache();
        // 用 path 作为唯一键去重/合并
        final Map<String, Map<String, dynamic>> byPath = {
          for (final t in existing) (t['path'] as String): t,
        };
        for (final t in importedFiles) {
          byPath[t['path'] as String] = t;
        }
        final merged = byPath.values.toList();
        await _saveCache(merged);
      }

      // 保存导入结果统计
      await _saveImportResultStats(
        importedCount: importedFiles.length,
        skippedCount: skippedFiles.length,
        warningCount: warningFiles.length,
      );

      // 输出导入结果统计
      if (kDebugMode) {
        print('================ 音频导入结果统计 ================');
        print('成功导入: ${importedFiles.length} 个文件');
        print('跳过重复: ${skippedFiles.length} 个文件');
        print('警告文件: ${warningFiles.length} 个文件');
        
        if (skippedFiles.isNotEmpty) {
          print('\n跳过的重复文件:');
          for (final skipped in skippedFiles) {
            print('  - ${skipped['name']}: ${skipped['reason']}');
          }
        }
        
        if (warningFiles.isNotEmpty) {
          print('\n警告文件:');
          for (final warning in warningFiles) {
            print('  - ${warning['name']}: ${warning['warning']}');
          }
        }
        print('================================================');
      }

      return importedFiles;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 导入音频文件失败: $e');
        print('❌ 错误堆栈: ${StackTrace.current}');
      }
      return [];
    }
  }

  /// 获取本地音频文件列表
  Future<List<Map<String, dynamic>>> getLocalAudioFiles() async {
    try {
      // 1) 优先读取本地缓存（含元数据）
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        // 过滤掉已经不存在的文件
        final List<Map<String, dynamic>> alive = [];
        for (final t in cached) {
          final path = t['path'] as String?;
          if (path != null && await File(path).exists()) {
            alive.add(t);
          }
        }
        if (alive.length != cached.length) {
          await _saveCache(alive);
        }
        alive.sort(
          (a, b) => (a['title'] as String).compareTo(b['title'] as String),
        );
        return alive;
      }

      // 2) 首次无缓存时，扫描目录构建缓存
      final List<Map<String, dynamic>> files = [];
      final dir = await localAudioDir;
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && await AudioFileUtil.isAudioFile(entity)) {
          final fileName = p.basename(entity.path);
          final fileInfo = await _getAudioFileInfo(entity, fileName);
          files.add(fileInfo);
        }
      }
      files.sort(
        (a, b) => (a['title'] as String).compareTo(b['title'] as String),
      );
      await _saveCache(files);
      return files;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取本地音频文件失败: $e');
      }
      return [];
    }
  }

  /// 获取音频文件信息（集成元数据读取，平台不支持时自动回退）
  Future<Map<String, dynamic>> _getAudioFileInfo(
    File file,
    String fileName,
  ) async {
    final fileSize = await file.length();
    final stat = await file.stat();

    // 生成唯一的文件ID
    final fileId =
        'local_${stat.modified.millisecondsSinceEpoch}_${fileName.hashCode}';

    // 默认兜底值
    String title = p.basenameWithoutExtension(fileName);
    String artist = '本地音频';
    String album = '本地音频';
    int durationMs = 0;
    Uint8List? albumArt;
    String? localCoverPath;

    // 读取音频文件元数据（纯 Dart，多平台）
    try {
      final meta = readMetadata(file, getImage: true);
      // 公共字段
      if (meta.title != null && meta.title!.trim().isNotEmpty) {
        title = meta.title!.trim();
      }
      if (meta.artist != null && meta.artist!.trim().isNotEmpty) {
        artist = meta.artist!.trim();
      }
      if (meta.album != null && meta.album!.trim().isNotEmpty) {
        album = meta.album!.trim();
      }
      durationMs = meta.duration?.inMilliseconds ?? durationMs;
      if (meta.pictures.isNotEmpty) {
        albumArt = meta.pictures.first.bytes;

        // 保存封面图到本地缓存
        localCoverPath = await _saveCoverToLocalCache(
          albumArt,
          fileId,
          fileName,
        );
      }

      if (kDebugMode) {
        print('================ 本地音频元数据 =================');
        print('文件名: $fileName');
        print('路径  : ${file.path}');
        print('标题  : ${meta.title}');
        print('歌手  : ${meta.artist}');
        print('专辑  : ${meta.album}');
        print('时长  : ${meta.duration?.inMilliseconds} ms');
        print('封面  : ${meta.pictures.isNotEmpty ? '有' : '无'}');
        if (localCoverPath != null) {
          print('本地封面路径: $localCoverPath');
        }
        print('===============================================${fileId}');
      }
    } catch (e) {
      if (kDebugMode) {
        // 忽略不支持平台/缺少实现等情况，继续使用兜底
        print('⚠️ 元数据读取失败或平台不支持，使用兜底: $e');
      }
    }

    return {
      'file_id': fileId,
      'id': fileId,
      'title': title,
      'name': fileName,
      'artist': artist,
      'album': album,
      'path': file.path,
      'size': fileSize,
      'duration': durationMs,
      'album_art': albumArt, // Uint8List，UI 层可选用
      'cover_url': localCoverPath ?? '', // 本地封面标识（fileId）
      'cover': localCoverPath ?? '', // 本地封面标识（fileId）
      'thumbnail': localCoverPath ?? '', // 本地封面标识（fileId）
      'drive_id': 'local',
      'is_local': true,
      'modified_time': stat.modified.millisecondsSinceEpoch,
    };
  }

  /// 删除本地音频文件
  Future<bool> deleteLocalAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // 获取文件信息以便删除对应的封面图
        final list = await _loadCache();
        Map<String, dynamic>? fileInfo;
        try {
          fileInfo = list.firstWhere((t) => t['path'] == filePath);
        } catch (e) {
          // 文件信息不存在，跳过封面图删除
          if (kDebugMode) {
            print('⚠️ 未找到文件信息，跳过封面图删除: $filePath');
          }
        }

        await file.delete();
        if (kDebugMode) {
          print('⭐️ 本地音频文件已删除: ${p.basename(filePath)}');
        }

        // 删除对应的封面图缓存
        if (fileInfo != null) {
          await _deleteCoverCache(fileInfo);
        }

        // 从缓存移除
        final updated = list.where((t) => t['path'] != filePath).toList();
        await _saveCache(updated);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 删除本地音频文件失败: $e');
      }
      return false;
    }
  }

  /// 删除封面图缓存
  Future<void> _deleteCoverCache(Map<String, dynamic> fileInfo) async {
    try {
      final fileId = fileInfo['file_id'] ?? fileInfo['id'] ?? '';
      
      if (fileId.isNotEmpty) {
        // 从ImageCacheService中删除封面图缓存
        // 注意：ImageCacheService目前没有删除方法，这里只是记录日志
        if (kDebugMode) {
          print('⭐️ 封面图缓存已标记为删除: $fileId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 删除封面图缓存失败: $e');
      }
    }
  }

  /// 获取本地封面图路径
  Future<String?> getLocalCoverPath(String fileId, String fileName) async {
    try {
      final cacheDir = await imageCacheDir;
      final baseName = '${fileId}-${p.basenameWithoutExtension(fileName)}';

      // 检查是否存在封面图缓存
      for (final ext in ['jpg', 'png', 'jpeg']) {
        final coverFile = File('${cacheDir.path}/$baseName.$ext');
        if (await coverFile.exists()) {
          return coverFile.path;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取本地封面图路径失败: $e');
      }
      return null;
    }
  }

  /// 清理孤立的封面图缓存（清理已删除文件的封面图）
  Future<void> cleanupOrphanedCoverCache() async {
    try {
      final cacheDir = await imageCacheDir;
      final localFiles = await getLocalAudioFiles();
      final localFileIds = <String>{};

      // 收集所有本地文件的ID
      for (final file in localFiles) {
        final fileId = file['file_id'] ?? file['id'] ?? '';
        if (fileId.isNotEmpty) {
          localFileIds.add(fileId);
        }
      }

      // 扫描封面图缓存目录
      final entities = await cacheDir.list().toList();
      int cleanedCount = 0;

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          // 检查文件名是否包含本地文件ID
          bool isOrphaned = true;
          for (final fileId in localFileIds) {
            if (fileName.startsWith('${fileId}-')) {
              isOrphaned = false;
              break;
            }
          }

          if (isOrphaned) {
            await entity.delete();
            cleanedCount++;
            if (kDebugMode) {
              print('⭐️ 清理孤立封面图: ${entity.path}');
            }
          }
        }
      }

      if (kDebugMode) {
        print('⭐️ 封面图缓存清理完成，共清理 $cleanedCount 个文件');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清理孤立封面图缓存失败: $e');
      }
    }
  }

  /// 读取本地缓存
  Future<List<Map<String, dynamic>>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      final List<dynamic> raw = json.decode(jsonString) as List<dynamic>;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // 规范化字段类型（album_art 从 List<dynamic> 恢复为 Uint8List）
      for (final t in list) {
        final art = t['album_art'];
        if (art is List) {
          try {
            t['album_art'] = Uint8List.fromList(art.cast<int>());
          } catch (_) {
            // 忽略无法转换的情况
            t['album_art'] = null;
          }
        }
      }
      return list;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 读取本地音频缓存失败: $e');
      }
      return [];
    }
  }

  /// 保存本地缓存
  Future<void> _saveCache(List<Map<String, dynamic>> tracks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(tracks));
      if (kDebugMode) {
        print('⭐️ 本地音频缓存已保存: ${tracks.length} 条');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存本地音频缓存失败: $e');
      }
    }
  }

  /// 获取本地音频目录大小
  Future<String> getLocalAudioDirSize() async {
    try {
      final dir = await localAudioDir;
      int totalSize = 0;

      await for (final entity in dir.list()) {
        if (entity is File) {
          if (await AudioFileUtil.isAudioFile(entity)) {
            totalSize += await entity.length();
          }
        }
      }

      return _formatFileSize(totalSize);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取本地音频目录大小失败: $e');
      }
      return '0 B';
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

  /// 获取重复文件检测的详细信息
  Future<Map<String, dynamic>> getDuplicateDetectionInfo(File sourceFile, String fileName) async {
    try {
      final duplicateCheck = await _checkDuplicateFile(sourceFile, fileName);
      return duplicateCheck;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取重复检测信息失败: $e');
      }
      return {
        'isDuplicate': false,
        'duplicateType': 'error',
        'existingFiles': [],
        'message': '获取重复检测信息时出错'
      };
    }
  }

  /// 获取导入结果统计信息
  Future<Map<String, dynamic>> getImportResultSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final importedCount = prefs.getInt('imported_count') ?? 0;
      final skippedCount = prefs.getInt('skipped_count') ?? 0;
      final warningCount = prefs.getInt('warning_count') ?? 0;
      
      return {
        'imported_count': importedCount,
        'skipped_count': skippedCount,
        'warning_count': warningCount,
        'total_processed': importedCount + skippedCount + warningCount,
        'last_import_time': prefs.getString('last_import_time'),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取导入结果统计失败: $e');
      }
      return {
        'imported_count': 0,
        'skipped_count': 0,
        'warning_count': 0,
        'total_processed': 0,
        'last_import_time': null,
      };
    }
  }

  /// 保存导入结果统计
  Future<void> _saveImportResultStats({
    required int importedCount,
    required int skippedCount,
    required int warningCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('imported_count', importedCount);
      await prefs.setInt('skipped_count', skippedCount);
      await prefs.setInt('warning_count', warningCount);
      await prefs.setString('last_import_time', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 保存导入结果统计失败: $e');
      }
    }
  }

  /// 清除导入结果统计
  Future<void> clearImportResultStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('imported_count');
      await prefs.remove('skipped_count');
      await prefs.remove('warning_count');
      await prefs.remove('last_import_time');
      if (kDebugMode) {
        print('⭐️ 导入结果统计已清除');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清除导入结果统计失败: $e');
      }
    }
  }
}
