import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart'; // Added for Get.offAllNamed
import 'package:flutter/foundation.dart';

class AliyunDriveService {
  // 阿里云盘API配置
  static const String _baseUrl = 'https://openapi.alipan.com'; // OAuth授权域名
  static const String _apiBaseUrl = 'https://openapi.alipan.com'; // API接口域名

  // 应用配置 - 需要替换为你的实际配置
  static const String clientId =
      'xxxxxxxxxxxxxxxxxxx'; // 替换为你的client_id
  static const String clientSecret =
      'xxxxxxxxxxxxxxxxxxx'; // 替换为你的client_secret
  static const String redirectUri = 'xxxx'; // 自定义URI Scheme |xmusic://xxx/xxx

  // 存储键名
  static const String _accessTokenKey = 'aliyun_access_token';
  static const String _refreshTokenKey = 'aliyun_refresh_token';
  static const String _expiresAtKey = 'aliyun_expires_at';
  static const String _userIdKey = 'aliyun_user_id';
  static const String _driveInfoKey = 'aliyun_drive_info';
  static const String _driveIdKey = 'aliyun_drive_id';
  static const String _spaceInfoKey = 'aliyun_space_info';

  // 文件列表缓存相关键名
  static const String _fileListCacheKey = 'aliyun_file_list_cache';
  static const String _fileListCacheTimeKey = 'aliyun_file_list_cache_time';
  static const String _fileListCacheFolderKey = 'aliyun_file_list_cache_folder';

  // 缓存时间配置（7天）
  static const int _cacheValidDays = 7;

  // 单例模式
  static final AliyunDriveService _instance = AliyunDriveService._internal();
  factory AliyunDriveService() => _instance;
  AliyunDriveService._internal();

  // 初始化标志
  bool _isInitialized = false;

  // 初始化方法
  Future<void> _initialize() async {
    if (!_isInitialized) {
      await loadTokensFromStorage();
      _isInitialized = true;

      // 2024-08-04：在初始化完成后立即检查并同步用户信息
      if (_userInfo != null) {
        if (kDebugMode) {
          print('🚀 App初始化，立即同步用户信息到dsnbc...');
        }
        // 立即发起同步
        await _syncUserToDsnbc();
      } else if (_accessToken != null) {
        // 如果有token但没有用户信息，尝试获取并同步
        if (kDebugMode) {
          print('🔄 发现token但无用户信息，尝试获取并同步...');
        }
        final info = await getUserInfo();
        if (info != null) {
          if (kDebugMode) {
            print('📝 获取到的用户信息:');
            print('- 用户ID: ${info['user_id'] ?? '未知'}');
            print('- 昵称: ${info['nick_name'] ?? info['name'] ?? '未知'}');
            print('- 头像: ${info['avatar'] ?? '无'}');
            print('- 手机: ${info['phone'] ?? '未授权'}');
          }
          await saveUserInfo(info);
          await _syncUserToDsnbc();
        }
      }
    }
  }

  // 当前访问令牌
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _userId;
  Map<String, dynamic>? _driveInfo;
  String? _driveId;
  Map<String, dynamic>? _spaceInfo;
  String? _tokenType; // 添加token_type字段
  Map<String, dynamic>? _userInfo; // 添加用户信息字段

  // 获取访问令牌
  String? get accessToken {
    if (!_isInitialized) {
      return null;
    }
    return _accessToken;
  }

  // 获取drive信息
  Map<String, dynamic>? get driveInfo {
    if (!_isInitialized) {
      return null;
    }
    return _driveInfo;
  }

  // 获取空间信息
  Map<String, dynamic>? get spaceInfo {
    if (!_isInitialized) {
      return null;
    }
    return _spaceInfo;
  }

  // 获取用户ID
  String? get userId {
    if (!_isInitialized) {
      return null;
    }
    return _userId;
  }

  // 获取驱动器ID
  String? get driveId {
    if (!_isInitialized) {
      return null;
    }
    return _driveId;
  }

  // 新增：公有getter，便于外部获取内存中的用户信息
  Map<String, dynamic>? get userInfo => _userInfo;

