import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // Added for File
// import 'package:uuid/uuid.dart';

/// 本地歌单服务（使用 SharedPreferences 持久化）
class PlaylistService extends GetxController {
  static const String _playlistsKey = 'user_playlists_v1';

  /// 歌单列表：每个歌单结构 { id, name, tracks: [track, ...] }
  final RxList<Map<String, dynamic>> playlists = RxList<Map<String, dynamic>>();

  // 单例
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal() {
    // 启动自动加载
    loadPlaylists();
  }

  /// 加载歌单
  Future<void> loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_playlistsKey);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is List) {
          playlists.assignAll(decoded.cast<Map<String, dynamic>>());

          // 调试信息：检查加载的歌单封面图
          if (kDebugMode) {
            print('📱 加载的歌单信息:');
            for (int i = 0; i < playlists.length; i++) {
              final p = playlists[i];
              final imagePath = p['image_path'] as String?;
              print('  - 歌单 $i:');
              print('    ID: ${p['id']}');
              print('    名称: ${p['name']}');
              print('    封面图路径: $imagePath');
              if (imagePath != null) {
                final file = File(imagePath);
                print('    文件是否存在: ${file.existsSync()}');
                print('    绝对路径: ${file.absolute.path}');
              }
            }
          }
        }
      }
      if (kDebugMode) {
        print('✅ 已加载歌单: ${playlists.length} 个');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载歌单失败: $e');
      }
    }
  }

  /// 保存歌单
  Future<void> savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playlistsKey, json.encode(playlists));
      if (kDebugMode) {
        print('✅ 歌单列表已保存');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存歌单失败: $e');
      }
    }
  }

  /// 创建歌单，返回歌单ID
  Future<String> createPlaylist(String name, {String? imagePath}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final exists = playlists.any((p) => (p['name'] ?? '') == name);
    final finalName = exists
        ? '$name(${DateTime.now().millisecondsSinceEpoch % 1000})'
        : name;

    // 调试信息
    if (kDebugMode) {
      print('🎵 创建歌单:');
      print('  - 歌单ID: $id');
      print('  - 歌单名称: $finalName');
      print('  - 封面图路径: $imagePath');
      if (imagePath != null) {
        final file = File(imagePath);
        print('  - 封面图文件是否存在: ${file.existsSync()}');
        print('  - 封面图绝对路径: ${file.absolute.path}');
      }
    }

    playlists.add({
      'id': id,
      'name': finalName,
      'image_path': imagePath, // 新增图片路径字段
      'tracks': <Map<String, dynamic>>[],
    });
    await savePlaylists();
    return id;
  }

  /// 将歌曲添加到指定歌单。返回是否新增（已存在则 false）。
  Future<bool> addTrackToPlaylist(
    String playlistId,
    Map<String, dynamic> track,
  ) async {
    final idx = playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) return false;
    final list = (playlists[idx]['tracks'] as List)
        .cast<Map<String, dynamic>>();
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final already = list.any((t) => (t['file_id'] ?? t['id'] ?? '') == fileId);
    if (already) {
      return false;
    }
    list.add(track);
    playlists[idx] = {
      ...playlists[idx],
      'tracks': List<Map<String, dynamic>>.from(list),
    };
    await savePlaylists();
    return true;
  }

  /// 从歌单移除歌曲
  Future<bool> removeTrackFromPlaylist(String playlistId, String fileId) async {
    final idx = playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) return false;
    final list = (playlists[idx]['tracks'] as List)
        .cast<Map<String, dynamic>>();
    final beforeLen = list.length;
    list.removeWhere((t) => (t['file_id'] ?? t['id'] ?? '') == fileId);
    final removed = list.length != beforeLen;
    if (removed) {
      playlists[idx] = {
        ...playlists[idx],
        'tracks': List<Map<String, dynamic>>.from(list),
      };
      await savePlaylists();
    }
    return removed;
  }

  /// 获取某个歌单的歌曲
  List<Map<String, dynamic>> getTracks(String playlistId) {
    final idx = playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) return const [];
    return (playlists[idx]['tracks'] as List).cast<Map<String, dynamic>>();
  }

  /// 重命名歌单
  Future<bool> renamePlaylist(String playlistId, String newName) async {
    final idx = playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    playlists[idx] = {...playlists[idx], 'name': trimmed};
    await savePlaylists();
    return true;
  }

  /// 更新歌单封面图
  Future<bool> updatePlaylistCover(String playlistId, String imagePath) async {
    final idx = playlists.indexWhere((p) => p['id'] == playlistId);
    if (idx == -1) return false;
    if (imagePath.isEmpty) return false;
    playlists[idx] = {...playlists[idx], 'image_path': imagePath};
    await savePlaylists();
    return true;
  }

  /// 删除歌单
  Future<bool> deletePlaylist(String playlistId) async {
    final before = playlists.length;
    playlists.removeWhere((p) => p['id'] == playlistId);
    final removed = playlists.length != before;
    if (removed) {
      await savePlaylists();
    }
    return removed;
  }

  /// 更新歌单中歌曲的顺序
  Future<bool> updatePlaylistOrder(
    String playlistId,
    List<Map<String, dynamic>> newTracks,
  ) async {
    try {
      final idx = playlists.indexWhere((p) => p['id'] == playlistId);
      if (idx == -1) return false;

      playlists[idx] = {
        ...playlists[idx],
        'tracks': List<Map<String, dynamic>>.from(newTracks),
      };

      await savePlaylists();
      if (kDebugMode) {
        print('✅ 歌单顺序已更新: ${playlists[idx]['name']}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 更新歌单顺序失败: $e');
      }
      return false;
    }
  }

  /// 重新排序歌单列表
  Future<bool> reorderPlaylists(int oldIndex, int newIndex) async {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = playlists.removeAt(oldIndex);
      playlists.insert(newIndex, item);
      await savePlaylists();
      if (kDebugMode) {
        print('✅ 歌单列表顺序已更新: $oldIndex -> $newIndex');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 重新排序歌单列表失败: $e');
      }
      return false;
    }
  }
}
