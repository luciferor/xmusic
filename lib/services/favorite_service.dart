import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 收藏歌曲服务
class FavoriteService extends GetxController {
  static const String _favoritesKey = 'favorite_songs';
  final favoriteTracks = RxList<Map<String, dynamic>>();

  // 单例模式
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  /// 加载收藏列表
  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_favoritesKey);
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        favoriteTracks.clear();
        favoriteTracks.addAll(list.cast<Map<String, dynamic>>());
        if (kDebugMode) {
          print('✅ 已加载${favoriteTracks.length}个收藏');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载收藏列表失败: $e');
      }
    }
  }

  /// 保存收藏列表
  Future<void> saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _favoritesKey,
        json.encode(favoriteTracks.toList()),
      );
      if (kDebugMode) {
        print('✅ 收藏列表已保存');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存收藏列表失败: $e');
      }
    }
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(Map<String, dynamic> track) async {
    try {
      final fileId = track['file_id'] ?? track['id'] ?? '';
      final existingIndex = favoriteTracks.indexWhere(
        (item) => (item['file_id'] ?? item['id'] ?? '') == fileId,
      );

      if (existingIndex != -1) {
        favoriteTracks.removeAt(existingIndex);
        if (kDebugMode) {
          print('💔 取消收藏: $fileId');
        }
      } else {
        favoriteTracks.add(track);
        if (kDebugMode) {
          print('❤️ 添加收藏: $fileId');
        }
      }
      await saveFavorites();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 切换收藏状态失败: $e');
      }
    }
  }

  /// 检查是否已收藏
  bool isFavorite(String fileId) {
    return favoriteTracks.any(
      (item) => (item['file_id'] ?? item['id'] ?? '') == fileId,
    );
  }

  /// 获取所有收藏的歌曲信息
  List<Map<String, dynamic>> getAllFavorites() {
    return favoriteTracks.toList();
  }

  /// 清空收藏列表
  Future<void> clearFavorites() async {
    try {
      favoriteTracks.clear();
      await saveFavorites();
      if (kDebugMode) {
        print('🗑️ 收藏列表已清空');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清空收藏列表失败: $e');
      }
    }
  }

  /// 重新排序收藏列表
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    try {
      if (oldIndex < 0 ||
          oldIndex >= favoriteTracks.length ||
          newIndex < 0 ||
          newIndex >= favoriteTracks.length) {
        if (kDebugMode) {
          print(
            '❌ 重新排序索引无效: oldIndex=$oldIndex, newIndex=$newIndex, length=${favoriteTracks.length}',
          );
        }
        return;
      }

      final element = favoriteTracks.removeAt(oldIndex);
      favoriteTracks.insert(newIndex, element);

      await saveFavorites();
      if (kDebugMode) {
        print('🔄 收藏列表重新排序: $oldIndex -> $newIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 重新排序收藏列表失败: $e');
      }
    }
  }
}