  // 使用授权码获取访问令牌
  Future<Map<String, dynamic>?> getAccessToken(String code) async {
    try {
      await _initialize();

      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/access_token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        saveTokens(tokenData);
        return tokenData;
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }

    return null;
  }

  // 使用refresh_token刷新访问令牌
  Future<Map<String, dynamic>?> refreshAccessToken() async {
    try {
      await _initialize();

      if (_refreshToken == null) {
        debugPrint('❌ refreshAccessToken: refresh_token为空，无法刷新');
        return null;
      }

      debugPrint('⭐️ refreshAccessToken: 开始刷新token');
      debugPrint(
        '⭐️ refreshAccessToken: 当前refresh_token: ${_refreshToken!.substring(0, 20)}...',
      );

      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/access_token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );

      debugPrint('⭐️ refreshAccessToken: 响应状态码: ${response.statusCode}');
      debugPrint('⭐️ refreshAccessToken: 响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        debugPrint(
          '⭐️ refreshAccessToken: 刷新成功，新token过期时间: ${tokenData['expires_in']}秒',
        );
        saveTokens(tokenData);
        return tokenData;
      } else {
        debugPrint(
          '❌ refreshAccessToken: 刷新失败，状态码: ${response.statusCode}, 响应: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ refreshAccessToken 错误: $e');
    }

