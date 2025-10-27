import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

/// Service to persist and query listening duration statistics.
/// Stores:
/// - total listened seconds
/// - per-day listened seconds (local date key)
/// - per-track listened seconds (by provided trackId)
/// - track information (name, artist, album, cover path, fileId)
class ListeningStatsService {
  static const String _totalSecondsKey = 'listening_total_seconds';

  String _dailyKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'listening_seconds_$y$m$d';
  }

  String _trackKey(String trackId) => 'listening_seconds_track_$trackId';

  // 新增：歌曲信息存储键
  String _trackInfoKey(String trackId) => 'listening_track_info_$trackId';

  bool _isDailyKey(String key) {
    const prefix = 'listening_seconds_';
    if (!key.startsWith(prefix)) return false;
    final tail = key.substring(prefix.length);
    // 过滤掉 per-track 的键：listening_seconds_track_*
    if (tail.startsWith('track_')) return false;
    if (tail.length != 8) return false;
    for (int i = 0; i < tail.length; i++) {
      final c = tail.codeUnitAt(i);
      if (c < 48 || c > 57) return false; // 非数字
    }
    return true;
  }

  /// 历史累计听歌天数（按本地已存的每日键统计）
  Future<int> getListenedDaysCount() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (final key in prefs.getKeys()) {
      if (_isDailyKey(key)) {
        final sec = prefs.getInt(key) ?? 0;
        if (sec > 0) count++;
      }
    }
    return count;
  }

  Future<void> addSeconds({
    required int seconds,
    String? trackId,
    Map<String, dynamic>? trackInfo,
    DateTime? now,
  }) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalSecondsKey) ?? 0;
    await prefs.setInt(_totalSecondsKey, current + seconds);

    final todayKey = _dailyKey((now ?? DateTime.now()));
    final daily = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, daily + seconds);

    if (trackId != null && trackId.isNotEmpty) {
      final tk = _trackKey(trackId);
      final tval = prefs.getInt(tk) ?? 0;
      await prefs.setInt(tk, tval + seconds);

      // 新增：保存歌曲信息
      if (trackInfo != null) {
        final infoKey = _trackInfoKey(trackId);
        await prefs.setString(infoKey, json.encode(trackInfo));
      }
    }
  }

  /// 提交当前本地统计到服务端（应用退出或切到后台时调用）
  ///
  /// POST: https://xxx/recorder
  /// Body(JSON): {
  ///   "totalSeconds": number,
  ///   "todaySeconds": number,
  ///   "timestamp": ISO8601 string
  /// }
  Future<void> submitStatsOnExit({
    String endpoint = 'https://xxx/recorder',
    Duration timeout = const Duration(seconds: 4),
    int topLimit = 20,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 开始提交听歌统计到服务器...');
        print('  - 接口地址: $endpoint');
        print('  - 超时时间: ${timeout.inSeconds}秒');
      }

      final overview = await getStatsOverview();
      final listenedDays = await getListenedDaysCount();
      final topTracks = await getTopTracks(limit: topLimit);
      final prefs = await SharedPreferences.getInstance();

      if (kDebugMode) {
        print('📊 统计概览数据:');
        print('  - 总听歌时长: ${overview['totalSeconds']}秒');
        print('  - 今日听歌时长: ${overview['todaySeconds']}秒');
        print('  - 听歌天数: $listenedDays');
        print('  - 当前连续天数: ${overview['currentStreak']}');
        print('  - 本周听歌时长: ${overview['thisWeekSeconds']}秒');
        print('  - 本月听歌时长: ${overview['thisMonthSeconds']}秒');
        print('  - 平均每日时长: ${overview['averageDailySeconds']}秒');
        print('  - Top歌曲数量: ${topTracks.length}');
      }

      // 获取用户ID
      String? userId = prefs.getString('aliyun_user_id');
      if (kDebugMode) {
        print('👤 用户ID获取:');
        print('  - 直接获取: $userId');
      }

      if (userId == null || userId.isEmpty) {
        final userInfoString = prefs.getString('aliyun_user_info');
        if (kDebugMode) {
          print(
            '  - 从aliyun_user_info获取: ${userInfoString != null ? '有数据' : '无数据'}',
          );
        }

        if (userInfoString != null) {
          try {
            final info = json.decode(userInfoString) as Map<String, dynamic>;
            userId = (info['id'] ?? info['user_id'] ?? '').toString();
            if (kDebugMode) {
              print('  - 解析后的用户ID: $userId');
            }
          } catch (e) {
            if (kDebugMode) {
              print('  - 解析aliyun_user_info失败: $e');
            }
          }
        }
      }

      // userId 必须存在，否则不提交
      if (userId == null || userId.isEmpty) {
        if (kDebugMode) {
          print('❌ 用户ID为空，取消提交');
          print('  - 可用的SharedPreferences键: ${prefs.getKeys().toList()}');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ 用户ID验证通过: $userId');
      }

      final payload = <String, dynamic>{
        'userId': userId,
        'totalSeconds': overview['totalSeconds'],
        'listenedDays': listenedDays,
        'currentStreak': overview['currentStreak'],
        'thisWeekSeconds': overview['thisWeekSeconds'],
        'thisMonthSeconds': overview['thisMonthSeconds'],
        'averageDailySeconds': overview['averageDailySeconds'],
        'topTracks': topTracks,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('📤 准备发送的数据:');
        print('  - 数据大小: ${jsonEncode(payload).length} 字符');
        print('  - 数据内容: ${jsonEncode(payload)}');
      }

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (kDebugMode) {
        print('📡 服务器响应:');
        print('  - 状态码: ${response.statusCode}');
        print('  - 响应头: ${response.headers}');
        print('  - 响应体: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          print('✅ 听歌统计提交成功!');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 听歌统计提交失败，状态码: ${response.statusCode}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 提交听歌统计异常:');
        print('  - 错误: $e');
        print('  - 堆栈: $stackTrace');
      }
      // 静默失败：退出阶段不应打断应用流程
    }
  }

  Future<int> getTotalSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalSecondsKey) ?? 0;
  }

  Future<int> getTodaySeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dailyKey(DateTime.now());
    return prefs.getInt(key) ?? 0;
  }

  Future<int> getDaySeconds(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dailyKey(day);
    return prefs.getInt(key) ?? 0;
  }

  Future<int> getTrackSeconds(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trackKey(trackId)) ?? 0;
  }

  /// 获取歌曲详细信息
  Future<Map<String, dynamic>?> getTrackInfo(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final infoKey = _trackInfoKey(trackId);
    final trackInfoString = prefs.getString(infoKey);

    if (trackInfoString != null) {
      try {
        return json.decode(trackInfoString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取本周听歌时长（从周一开始）
  Future<int> getThisWeekSeconds() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    int totalSeconds = 0;

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      totalSeconds += await getDaySeconds(day);
    }

    return totalSeconds;
  }

  /// 获取本月听歌时长
  Future<int> getThisMonthSeconds() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    int totalSeconds = 0;

    for (int i = 0; i < lastDay.day; i++) {
      final day = firstDay.add(Duration(days: i));
      totalSeconds += await getDaySeconds(day);
    }

    return totalSeconds;
  }

  /// 获取最近7天的听歌时长数据
  Future<List<Map<String, dynamic>>> getLast7DaysData() async {
    final List<Map<String, dynamic>> data = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final seconds = await getDaySeconds(day);
      data.add({
        'date': day,
        'seconds': seconds,
        'formattedDate': '${day.month}/${day.day}',
        'weekday': _getWeekdayName(day.weekday),
      });
    }

    return data;
  }

  /// 获取最近30天的听歌时长数据
  Future<List<Map<String, dynamic>>> getLast30DaysData() async {
    final List<Map<String, dynamic>> data = [];
    final now = DateTime.now();

    for (int i = 29; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final seconds = await getDaySeconds(day);
      data.add({
        'date': day,
        'seconds': seconds,
        'formattedDate': '${day.month}/${day.day}',
        'weekday': _getWeekdayName(day.weekday),
      });
    }

    return data;
  }

  /// 获取从首次有记录的日期到今天的每日听歌时长数据
  Future<List<Map<String, dynamic>>> getAllHistoryDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    // 区分每日键与歌曲键
    final dailyKeyReg = RegExp(r'^listening_seconds_\d{8}$');
    final dayKeys = keys.where((key) => dailyKeyReg.hasMatch(key)).toList();
    if (dayKeys.isEmpty) return [];

    // 找到最早日期
    dayKeys.sort(); // 字符串排序对 YYYYMMDD 有效
    final earliestKey = dayKeys.first; // listening_seconds_YYYYMMDD
    final earliestStr = earliestKey.substring('listening_seconds_'.length);
    final year = int.parse(earliestStr.substring(0, 4));
    final month = int.parse(earliestStr.substring(4, 6));
    final day = int.parse(earliestStr.substring(6, 8));

    final start = DateTime(year, month, day);
    final today = DateTime.now();

    final List<Map<String, dynamic>> data = [];
    int days = today.difference(DateTime(year, month, day)).inDays + 1;
    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final seconds = await getDaySeconds(date);
      data.add({
        'date': date,
        'seconds': seconds,
        'formattedDate': '${date.month}/${date.day}',
        'weekday': _getWeekdayName(date.weekday),
      });
    }

    return data;
  }

  /// 获取本月每天的听歌时长（从1号到今天）
  Future<List<Map<String, dynamic>>> getThisMonthDailyData() async {
    final List<Map<String, dynamic>> data = [];
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);

    int days = today.difference(firstDay).inDays + 1;
    for (int i = 0; i < days; i++) {
      final day = firstDay.add(Duration(days: i));
      final seconds = await getDaySeconds(day);
      data.add({
        'date': day,
        'seconds': seconds,
        'formattedDate': '${day.month}/${day.day}',
        'weekday': _getWeekdayName(day.weekday),
      });
    }

    return data;
  }

  /// 获取听歌时长最多的歌曲（前10首）
  Future<List<Map<String, dynamic>>> getTopTracks({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final trackKeys = keys
        .where((key) => key.startsWith('listening_seconds_track_'))
        .toList();

    final List<Map<String, dynamic>> tracks = [];
    for (final key in trackKeys) {
      final trackId = key.replaceFirst('listening_seconds_track_', '');
      final seconds = prefs.getInt(key) ?? 0;
      if (seconds > 0) {
        // 获取歌曲详细信息
        final infoKey = _trackInfoKey(trackId);
        final trackInfoString = prefs.getString(infoKey);
        Map<String, dynamic> trackInfo = {};

        if (trackInfoString != null) {
          try {
            trackInfo = json.decode(trackInfoString);
          } catch (e) {
            // 如果解析失败，使用默认信息
            trackInfo = {
              'fileId': trackId,
              'title': '未知歌曲',
              'artist': '未知艺术家',
              'album': '未知专辑',
              'coverPath': '',
            };
          }
        } else {
          // 如果没有保存的歌曲信息，使用默认信息
          trackInfo = {
            'fileId': trackId,
            'title': '未知歌曲',
            'artist': '未知艺术家',
            'album': '未知专辑',
            'coverPath': '',
          };
        }

        tracks.add({
          'trackId': trackId,
          'fileId': trackInfo['fileId'] ?? trackId,
          'title': trackInfo['title'] ?? '未知歌曲',
          'artist': trackInfo['artist'] ?? '未知艺术家',
          'album': trackInfo['album'] ?? '未知专辑',
          'coverPath': trackInfo['coverPath'] ?? '',
          'seconds': seconds,
        });
      }
    }

    // 按听歌时长排序
    tracks.sort((a, b) => b['seconds'].compareTo(a['seconds']));

    return tracks.take(limit).toList();
  }

  /// 获取平均每日听歌时长
  Future<double> getAverageDailySeconds() async {
    final totalSeconds = await getTotalSeconds();
    if (totalSeconds == 0) return 0.0;

    // 计算从第一次听歌到今天的天数
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    // 区分每日键与歌曲键：
    // 每日键格式：listening_seconds_YYYYMMDD（长度应为26）
    // 歌曲键格式：listening_seconds_track_<trackId>
    final dailyKeyReg = RegExp(r'^listening_seconds_\d{8}$');
    final dayKeys = keys.where((key) => dailyKeyReg.hasMatch(key)).toList();

    if (dayKeys.isEmpty) return 0.0;

    final days = dayKeys.length;
    return totalSeconds / days;
  }

  /// 获取最长连续听歌天数
  Future<int> getLongestStreak() async {
    final data = await getLast30DaysData();
    int currentStreak = 0;
    int maxStreak = 0;

    for (final day in data) {
      if (day['seconds'] > 0) {
        currentStreak++;
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
      } else {
        currentStreak = 0;
      }
    }

    return maxStreak;
  }

  /// 获取当前连续听歌天数
  Future<int> getCurrentStreak() async {
    final data = await getLast30DaysData();
    int currentStreak = 0;

    if (data.isEmpty) return 0;

    // 如果今天没有听歌，则从昨天开始往前统计，避免今天刚开启应用时显示 0 的体验问题
    int startIndex = data.length - 1; // 今天
    if ((data[startIndex]['seconds'] as int? ?? 0) == 0) {
      startIndex = data.length - 2; // 昨天
    }

    for (int i = startIndex; i >= 0; i--) {
      if ((data[i]['seconds'] as int? ?? 0) > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    return currentStreak;
  }

  /// 获取听歌统计概览
  Future<Map<String, dynamic>> getStatsOverview() async {
    final totalSeconds = await getTotalSeconds();
    final todaySeconds = await getTodaySeconds();
    final thisWeekSeconds = await getThisWeekSeconds();
    final thisMonthSeconds = await getThisMonthSeconds();
    final averageDaily = await getAverageDailySeconds();
    final longestStreak = await getLongestStreak();
    final currentStreak = await getCurrentStreak();

    return {
      'totalSeconds': totalSeconds,
      'todaySeconds': todaySeconds,
      'thisWeekSeconds': thisWeekSeconds,
      'thisMonthSeconds': thisMonthSeconds,
      'averageDailySeconds': averageDaily,
      'longestStreak': longestStreak,
      'currentStreak': currentStreak,
    };
  }

  /// 格式化时长为可读字符串
  String formatDuration(int seconds) {
    if (seconds <= 0) return '0秒';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}小时${minutes}分钟';
    } else if (minutes > 0) {
      return '${minutes}分钟${remainingSeconds}秒';
    } else {
      return '${remainingSeconds}秒';
    }
  }

  /// 格式化时长为详细字符串
  String formatDurationDetailed(int seconds) {
    if (seconds <= 0) return '0秒';

    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}天');
    if (hours > 0) parts.add('${hours}小时');
    if (minutes > 0) parts.add('${minutes}分钟');
    if (remainingSeconds > 0 || parts.isEmpty)
      parts.add('${remainingSeconds}秒');

    return parts.join('');
  }

  /// 获取星期名称
  String _getWeekdayName(int weekday) {
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday];
  }

  /// 更新歌曲信息
  Future<void> updateTrackInfo(
    String trackId,
    Map<String, dynamic> trackInfo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final infoKey = _trackInfoKey(trackId);
    await prefs.setString(infoKey, json.encode(trackInfo));
  }

  /// 清除所有统计数据
  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final statsKeys = keys
        .where(
          (key) =>
              key.startsWith('listening_seconds_') ||
              key.startsWith('listening_track_info_'),
        )
        .toList();

    for (final key in statsKeys) {
      await prefs.remove(key);
    }
  }

  /// 手动测试提交听歌统计到服务器
  /// 用于调试和验证数据提交功能
  Future<Map<String, dynamic>> testSubmitStats({
    String endpoint = 'https://xxx/recorder',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      print('🧪 开始手动测试听歌统计提交...');

      final overview = await getStatsOverview();
      final listenedDays = await getListenedDaysCount();
      final topTracks = await getTopTracks(limit: 5);
      final prefs = await SharedPreferences.getInstance();

      print('📊 当前统计数据:');
      print('  - 总听歌时长: ${overview['totalSeconds']}秒');
      print('  - 今日听歌时长: ${overview['todaySeconds']}秒');
      print('  - 听歌天数: $listenedDays');
      print('  - Top歌曲: ${topTracks.length}首');

      // 获取用户ID
      String? userId = prefs.getString('aliyun_user_id');
      print('👤 用户ID: $userId');

      if (userId == null || userId.isEmpty) {
        final userInfoString = prefs.getString('aliyun_user_info');
        print('📋 aliyun_user_info: ${userInfoString != null ? '有数据' : '无数据'}');

        if (userInfoString != null) {
          try {
            final info = json.decode(userInfoString) as Map<String, dynamic>;
            userId = (info['id'] ?? info['user_id'] ?? '').toString();
            print('🔄 从aliyun_user_info解析的用户ID: $userId');
          } catch (e) {
            print('❌ 解析aliyun_user_info失败: $e');
          }
        }
      }

      if (userId == null || userId.isEmpty) {
        print('❌ 无法获取用户ID，测试失败');
        return {
          'success': false,
          'error': '用户ID为空',
          'availableKeys': prefs.getKeys().toList(),
        };
      }

      final payload = <String, dynamic>{
        'userId': userId,
        'totalSeconds': overview['totalSeconds'],
        'listenedDays': listenedDays,
        'currentStreak': overview['currentStreak'],
        'thisWeekSeconds': overview['thisWeekSeconds'],
        'thisMonthSeconds': overview['thisMonthSeconds'],
        'averageDailySeconds': overview['averageDailySeconds'],
        'topTracks': topTracks,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'test_mode': true, // 标记为测试数据
      };

      print('📤 发送数据:');
      print('  - 接口: $endpoint');
      print('  - 数据大小: ${jsonEncode(payload).length} 字符');
      print('  - 数据内容: ${jsonEncode(payload)}');

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      print('📡 服务器响应:');
      print('  - 状态码: ${response.statusCode}');
      print('  - 响应头: ${response.headers}');
      print('  - 响应体: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ 测试成功!');
        return {
          'success': true,
          'statusCode': response.statusCode,
          'response': response.body,
          'payload': payload,
        };
      } else {
        print('⚠️ 测试失败，状态码: ${response.statusCode}');
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': 'HTTP ${response.statusCode}',
          'response': response.body,
          'payload': payload,
        };
      }
    } catch (e, stackTrace) {
      print('❌ 测试异常: $e');
      print('堆栈: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// 从服务器拉取听歌统计数据
  /// 当本地数据为0时，使用服务器数据作为兜底
  Future<Map<String, dynamic>?> fetchStatsFromServer({
    String endpoint = 'https://xxx/gettimer',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 开始从服务器拉取听歌统计数据...');
        print('  - 接口地址: $endpoint');
      }

      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('aliyun_user_id');

      if (userId == null || userId.isEmpty) {
        final userInfoString = prefs.getString('aliyun_user_info');
        if (userInfoString != null) {
          try {
            final info = json.decode(userInfoString) as Map<String, dynamic>;
            userId = (info['id'] ?? info['user_id'] ?? '').toString();
          } catch (e) {
            if (kDebugMode) {
              print('❌ 解析aliyun_user_info失败: $e');
            }
          }
        }
      }

      if (userId == null || userId.isEmpty) {
        if (kDebugMode) {
          print('❌ 无法获取用户ID，无法拉取服务器数据');
        }
        return null;
      }

      if (kDebugMode) {
        print('👤 用户ID: $userId');
      }

      if (kDebugMode) {
        print('📤 请求URL: $endpoint');
      }

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': userId}), // 同时发送POST body
          )
          .timeout(timeout);

      if (kDebugMode) {
        print('📡 服务器响应:');
        print('  - 状态码: ${response.statusCode}');
        print('  - 响应头: ${response.headers}');
        print('  - 响应体: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;

          if (kDebugMode) {
            print('✅ 成功解析服务器数据');
            print('  - 数据内容: $data');
          }

          return data;
        } catch (e) {
          if (kDebugMode) {
            print('❌ 解析服务器响应失败: $e');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 服务器响应错误，状态码: ${response.statusCode}');
        }
        return null;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 拉取服务器数据异常:');
        print('  - 错误: $e');
        print('  - 堆栈: $stackTrace');
      }
      return null;
    }
  }

  /// 同步服务器数据到本地（当本地数据为0时）
  Future<bool> syncServerDataToLocal() async {
    try {
      if (kDebugMode) {
        print('🔄 开始同步服务器数据到本地...');
      }

      // 检查本地是否有数据
      final totalSeconds = await getTotalSeconds();
      if (totalSeconds > 0) {
        if (kDebugMode) {
          print('ℹ️ 本地已有数据，无需同步');
        }
        return true;
      }

      // 从服务器拉取数据
      final serverData = await fetchStatsFromServer();
      if (serverData == null) {
        if (kDebugMode) {
          print('❌ 无法从服务器获取数据');
        }
        return false;
      }

      // 解析并保存服务器数据到本地
      final prefs = await SharedPreferences.getInstance();

      // 从服务器响应中提取实际数据
      // 服务器返回格式: {"code": 200, "message": {...}, "status": true}
      final actualData = serverData['message'] ?? serverData;

      if (kDebugMode) {
        print('📊 解析到的实际数据: $actualData');
      }

      // 保存总听歌时长
      final serverTotalSeconds =
          actualData['totalSeconds'] ?? actualData['total_seconds'] ?? 0;
      if (serverTotalSeconds > 0) {
        await prefs.setInt(_totalSecondsKey, serverTotalSeconds);
        if (kDebugMode) {
          print('💾 保存总听歌时长: $serverTotalSeconds秒');
        }
      }

      // 保存今日听歌时长（如果没有今日数据，使用本周数据的一部分作为估算）
      final serverTodaySeconds =
          actualData['todaySeconds'] ?? actualData['today_seconds'] ?? 0;
      if (serverTodaySeconds > 0) {
        final todayKey = _dailyKey(DateTime.now());
        await prefs.setInt(todayKey, serverTodaySeconds);
        if (kDebugMode) {
          print('💾 保存今日听歌时长: $serverTodaySeconds秒');
        }
      } else {
        // 如果没有今日数据，尝试从本周数据估算
        final weekSeconds =
            actualData['thisWeekSeconds'] ??
            actualData['this_week_seconds'] ??
            0;
        if (weekSeconds > 0) {
          // 估算今日数据为本周数据的1/7
          final estimatedTodaySeconds = (weekSeconds / 7).round();
          final todayKey = _dailyKey(DateTime.now());
          await prefs.setInt(todayKey, estimatedTodaySeconds);
          if (kDebugMode) {
            print('💾 估算并保存今日听歌时长: $estimatedTodaySeconds秒');
          }
        }
      }

      // 保存本周听歌时长
      final weekSeconds =
          actualData['thisWeekSeconds'] ?? actualData['this_week_seconds'] ?? 0;
      if (weekSeconds > 0) {
        // 将本周数据分配到最近7天
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));

        for (int i = 0; i < 7; i++) {
          final day = weekStart.add(Duration(days: i));
          final dayKey = _dailyKey(day);
          // 每天平均分配，但今天优先使用估算值
          if (day.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
            // 今天的数据已经在上面处理过了
            continue;
          }
          final dailySeconds = (weekSeconds / 7).round();
          await prefs.setInt(dayKey, dailySeconds);
        }
        if (kDebugMode) {
          print('💾 保存本周听歌数据: $weekSeconds秒，分配到7天');
        }
      }

      // 保存本月听歌时长
      final monthSeconds =
          actualData['thisMonthSeconds'] ??
          actualData['this_month_seconds'] ??
          0;
      if (monthSeconds > 0) {
        if (kDebugMode) {
          print('💾 本月听歌时长: $monthSeconds秒');
        }
      }

      // 保存平均每日时长
      final avgDailySeconds =
          actualData['averageDailySeconds'] ??
          actualData['average_daily_seconds'] ??
          0;
      if (avgDailySeconds > 0) {
        if (kDebugMode) {
          print('💾 平均每日时长: $avgDailySeconds秒');
        }
      }

      // 保存连续听歌天数
      final currentStreak =
          actualData['currentStreak'] ?? actualData['current_streak'] ?? 0;
      if (currentStreak > 0) {
        if (kDebugMode) {
          print('💾 连续听歌天数: $currentStreak天');
        }
      }

      // 保存历史每日数据
      final historyData =
          serverData['history'] ?? serverData['dailyData'] ?? [];
      if (historyData is List) {
        int savedDays = 0;
        for (final dayData in historyData) {
          if (dayData is Map<String, dynamic>) {
            final dateStr = dayData['date'] ?? dayData['day'];
            final seconds = dayData['seconds'] ?? dayData['duration'];

            if (dateStr != null && seconds != null && seconds > 0) {
              try {
                final date = DateTime.parse(dateStr);
                final key = _dailyKey(date);
                await prefs.setInt(key, seconds);
                savedDays++;
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ 解析日期失败: $dateStr, 错误: $e');
                }
              }
            }
          }
        }
        if (kDebugMode) {
          print('💾 保存历史数据: $savedDays 天');
        }
      }

      // 保存Top歌曲数据
      final topTracks =
          serverData['topTracks'] ?? serverData['top_tracks'] ?? [];
      if (topTracks is List) {
        int savedTracks = 0;
        for (final trackData in topTracks) {
          if (trackData is Map<String, dynamic>) {
            final trackId =
                trackData['trackId'] ??
                trackData['track_id'] ??
                trackData['id'];
            final seconds = trackData['seconds'] ?? trackData['duration'];

            if (trackId != null && seconds != null && seconds > 0) {
              final key = _trackKey(trackId);
              await prefs.setInt(key, seconds);

              // 保存歌曲信息
              final trackInfo = {
                'name': trackData['name'] ?? trackData['title'],
                'artist': trackData['artist'] ?? trackData['singer'],
                'album': trackData['album'],
                'cover': trackData['cover'] ?? trackData['coverUrl'],
                'fileId': trackData['fileId'] ?? trackData['file_id'],
              };

              final infoKey = _trackInfoKey(trackId);
              await prefs.setString(infoKey, json.encode(trackInfo));
              savedTracks++;
            }
          }
        }
        if (kDebugMode) {
          print('💾 保存Top歌曲数据: $savedTracks 首');
        }
      }

      if (kDebugMode) {
        print('✅ 服务器数据同步完成');
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 同步服务器数据失败:');
        print('  - 错误: $e');
        print('  - 堆栈: $stackTrace');
      }
      return false;
    }
  }

  /// 调试方法：验证本地数据保存情况
  Future<void> debugLocalData() async {
    if (!kDebugMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      print('🔍 本地数据验证:');
      print('  - 总听歌时长键: $_totalSecondsKey');
      print('  - 总听歌时长值: ${prefs.getInt(_totalSecondsKey)}');

      final todayKey = _dailyKey(DateTime.now());
      print('  - 今日听歌时长键: $todayKey');
      print('  - 今日听歌时长值: ${prefs.getInt(todayKey)}');

      // 检查最近7天的数据
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        final dayKey = _dailyKey(day);
        final dayValue = prefs.getInt(dayKey) ?? 0;
        print('  - ${day.toString().substring(0, 10)}: $dayValue秒');
      }

      // 检查所有相关的键
      final allKeys = prefs
          .getKeys()
          .where(
            (key) =>
                key.startsWith('listening_seconds_') || key == _totalSecondsKey,
          )
          .toList();

      print('  - 所有相关键: $allKeys');
      for (final key in allKeys) {
        final value = prefs.getInt(key);
        print('    $key: $value');
      }
    } catch (e) {
      print('❌ 调试本地数据失败: $e');
    }
  }
}
