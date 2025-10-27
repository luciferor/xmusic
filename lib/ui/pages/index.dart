import 'package:cube_transition_plus/cube_transition_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmusic/services/cache_download_manager.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/cloudmusic.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/localdisk.dart';
import 'package:xmusic/ui/pages/dynamicon.dart';

import 'package:xmusic/ui/pages/mine.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/avatar_hero.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'dart:async';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/services/listening_stats_service.dart';

class Index extends StatefulWidget {
  const Index({super.key});
  @override
  State<Index> createState() => _IndexState();
}

class _IndexState extends State<Index> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final aliyunDriveService = AliyunDriveService();
  Map<String, dynamic>? _userInfo;
  String? _lastAvatarUrl; // 记录上次的头像URL
  bool _isAvatarReady = false; // 头像是否准备就绪
  bool _isFront = false; //云盘或本地

  // 提前缓存 widget 实例，使用 IndexedStack 来避免重建
  late final Widget _localDisk = Localdisk();
  late final Widget _cloudMusicList = CloudMusicList();

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  // 声明变量：获取总听歌时长（秒）
  final Future<int> totalListeningSeconds = ListeningStatsService()
      .getTotalSeconds();

  String _formatSecondsZH(int totalSeconds) {
    if (totalSeconds <= 0) return '0秒';
    int seconds = totalSeconds;
    const int secPerMinute = 60;
    const int secPerHour = 60 * secPerMinute;
    const int secPerDay = 24 * secPerHour;
    const int secPerMonth = 30 * secPerDay; // 粗略按30天/月
    const int secPerYear = 365 * secPerDay; // 粗略按365天/年

    final years = seconds ~/ secPerYear;
    seconds %= secPerYear;
    final months = seconds ~/ secPerMonth;
    seconds %= secPerMonth;
    final days = seconds ~/ secPerDay;
    seconds %= secPerDay;
    final hours = seconds ~/ secPerHour;
    seconds %= secPerHour;
    final minutes = seconds ~/ secPerMinute;
    seconds %= secPerMinute;

    final parts = <String>[];
    if (years > 0) parts.add('$years年');
    if (months > 0) parts.add('$months月');
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours小时');
    if (minutes > 0) parts.add('$minutes分钟');
    if (seconds > 0 || parts.isEmpty) parts.add('$seconds秒');
    return parts.join('');
  }

  @override
  void initState() {
    try {
      super.initState();
      _controller = AnimationController(
        duration: Duration(milliseconds: 800),
        vsync: this,
      );
      _animation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      );

      _initPackinfo();
      _loadUserInfo();
      _refreshUserInfoFromCloud();
      _cleanExpiredCache();
      _preloadAvatarFromCache();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Index initState 错误: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initPackinfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  /// 从缓存预加载头像到内存
  Future<void> _preloadAvatarFromCache() async {
    try {
      // 从本地存储获取用户信息
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('aliyun_user_info');
      if (userInfoString != null) {
        final userInfo = json.decode(userInfoString);
        final avatarUrl = userInfo['avatar'];

        if (avatarUrl != null && avatarUrl.toString().startsWith('http')) {
          if (kDebugMode) {
            print('⭐️ 启动时预加载头像到内存: $avatarUrl');
          }
          // 预加载头像到内存缓存
          final imageCacheService = ImageCacheService();
          await imageCacheService.getImageData(avatarUrl);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 预加载头像失败: $e');
      }
    }
  }

  /// 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    try {
      final imageCacheService = ImageCacheService();
      await imageCacheService.cleanExpiredCache();
      if (kDebugMode) {
        print('⭐️ 已清理过期缓存');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清理过期缓存失败: $e');
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('aliyun_user_info');
      if (userInfoString != null) {
        final userInfo = json.decode(userInfoString);
        setState(() {
          _userInfo = userInfo;
          // 检查头像是否有效
          final avatarUrl = userInfo['avatar'];
          if (avatarUrl != null && avatarUrl.toString().startsWith('http')) {
            _isAvatarReady = true;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ _loadUserInfo 错误: $e');
      }
    }
  }

  Future<void> _refreshUserInfoFromCloud() async {
    try {
      // 只有已授权才拉取
      if (await aliyunDriveService.isAuthorized()) {
        final userInfo = await aliyunDriveService.getUserInfo();
        if (userInfo != null) {
          setState(() {
            _userInfo = userInfo;
            // 检查头像是否有效
            final avatarUrl = userInfo['avatar'];
            if (avatarUrl != null && avatarUrl.toString().startsWith('http')) {
              _isAvatarReady = true;
            }
          });

          // 预加载头像到本地缓存
          final avatarUrl = userInfo['avatar'];
          if (avatarUrl != null && avatarUrl.toString().startsWith('http')) {
            // 检查头像URL是否发生变化
            if (_lastAvatarUrl != null && _lastAvatarUrl != avatarUrl) {
              if (kDebugMode) {
                print('🔄 检测到头像URL变化，刷新缓存: $_lastAvatarUrl -> $avatarUrl');
              }
              // 清除旧头像缓存并刷新新头像
              final imageCacheService = ImageCacheService();
              await imageCacheService.refreshAvatarCache(avatarUrl);
            } else if (_lastAvatarUrl == null) {
              if (kDebugMode) {
                print('⭐️ 首次加载头像，预加载到本地缓存: $avatarUrl');
              }
              // 立即预加载到内存缓存，避免闪烁
              final imageCacheService = ImageCacheService();
              await imageCacheService.getImageData(avatarUrl);
            }

            // 更新记录的头像URL
            _lastAvatarUrl = avatarUrl;

            // 打印缓存统计信息
            Future.delayed(Duration(seconds: 2), () {
              if (kDebugMode) {
                final imageCacheService = ImageCacheService();
                imageCacheService.printCacheStats();
              }
            });
          }
        }
        // 初始化缓存下载管理器
        await CacheDownloadManager().init();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ _refreshUserInfoFromCloud 错误: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.find<PlayerUIController>();
    // 优先用本地和内存中的 userInfo
    final memoryUserInfo = aliyunDriveService.userInfo;

    // 优化头像获取逻辑，避免显示默认头像
    String? avatar;
    if (_isAvatarReady &&
        _userInfo?['avatar'] != null &&
        _userInfo!['avatar'].toString().startsWith('http')) {
      avatar = _userInfo!['avatar'];
    } else if (memoryUserInfo?['avatar'] != null &&
        memoryUserInfo!['avatar'].toString().startsWith('http')) {
      avatar = memoryUserInfo!['avatar'];
    } else if (aliyunDriveService.driveInfo?['avatar'] != null &&
        aliyunDriveService.driveInfo!['avatar'].toString().startsWith('http')) {
      avatar = aliyunDriveService.driveInfo!['avatar'];
    }

    final name =
        _userInfo?['name'] ??
        memoryUserInfo?['name'] ??
        aliyunDriveService.driveInfo?['name'] ??
        aliyunDriveService.driveInfo?['nick_name'] ??
        '荧惑音乐';

    return Scaffold(
      body: Base(
        child: Column(
          children: [
            SizedBox(height: 20.rpx(context)),
            // 顶部UI
            Container(
              color: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
              height: 80.rpx(context),
              child: Row(
                children: [
                  // 头像
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => Mine()),
                      );
                    },
                    child: avatar != null
                        ? AvatarHero(
                            avatar: avatar,
                            size: 80.rpx(context),
                            radius: 50.rpx(context),
                          )
                        : Container(
                            width: 80.rpx(context),
                            height: 80.rpx(context),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.person_fill,
                              color: Colors.grey[600],
                              size: 30.rpx(context),
                            ),
                          ),
                  ),
                  SizedBox(width: 20.rpx(context)),
                  // 昵称
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradientText(
                          name,
                          style: TextStyle(
                            fontSize: 32.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color(0x50D6E2F6),
                              Color(0xC7D5F9F6),
                              Color(0xFFFFFFFF),
                            ], // 绿色到蓝色
                          ),
                        ),
                        FutureBuilder<int>(
                          future: totalListeningSeconds,
                          builder: (context, snapshot) {
                            final text = snapshot.hasData
                                ? '您已听歌：${_formatSecondsZH(snapshot.data!)}'
                                : '听歌时长：计算中...';
                            return GradientText(
                              text,
                              style: TextStyle(fontSize: 20.rpx(context)),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x81FFFFFF),
                                  Color(0x8DD5F9F6),
                                  Color(0x50D6E2F6),
                                ], // 绿色到蓝色
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // 设置按钮
                  IconButton(
                    alignment: Alignment.centerRight,
                    iconSize: 80.rpx(context),
                    padding: EdgeInsets.zero,
                    icon: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.rpx(context)),
                      ),
                      child: Icon(
                        CupertinoIcons.settings,
                        size: 50.rpx(context),
                        color: Colors.white38,
                      ),
                      // AnimatedSwitcher(
                      //   duration: Duration(milliseconds: 300),
                      //   transitionBuilder:
                      //       (Widget child, Animation<double> animation) {
                      //         return ScaleTransition(
                      //           scale: animation,
                      //           child: FadeTransition(
                      //             opacity: animation,
                      //             child: child,
                      //           ),
                      //         );
                      //       },
                      //   child: Image.asset(
                      //     _isFront
                      //         ? 'assets/images/localdisk.png'
                      //         : 'assets/images/alipan.png',
                      //     key: ValueKey(_isFront), // 关键：为不同状态设置不同的key
                      //     width: 50.rpx(context),
                      //     height: 50.rpx(context),
                      //   ),
                      // ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Get.toNamed('/dynamicon');
                      // Navigator.of(context).push(
                      //   CubePageRoute(
                      //     enterPage: Dynamicon(),
                      //     exitPage: context.widget,
                      //     duration: const Duration(milliseconds: 900),
                      //   ),
                      // );
                      // if (_controller.status == AnimationStatus.completed) {
                      //   _controller.reverse();
                      // } else {
                      //   _controller.forward();
                      // }
                      // setState(() {
                      //   _isFront = !_isFront;
                      // });
                    },
                  ),
                ],
              ),
            ),
            //收藏列表
            // Fav(),
            //歌单
            // Songsclass(),
            // 用 Obx 包裹 CloudMusicList，确保响应式刷新
            Expanded(
              child:
                  // 使用3D翻转动画 + 缩放效果 + 透明度变化
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final angle =
                          _animation.value * 3.14159; // π radians = 180 degrees
                      final isAnimating = _controller.isAnimating;

                      // 根据角度值确定当前应该显示哪个组件
                      final shouldShowLocalDisk = angle < 1.57;
                      final shouldShowCloudMusic = angle >= 1.57;

                      // 计算缩放值：开始时缩小，中间最小，结束时放大
                      double scale;
                      if (_animation.value <= 0.5) {
                        // 前半段：从1.0缩小到0.7
                        scale = 1.0 - (0.3 * (_animation.value / 0.5));
                      } else {
                        // 后半段：从0.7放大到1.0
                        scale = 0.7 + (0.3 * ((_animation.value - 0.5) / 0.5));
                      }

                      // 计算透明度值：开始时降低，中间最低，结束时恢复
                      double opacity;
                      if (_animation.value <= 0.5) {
                        // 前半段：从1.0降低到0.4
                        opacity = 1.0 - (0.6 * (_animation.value / 0.5));
                      } else {
                        // 后半段：从0.4恢复到1.0
                        opacity =
                            0.4 + (0.6 * ((_animation.value - 0.5) / 0.5));
                      }

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: IndexedStack(
                            index: shouldShowLocalDisk ? 0 : 1,
                            children: [
                              // 正面卡片 - 本地音乐
                              RepaintBoundary(
                                child: Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // 透视效果
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: Opacity(
                                    opacity: shouldShowLocalDisk ? 1.0 : 0.0,
                                    child: IgnorePointer(
                                      ignoring:
                                          !shouldShowLocalDisk || isAnimating,
                                      child: _cloudMusicList,
                                    ),
                                  ),
                                ),
                              ),

                              // 背面卡片 - 云音乐
                              RepaintBoundary(
                                child: Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // 透视效果
                                    ..rotateY(angle - 3.14159), // 减去π来纠正方向
                                  alignment: Alignment.center,
                                  child: Opacity(
                                    opacity: shouldShowCloudMusic ? 1.0 : 0.0,
                                    child: IgnorePointer(
                                      ignoring:
                                          !shouldShowCloudMusic || isAnimating,
                                      child: _localDisk,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