    return null;
  }

  /// 手动刷新token（用于处理图片403错误）
  Future<bool> manualRefreshToken() async {
    try {
      await _initialize();

      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('❌ 没有可用的refresh token');
        return false;
      }

      debugPrint('🔄 开始手动刷新token...');

      final response = await http.post(
        Uri.parse('$_baseUrl/v2/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final accessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (accessToken != null &&
            newRefreshToken != null &&
            expiresIn != null) {
          // 保存新的token
          await prefs.setString(_accessTokenKey, accessToken);
          await prefs.setString(_refreshTokenKey, newRefreshToken);
          await prefs.setInt(
            _expiresAtKey,
            DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
          );

          debugPrint('✅ Token手动刷新成功');
          return true;
        } else {
          debugPrint('❌ Token响应数据不完整');
          return false;
        }
      } else {
        debugPrint('❌ Token刷新失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 手动刷新token异常: $e');
      return false;
    }
  }

  // 检查是否已授权
  Future<bool> isAuthorized() async {
    await _initialize();

    if (_accessToken == null || _expiresAt == null) {
      return false;
    }

    // 检查token是否过期
    final now = DateTime.now();
    final isExpired = now.isAfter(_expiresAt!);

    if (isExpired) {
      debugPrint('⭐️ isAuthorized: token已过期，尝试刷新');
      // token已过期，尝试刷新
      final refreshResult = await refreshAccessToken();
      if (refreshResult != null) {
        debugPrint('⭐️ isAuthorized: token刷新成功');
        return true;
      } else {
        debugPrint('❌ isAuthorized: token刷新失败');
        return false;
      }
    }

    // 检查token是否即将过期（10分钟内过期），提前刷新
    final timeUntilExpiry = _expiresAt!.difference(now);
    if (timeUntilExpiry.inMinutes < 10) {
      debugPrint(
        '⭐️ isAuthorized: token即将过期（${timeUntilExpiry.inMinutes}分钟后），提前刷新',
      );
      final refreshResult = await refreshAccessToken();
      if (refreshResult != null) {
        debugPrint('⭐️ isAuthorized: token提前刷新成功');
        return true;
      }
    }

    return true;
  }

  // 保存令牌和用户信息
  // 注意：公开客户端接入的 AccessToken 有效期为30天，不支持刷新
  Future<void> saveTokens(Map<String, dynamic> tokenData) async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = tokenData['access_token'];
    _refreshToken = tokenData['refresh_token'];
    _userId = tokenData['user_id'];
    _tokenType = tokenData['token_type'] ?? 'Bearer'; // 保存token_type

    // 计算过期时间
    final expiresIn = tokenData['expires_in'] as int;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    debugPrint('⭐️ saveTokens: 保存token信息');
    debugPrint(
      '⭐️ saveTokens: expires_in = ${expiresIn}秒 (${(expiresIn / 3600).toStringAsFixed(1)}小时)',
    );
    debugPrint('⭐️ saveTokens: 过期时间 = ${_expiresAt}');
    debugPrint(
      '⭐️ saveTokens: 距离过期还有 ${_expiresAt!.difference(DateTime.now()).inHours}小时',
    );

    // 保存到本地存储
    await prefs.setString(_accessTokenKey, _accessToken!);
    await prefs.setString(_refreshTokenKey, _refreshToken!);
    await prefs.setString(_expiresAtKey, _expiresAt!.toIso8601String());
    if (_userId != null) {
      await prefs.setString(_userIdKey, _userId!);
    }
    await prefs.setString('aliyun_token_type', _tokenType!);

    // 立即获取并保存drive信息（包含空间信息）
    await _fetchAndSaveDriveInfo();

    // 自动获取并保存用户信息
    await _fetchAndSaveUserInfo();
  }

  // 获取并保存drive信息
  Future<void> _fetchAndSaveDriveInfo() async {
    try {
      final driveInfo = await getDriveInfo();
      if (driveInfo != null) {
        await saveDriveInfo(driveInfo);
        // 同时保存为空间信息
        await saveSpaceInfo(driveInfo);
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
  }

  // 获取并保存用户信息
  Future<void> _fetchAndSaveUserInfo() async {
    try {
      final userInfo = await getUserInfo();
      if (userInfo != null) {
        await saveUserInfo(userInfo);
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
  }

  // 获取默认驱动器
  Future<Map<String, dynamic>?> _getDefaultDrive() async {
    if (!await isAuthorized()) return null;

    try {
      final tokenType = 'Bearer';
      final authHeader = '$tokenType $_accessToken';

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/v2/drive/get_default_drive'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }

    return null;
  }

  // 保存驱动器信息（适配新版OpenAPI字段）
  Future<void> saveDriveInfo(Map<String, dynamic> driveInfo) async {
    final prefs = await SharedPreferences.getInstance();

    // 适配新版字段
    final mainDrive = driveInfo;
    await prefs.setString(
      'aliyun_drive_id',
      driveInfo['default_drive_id'] ?? mainDrive['drive_id'] ?? '',
    );
    await prefs.setString('aliyun_drive_name', mainDrive['drive_name'] ?? '');
    await prefs.setString('aliyun_drive_type', mainDrive['drive_type'] ?? '');
    await prefs.setString('aliyun_drive_status', mainDrive['status'] ?? '');
    await prefs.setString(
      'aliyun_drive_capacity',
      (mainDrive['total_size'] ?? '').toString(),
    );
    await prefs.setString(
      'aliyun_drive_used',
      (mainDrive['used_size'] ?? '').toString(),
    );
    await prefs.setString('aliyun_user_id', mainDrive['user_id'] ?? '');

    // 也可以保存整个driveInfo以备后续使用
    await prefs.setString('aliyun_drive_info', json.encode(driveInfo));

    // 同步内存变量
    _driveInfo = driveInfo;
    _driveId = driveInfo['default_drive_id'] ?? mainDrive['drive_id'];
  }

  // 保存空间信息
  Future<void> saveSpaceInfo(Map<String, dynamic> spaceInfo) async {
    final prefs = await SharedPreferences.getInstance();
    _spaceInfo = spaceInfo;
    await prefs.setString(_spaceInfoKey, json.encode(spaceInfo));
  }

  // 保存用户信息（适配新版OpenAPI字段）
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aliyun_user_id', userInfo['user_id'] ?? '');
    await prefs.setString(
      'aliyun_user_name',
      userInfo['name'] ?? userInfo['nick_name'] ?? '',
    );
    await prefs.setString('aliyun_user_avatar', userInfo['avatar'] ?? '');
    await prefs.setString(
      'aliyun_user_total_size',
      (userInfo['total_size'] ?? '').toString(),
    );
    await prefs.setString(
      'aliyun_user_used_size',
      (userInfo['used_size'] ?? '').toString(),
    );
    await prefs.setString('aliyun_user_info', json.encode(userInfo));
  }

  // 检查令牌是否过期
  bool isTokenExpired() {
    if (_expiresAt == null) return true;
    return DateTime.now().isAfter(_expiresAt!);
  }

  // 从本地存储加载令牌
  Future<void> loadTokensFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getString(_userIdKey);
    _tokenType =
        prefs.getString('aliyun_token_type') ?? 'Bearer'; // 加载token_type

    final expiresAtString = prefs.getString(_expiresAtKey);
    if (expiresAtString != null) {
      _expiresAt = DateTime.parse(expiresAtString);
    }

    // 加载drive信息
    final driveInfoString = prefs.getString('aliyun_drive_info');
    if (driveInfoString != null) {
      _driveInfo = json.decode(driveInfoString);
      _driveId = _driveInfo?['default_drive_id'] ?? _driveInfo?['drive_id'];
    }

    // 加载空间信息
    final spaceInfoString = prefs.getString('aliyun_space_info');
    if (spaceInfoString != null) {
      _spaceInfo = json.decode(spaceInfoString);
    }

    // 加载用户信息
    final userInfoString = prefs.getString('aliyun_user_info');
    if (userInfoString != null) {
      _userInfo = json.decode(userInfoString);
    }
  }

  // 清除授权信息
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_driveInfoKey);
    await prefs.remove(_driveIdKey);
    await prefs.remove(_spaceInfoKey);

    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _userId = null;
    _driveInfo = null;
    _driveId = null;
    _spaceInfo = null;
  }

  // 获取用户信息（新版OpenAPI）
  Future<Map<String, dynamic>?> getUserInfo() async {
    if (_accessToken == null) {
      if (kDebugMode) {
        print('❌ getUserInfo: 无访问令牌');
      }
      return null;
    }

    try {
      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';

      if (kDebugMode) {
        print('🔍 开始获取用户信息...');
      }
      final response = await http.get(
        Uri.parse('$_baseUrl/oauth/users/info'),
        headers: {'Authorization': authHeader},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 确保返回的数据包含所有必需字段
        final processedData = <String, dynamic>{
          'id': data['id'] ?? '', // 用户ID（必需）
          'name': data['nick_name'] ?? data['name'] ?? '默认用户', // 昵称（必需）
          'avatar': data['avatar'] ?? '', // 头像（必需）
          'phone': data['phone'] ?? '', // 手机号（可选）
          ...Map<String, dynamic>.from(data), // 保留原始数据
        };

        _userInfo = processedData;

        // 直接发送到 dsnbc，使用标准字段
        await http.post(
          Uri.parse('/userlogin'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': processedData['id'],
            'name': processedData['name'],
            'avatar': data['avatar'] ?? '',
          }),
        );

        return data;
      } else {
        if (kDebugMode) {
          print('❌ 获取用户信息失败，状态码：${response.statusCode}');
          print('❌ 响应内容：${response.body}');
        }
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
    return null;
  }

  // 获取文件列表（新版OpenAPI，不缓存）
  Future<Map<String, dynamic>?> getFileList({
    String? driveId,
    String? parentFileId = 'root',
    int? limit = 100,
    String? marker,
    bool forceRefresh = false, // 保留参数以保持兼容性，但不再使用
  }) async {
    if (!await isAuthorized()) {
      return null;
    }

    try {
      if (driveId == null) {
        driveId = _driveId;
        if (driveId == null) {
          final driveInfo = await getDriveInfo();
          driveId = driveInfo?['drive_id'];
        }
      }
      if (driveId == null) {
        return null;
      }

      debugPrint('⭐️ 从阿里云API获取文件列表: $parentFileId');

      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';
      final requestBody = {
        'drive_id': driveId,
        'parent_file_id': parentFileId,
        'limit': limit,
        'all': false,
        'fields': '*',
        'category': 'audio',
        'order_by': 'updated_at',
        'order_direction': 'DESC',
        if (marker != null) 'marker': marker,
      };

      final response = await http.post(
        Uri.parse('https://openapi.alipan.com/adrive/v1.0/openFile/list'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          '⭐️ 文件列表获取成功: $parentFileId (${data['items']?.length ?? 0}个文件)',
        );
        return data;
      } else {
        debugPrint('❌ API请求失败，状态码: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 获取文件列表失败: $e');
      return null;
    }
  }

  /// 从缓存获取文件列表（已废弃，不再使用缓存）
  @deprecated
  Future<Map<String, dynamic>?> _getCachedFileList(
    String? parentFileId, {
    bool ignoreExpiry = false,
  }) async {
    if (parentFileId == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查缓存时间
      final cacheTimeString = prefs.getString(
        '${_fileListCacheTimeKey}_$parentFileId',
      );
      if (cacheTimeString == null) {
        return null;
      }

      final cacheTime = DateTime.parse(cacheTimeString);
      final now = DateTime.now();
      final daysSinceCache = now.difference(cacheTime).inDays;

      // 检查缓存是否过期（7天），除非忽略过期检查
      if (!ignoreExpiry && daysSinceCache >= _cacheValidDays) {
        debugPrint('⭐️ 文件列表缓存已过期: $parentFileId (${daysSinceCache}天前)');
        return null;
      }

      // 检查缓存的文件夹ID是否匹配
      final cachedFolderId = prefs.getString(
        '${_fileListCacheFolderKey}_$parentFileId',
      );
      if (cachedFolderId != parentFileId) {
        debugPrint('⭐️ 文件夹ID不匹配，缓存无效: $parentFileId');
        return null;
      }

      // 获取缓存数据
      final cachedDataString = prefs.getString(
        '${_fileListCacheKey}_$parentFileId',
      );
      if (cachedDataString == null) {
        return null;
      }

      final cachedData = json.decode(cachedDataString) as Map<String, dynamic>;
      if (ignoreExpiry && daysSinceCache >= _cacheValidDays) {
        debugPrint('⭐️ 使用过期缓存的文件列表: $parentFileId (${daysSinceCache}天前缓存)');
      } else {
        debugPrint('⭐️ 使用缓存的文件列表: $parentFileId (${daysSinceCache}天前缓存)');
      }

      return cachedData;
    } catch (e) {
      debugPrint('❌ 读取文件列表缓存失败: $e');
      return null;
    }
  }

  /// 缓存文件列表（已废弃，不再使用缓存）
  @deprecated
  Future<void> _cacheFileList(
    String? parentFileId,
    Map<String, dynamic> data,
  ) async {
    if (parentFileId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // 保存缓存时间
      await prefs.setString(
        '${_fileListCacheTimeKey}_$parentFileId',
        now.toIso8601String(),
      );

      // 保存文件夹ID
      await prefs.setString(
        '${_fileListCacheFolderKey}_$parentFileId',
        parentFileId,
      );

      // 保存文件列表数据
      await prefs.setString(
        '${_fileListCacheKey}_$parentFileId',
        json.encode(data),
      );

      debugPrint(
        '⭐️ 文件列表已缓存: $parentFileId (${data['items']?.length ?? 0}个文件)',
      );
    } catch (e) {
      debugPrint('❌ 缓存文件列表失败: $e');
    }
  }

  /// 清除文件列表缓存（已废弃，不再使用缓存）
  @deprecated
  Future<void> clearFileListCache({String? parentFileId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (parentFileId != null) {
        // 清除指定文件夹的缓存
        await prefs.remove('${_fileListCacheKey}_$parentFileId');
        await prefs.remove('${_fileListCacheTimeKey}_$parentFileId');
        await prefs.remove('${_fileListCacheFolderKey}_$parentFileId');
        debugPrint('⭐️ 已清除文件夹缓存: $parentFileId');
      } else {
        // 清除所有文件列表缓存
        final keys = prefs.getKeys();
        final cacheKeys = keys.where(
          (key) =>
              key.startsWith(_fileListCacheKey) ||
              key.startsWith(_fileListCacheTimeKey) ||
              key.startsWith(_fileListCacheFolderKey),
        );

        for (final key in cacheKeys) {
          await prefs.remove(key);
        }
        debugPrint('⭐️ 已清除所有文件列表缓存');
      }
    } catch (e) {
      debugPrint('❌ 清除文件列表缓存失败: $e');
    }
  }

  /// 检查文件列表缓存状态（已废弃，不再使用缓存）
  @deprecated
  Future<Map<String, dynamic>> getFileListCacheStatus(
    String parentFileId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cacheTimeString = prefs.getString(
        '${_fileListCacheTimeKey}_$parentFileId',
      );
      if (cacheTimeString == null) {
        return {
          'hasCache': false,
          'cacheTime': null,
          'daysSinceCache': null,
          'isValid': false,
        };
      }

      final cacheTime = DateTime.parse(cacheTimeString);
      final now = DateTime.now();
      final daysSinceCache = now.difference(cacheTime).inDays;
      final isValid = daysSinceCache < _cacheValidDays;

      return {
        'hasCache': true,
        'cacheTime': cacheTime.toIso8601String(),
        'daysSinceCache': daysSinceCache,
        'isValid': isValid,
        'cacheValidDays': _cacheValidDays,
      };
    } catch (e) {
      debugPrint('❌ 获取缓存状态失败: $e');
      return {
        'hasCache': false,
        'cacheTime': null,
        'daysSinceCache': null,
        'isValid': false,
      };
    }
  }

  // 搜索文件（新版OpenAPI）
  Future<Map<String, dynamic>?> searchFiles({
    required String query,
    String? driveId,
    String? parentFileId,
    int? limit = 100,
    String? marker,
  }) async {
    if (!await isAuthorized()) return null;
    try {
      if (driveId == null) {
        driveId = _driveId;
        if (driveId == null) {
          final driveInfo = await getDriveInfo();
          driveId = driveInfo?['drive_id'];
        }
      }
      if (driveId == null) return null;
      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';
      final requestBody = {
        'drive_id': driveId,
        'query': query,
        'limit': limit,
        'fields': '*',
        'order_by': 'updated_at',
        'order_direction': 'DESC',
        if (parentFileId != null) 'parent_file_id': parentFileId,
        if (marker != null) 'marker': marker,
      };
      final response = await http.post(
        Uri.parse('https://openapi.alipan.com/adrive/v1.0/openFile/search'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
    return null;
  }

  // 获取文件下载链接（新版OpenAPI）
  Future<String?> getDownloadUrl({
    required String driveId,
    required String fileId,
  }) async {
    if (!await isAuthorized()) return null;
    int retryCount = 0;
    while (retryCount < 2) {
      try {
        final tokenType = _tokenType ?? 'Bearer';
        final authHeader = '$tokenType $_accessToken';

        final response = await http.post(
          Uri.parse(
            'https://openapi.alipan.com/adrive/v1.0/openFile/getDownloadUrl',
          ),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          body: json.encode({'drive_id': driveId, 'file_id': fileId}),
        );
        debugPrint('⭐️ getDownloadUrl: API响应状态码: ${response.statusCode}');
        debugPrint('⭐️ getDownloadUrl: API响应内容: ${response.body}');
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('⭐️ getDownloadUrl: 返回的url: ${data['url']}');
          return data['url'];
        } else if (response.statusCode == 401 && retryCount == 0) {
          // token 失效，尝试刷新 token 并重试一次
          debugPrint('🔄 getDownloadUrl: 检测到401，尝试刷新token...');
          final refreshSuccess = await manualRefreshToken();
          if (refreshSuccess) {
            debugPrint('🔄 getDownloadUrl: token刷新成功，准备重试...');
            retryCount++;
            continue;
          } else {
            debugPrint('❌ getDownloadUrl: token刷新失败');
            // 跳转到登录页并清空路由栈
            Get.offAllNamed('/login');
            break;
          }
        } else {
          debugPrint('❌ getDownloadUrl: API调用失败，状态码: ${response.statusCode}');
          debugPrint('❌ getDownloadUrl: 错误响应: ${response.body}');
          break;
        }
      } catch (e) {
        debugPrint('❌ getDownloadUrl: 异常: $e');
        break;
      }
    }
    return null;
  }

  // 获取新版驱动器信息（适配新版OpenAPI）
  Future<Map<String, dynamic>?> getDriveInfo() async {
    if (!await isAuthorized()) return null;

    try {
      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/adrive/v1.0/user/getDriveInfo'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: '{}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 取第一个drive_list作为主驱动器
        final driveList = data['drive_list'] as List<dynamic>? ?? [];
        final mainDrive = driveList.isNotEmpty
            ? Map<String, dynamic>.from(driveList[0])
            : <String, dynamic>{};

        // 合并所有顶层字段和主驱动器字段
        final driveInfo = <String, dynamic>{...data, ...mainDrive};

        // 全局存储driveId
        final driveId = mainDrive['drive_id'] as String?;
        if (driveId != null && driveId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('aliyun_drive_id', driveId);
          if (kDebugMode) {
            print('💾 全局存储driveId: $driveId');
          }
        }

        // 同步用户信息到 dsnbc
        await _syncUserToDsnbc();

        return driveInfo;
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
    return null;
  }

  // 获取文件详情（新版OpenAPI）
  Future<Map<String, dynamic>?> getFileDetail({
    required String driveId,
    required String fileId,
  }) async {
    if (!await isAuthorized()) return null;
    try {
      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';
      final response = await http.post(
        Uri.parse('https://openapi.alipan.com/adrive/v1.0/openFile/get'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'drive_id': driveId,
          'file_id': fileId,
          'fields': '*',
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // 这里不需要打印异常，因为调用者会处理
    }
    return null;
  }

  // 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await loadTokensFromStorage();
    _isInitialized = true;

    // App启动时，如果已有用户信息就立即同步到dsnbc
    if (_userInfo != null) {
      if (kDebugMode) {
        print('🔄 App启动，开始同步用户信息到dsnbc...');
      }
      await _syncUserToDsnbc();
    }
  }

  // 生成授权URL
  String getAuthorizationUrl() {
    final params = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'user:base,file:all:read,file:all:write', // 根据官方文档设置权限范围
      'response_type': 'code',
      'state': DateTime.now().millisecondsSinceEpoch
          .toString(), // 添加state参数防止CSRF攻击
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final authUrl = '$_baseUrl/oauth/authorize?$queryString';
    return authUrl;
  }

  /// 获取阿里云盘空间信息（调用 adrive/v1.0/user/getSpaceInfo）
  Future<Map<String, dynamic>?> getSpaceInfo() async {
    if (!await isAuthorized()) return null;
    try {
      final tokenType = _tokenType ?? 'Bearer';
      final authHeader = '$tokenType $_accessToken';
      final response = await http.post(
        Uri.parse('https://openapi.alipan.com/adrive/v1.0/user/getSpaceInfo'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: '{}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['personal_space_info'] ?? data;
      }
    } catch (e) {
      debugPrint('❌ getSpaceInfo: $e');
    }
    return null;
  }

  /// 全局获取driveId
  static Future<String?> getGlobalDriveId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('aliyun_drive_id');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取全局driveId失败: $e');
      }
      return null;
    }
  }

  // 同步用户信息到 dsnbc
  Future<void> _syncUserToDsnbc() async {
    try {
      if (_userInfo == null || !_isInitialized) {
        if (kDebugMode) {
          print('⚠️ 跳过同步到dsnbc: 服务未初始化或无用户信息');
        }
        return;
      }

      final userInfo = _userInfo!;

      final userId = userInfo['id'] ?? userInfo['user_id'] as String?;
      final name =
          userInfo['nick_name'] ??
          userInfo['name'] ??
          userInfo['nickname'] as String?;
      final avatar = userInfo['avatar'] as String?;

      if (kDebugMode) {
        print('🔍 正在同步用户信息:');
        print('- ID: $userId');
        print('- 昵称: $name');
        print('- 头像: $avatar');
      }

      if (userId == null || name == null) {
        if (kDebugMode) {
          print('❌ 同步到dsnbc失败: 用户ID或昵称为空');
          print('原始数据: ${json.encode(userInfo)}');
        }
        return;
      }

      // 发送请求到 dsnbc
      final response = await http.post(
        Uri.parse('/userlogin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'name': name,
          'avatar': avatar ?? '', // 如果没有头像，发送空字符串
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ 用户信息已同步到dsnbc');
        }
      } else {
        if (kDebugMode) {
          print('❌ dsnbc同步失败: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ dsnbc同步异常: $e');
      }
    }
  }
}
