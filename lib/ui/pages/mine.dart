import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/listentimer.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/avatar_hero.dart';

class Mine extends StatefulWidget {
  const Mine({super.key});

  @override
  State<Mine> createState() => _MineState();
}

class _MineState extends State<Mine> {
  Map<String, dynamic>? _userInfo;
  final aliyunDriveService = AliyunDriveService();

  // 云盘容量信息缓存相关
  Map<String, dynamic>? _cachedSpaceInfo;
  DateTime? _spaceInfoCacheTime;
  static const int _cacheValidDays = 7;

  int isMember = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadCachedSpaceInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('aliyun_user_info');
    if (userInfoString != null) {
      setState(() {
        _userInfo = json.decode(userInfoString);
      });
      _getXmusicUsersInfo();
    }
  }

  Future<void> _getXmusicUsersInfo() async {
    try {
      final id = _userInfo?['id'];
      if (id == null) {
        if (kDebugMode) {
          print('❌ 用户ID为空，无法获取会员信息');
        }
        return;
      }

      final url = 'https://xxx/getisvip';
      if (kDebugMode) {
        print('🔄 正在获取会员信息: $url');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['message'] != null) {
          final message = data['message'];
          final memberStatus = message['is_member'] ?? 0;

          setState(() {
            isMember = memberStatus;
          });

          if (kDebugMode) {
            print('✅ 会员信息获取成功: isMember = $isMember');
          }
        } else {
          if (kDebugMode) {
            print('❌ API返回错误: ${data['message']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP请求失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取会员信息失败: $e');
      }
    }
  }

  // 加载缓存的云盘容量信息
  Future<void> _loadCachedSpaceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final spaceInfoString = prefs.getString('cached_space_info');
      final cacheTimeString = prefs.getString('cached_space_info_time');

      if (spaceInfoString != null && cacheTimeString != null) {
        final cacheTime = DateTime.parse(cacheTimeString);
        final now = DateTime.now();
        final daysSinceCache = now.difference(cacheTime).inDays;

        // 检查缓存是否过期（7天）
        if (daysSinceCache < _cacheValidDays) {
          setState(() {
            _cachedSpaceInfo = json.decode(spaceInfoString);
            _spaceInfoCacheTime = cacheTime;
          });
          if (kDebugMode) {
            print('⭐️ 使用缓存的云盘容量信息 ($daysSinceCache天前缓存)');
          }
        } else {
          if (kDebugMode) {
            print('⭐️ 云盘容量信息缓存已过期 ($daysSinceCache天前缓存)，需要重新获取');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('加载云盘容量信息缓存失败: $e');
      }
    }
  }

  // 缓存云盘容量信息
  Future<void> _cacheSpaceInfo(Map<String, dynamic> spaceInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_space_info', json.encode(spaceInfo));
      await prefs.setString(
        'cached_space_info_time',
        DateTime.now().toIso8601String(),
      );

      setState(() {
        _cachedSpaceInfo = spaceInfo;
        _spaceInfoCacheTime = DateTime.now();
      });
    } catch (e) {
      if (kDebugMode) {
        print('缓存云盘容量信息失败: $e');
      }
    }
  }

  // 获取云盘容量信息（带缓存）
  Future<Map<String, dynamic>?> _getSpaceInfoWithCache() async {
    // 如果有有效缓存，直接返回
    if (_cachedSpaceInfo != null && _spaceInfoCacheTime != null) {
      final now = DateTime.now();
      final daysSinceCache = now.difference(_spaceInfoCacheTime!).inDays;
      if (daysSinceCache < _cacheValidDays) {
        return _cachedSpaceInfo;
      }
    }

    // 缓存过期或不存在，从API获取
    try {
      final spaceInfo = await aliyunDriveService.getSpaceInfo();
      if (spaceInfo != null) {
        await _cacheSpaceInfo(spaceInfo);
        return spaceInfo;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取云盘容量信息失败: $e');
      }
      // 如果API获取失败但有过期缓存，返回过期缓存
      if (_cachedSpaceInfo != null) {
        if (kDebugMode) {
          print('⚠️ API获取失败，使用过期缓存');
        }
        return _cachedSpaceInfo;
      }
    }

    return null;
  }

  // 强制刷新云盘容量信息
  Future<void> _refreshSpaceInfo() async {
    // 添加点击反馈
    HapticFeedback.lightImpact();
    try {
      if (kDebugMode) {
        print('🔄 强制刷新云盘容量信息...');
      }
      final spaceInfo = await aliyunDriveService.getSpaceInfo();
      if (spaceInfo != null) {
        await _cacheSpaceInfo(spaceInfo);
        setState(() {}); // 触发UI刷新
        if (kDebugMode) {
          print('✅ 云盘容量信息刷新成功');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 强制刷新云盘容量信息失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memoryUserInfo = aliyunDriveService.userInfo;

    // 优化头像获取逻辑，避免显示默认头像
    String? avatar;
    if (_userInfo?['avatar'] != null &&
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

    final id = _userInfo?['id'];

    return Base(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 40.rpx(context)),
              width: MediaQuery.of(context).size.width,
              height: 80.rpx(context),
              child: Row(
                children: [
                  Re(),
                  Expanded(child: Container(color: Colors.transparent)),
                ],
              ),
            ),
            // 头像与昵称
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Get.toNamed('/users');
                  },
                  child: avatar != null
                      ? AvatarHero(
                          avatar: avatar,
                          size: 120.rpx(context),
                          radius: 60.rpx(context),
                        )
                      : Container(
                          width: 100.rpx(context),
                          height: 100.rpx(context),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.person_fill,
                            color: Colors.grey[600],
                            size: 40.rpx(context),
                          ),
                        ),
                ),

                SizedBox(width: 20.rpx(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GradientText(
                            name,
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(30, 255, 255, 255),
                                Color.fromARGB(150, 255, 255, 255),
                                Color.fromARGB(255, 255, 255, 255),
                              ], // 绿色到蓝色
                            ),
                            style: TextStyle(
                              fontSize: 32.rpx(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10.rpx(context)),
                          if (isMember == 1)
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/images/svip.svg',
                                  width: 50.rpx(context),
                                  height: 50.rpx(context),
                                ),
                                SizedBox(width: 5.rpx(context)),
                                Text(
                                  '超级会员',
                                  style: TextStyle(
                                    fontSize: 24.rpx(context),
                                    color: Color(0xFF9C80FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                          if (isMember == 0)
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/images/svip.svg',
                                  width: 50.rpx(context),
                                  height: 50.rpx(context),
                                  // ignore: deprecated_member_use
                                  color: Colors.white24,
                                ),
                                SizedBox(width: 5.rpx(context)),
                                Text(
                                  '普通用户',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              height: 50.rpx(context),
                              child: Bounceable(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  try {
                                    final aliyun = AliyunDriveService();
                                    await aliyun.clearTokens();
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('aliyun_user_info');
                                  } catch (_) {}
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                },
                                child: Icon(
                                  CupertinoIcons.smallcircle_fill_circle,
                                  color: Colors.white38,
                                  size: 50.rpx(context),
                                ),
                              ),
                              // GradientButton(
                              //   onPressed: () async {
                              //     HapticFeedback.lightImpact();
                              //     try {
                              //       final aliyun = AliyunDriveService();
                              //       await aliyun.clearTokens();
                              //       final prefs =
                              //           await SharedPreferences.getInstance();
                              //       await prefs.remove('aliyun_user_info');
                              //     } catch (_) {}
                              //     if (context.mounted) {
                              //       Navigator.of(
                              //         context,
                              //       ).pushNamedAndRemoveUntil(
                              //         '/login',
                              //         (route) => false,
                              //       );
                              //     }
                              //   },
                              //   gradientColors: [
                              //     Color.fromARGB(0, 70, 19, 255),
                              //     Color.fromARGB(98, 70, 19, 255),
                              //     Color.fromARGB(147, 70, 19, 255),
                              //   ],
                              //   padding: EdgeInsetsGeometry.symmetric(
                              //     horizontal: 20.rpx(context),
                              //     vertical: 0,
                              //   ),
                              //   borderRadius: 15.rpx(context),
                              //   child: Row(
                              //     crossAxisAlignment: CrossAxisAlignment.center,
                              //     mainAxisAlignment: MainAxisAlignment.center,
                              //     children: [
                              //       Icon(
                              //         CupertinoIcons
                              //             .arrow_2_circlepath_circle,
                              //         color: const Color(0x2FFFFFFF),
                              //         size: 30.rpx(context),
                              //       ),

                              //     ],
                              //   ),
                              // ),
                            ),
                          ),
                        ],
                      ),
                      _driveInfo(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      width: 200.rpx(context),
                      child: GradientText(
                        '我的歌单',
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(255, 255, 255, 255),
                            Color.fromARGB(100, 255, 255, 255),
                            Color.fromARGB(50, 255, 255, 255),
                          ], // 绿色到蓝色
                        ),
                        style: TextStyle(
                          fontSize: 32.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 30.rpx(context)),
                    Listentimer(),
                    SizedBox(height: 40.rpx(context)),
                    SizedBox(
                      width: 200.rpx(context),
                      child: GradientText(
                        '其它菜单',
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(255, 255, 255, 255),
                            Color.fromARGB(100, 255, 255, 255),
                            Color.fromARGB(50, 255, 255, 255),
                          ], // 绿色到蓝色
                        ),
                        style: TextStyle(
                          fontSize: 32.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildMenuItem(
                      '缓存管理',
                      Icon(
                        CupertinoIcons.cloud_download,
                        color: Colors.white60,
                        size: 40.rpx(context),
                      ),
                      () {
                        // 添加点击反馈
                        HapticFeedback.lightImpact();
                        Get.toNamed('/catchs');
                      },
                    ),

                    Divider(
                      color: const Color(0x09FFFFFF),
                      height: 1.rpx(context),
                      indent: 100.rpx(context),
                      endIndent: 40.rpx(context),
                    ),
                    _buildMenuItem(
                      '使用帮助',
                      Icon(
                        CupertinoIcons.question_diamond,
                        color: Colors.white60,
                        size: 40.rpx(context),
                      ),
                      () {
                        // 添加点击反馈
                        HapticFeedback.lightImpact();
                        Get.toNamed('/help');
                      },
                    ),
                    Divider(
                      color: const Color(0x09FFFFFF),
                      height: 1.rpx(context),
                      indent: 100.rpx(context),
                      endIndent: 40.rpx(context),
                    ),
                    _buildMenuItem(
                      '免责声明',
                      Icon(
                        CupertinoIcons.exclamationmark_shield,
                        color: Colors.white60,
                        size: 40.rpx(context),
                      ),
                      () {
                        // 添加点击反馈
                        HapticFeedback.lightImpact();
                        Get.toNamed('/mz');
                      },
                    ),
                    Divider(
                      color: const Color(0x09FFFFFF),
                      height: 1.rpx(context),
                      indent: 100.rpx(context),
                      endIndent: 40.rpx(context),
                    ),
                    _buildMenuItem(
                      '设置',
                      Icon(
                        CupertinoIcons.settings,
                        color: Colors.white60,
                        size: 40.rpx(context),
                      ),
                      () {
                        // 添加点击反馈
                        HapticFeedback.lightImpact();
                        Get.toNamed('/setting');
                      },
                    ),
                    Divider(
                      color: const Color(0x09FFFFFF),
                      height: 1.rpx(context),
                      indent: 100.rpx(context),
                      endIndent: 40.rpx(context),
                    ),
                    _buildMenuItem(
                      '关于荧惑',
                      Icon(
                        CupertinoIcons.exclamationmark_square,
                        color: Colors.white60,
                        size: 40.rpx(context),
                      ),
                      () {
                        // 添加点击反馈
                        HapticFeedback.lightImpact();
                        Get.toNamed('/appinfo');
                      },
                    ),
                  ],
                ),
              ),
            ),
            Copyright(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, Icon icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100.rpx(context),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 0.rpx(context)),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 60.rpx(context),
              height: 60.rpx(context),
              alignment: Alignment.center,
              child: Opacity(opacity: 0.3, child: icon),
            ),
            SizedBox(width: 20.rpx(context)),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                child: GradientText(
                  title,
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(50, 215, 224, 255),
                      Color.fromARGB(100, 215, 224, 255),
                      Color.fromARGB(255, 215, 224, 255),
                    ], // 绿色到蓝色
                  ),
                  style: TextStyle(
                    fontSize: 30.rpx(context),
                    // fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Container(
              width: 60.rpx(context),
              height: 60.rpx(context),
              alignment: Alignment.center,
              child: Icon(
                CupertinoIcons.chevron_forward,
                color: Colors.white24,
                size: 36.rpx(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driveInfo(BuildContext context) {
    return SizedBox(
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _getSpaceInfoWithCache(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('未获取到云盘容量', style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: _refreshSpaceInfo,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '刷新',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 24.rpx(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final used = info['used_size'] ?? 0;
                final total = info['total_size'] ?? 0;
                String formatSize(num size) {
                  if (size >= 1024 * 1024 * 1024) {
                    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
                  } else if (size >= 1024 * 1024) {
                    return '${(size / (1024 * 1024)).toStringAsFixed(2)}MB';
                  } else if (size >= 1024) {
                    return '${(size / 1024).toStringAsFixed(2)}KB';
                  } else {
                    return '${size}B';
                  }
                }

                // 检查是否使用缓存数据
                final isUsingCache =
                    _cachedSpaceInfo != null &&
                    _spaceInfoCacheTime != null &&
                    DateTime.now().difference(_spaceInfoCacheTime!).inDays <
                        _cacheValidDays;

                return GradientText(
                  '${formatSize(used)}/${formatSize(total)}',
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 255, 255, 255),
                      Color.fromARGB(50, 255, 255, 255),
                      Color.fromARGB(10, 255, 255, 255),
                    ], // 绿色到蓝色
                  ),
                  style: TextStyle(
                    fontSize: 28.rpx(context),
                    fontFamily: 'Nufei',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
