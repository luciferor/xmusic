import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/services/listening_stats_service.dart';
import 'package:xmusic/ui/components/avatar_hero.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:flutter/foundation.dart';
import 'package:marquee/marquee.dart';

class ListenIng extends StatefulWidget {
  const ListenIng({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListenIngState createState() => _ListenIngState();
}

class _ListenIngState extends State<ListenIng> {
  final playerController = Get.find<PlayerUIController>();
  final aliyunDriveService = AliyunDriveService();
  Map<String, dynamic>? _userInfo;

  final ListeningStatsService _statsService = ListeningStatsService();

  Map<String, dynamic> _statsOverview = {};

  List<Color> gradientColors = [
    // const Color.fromARGB(9, 61, 135, 255),
    // const Color.fromARGB(146, 127, 253, 255),
    // const Color.fromARGB(198, 102, 0, 255),
    Color(0xFFFF6CAB),
    Color(0xFFFFD452),
    Color(0xFF8AFF6C),
    Color(0xFF55D3FF),
    Color(0xFFB388FF),
    Color(0xFFFF6CAB),
  ];

  bool showLyrics = false;

  @override
  void initState() {
    super.initState();
    // 检查歌词开关状态
    try {
      final boController = Get.find<BlurOpacityController>();
      showLyrics = boController.isEnabled.value;
    } catch (e) {
      // 如果获取开关状态失败，默认显示歌词
      showLyrics = false;
    }
    _loadStatsData();
    _loadUserInfo();

    // 添加调试信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        print('🎵 ListenIng页面初始化完成');
        print('🎵 播放列表长度: ${playerController.playlist.length}');
        print('🎵 当前播放索引: ${playerController.currentIndex.value}');
        if (playerController.playlist.isNotEmpty) {
          print('🎵 播放列表第一首: ${playerController.playlist.first}');
        }
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('aliyun_user_info');
    if (userInfoString != null) {
      setState(() {
        _userInfo = json.decode(userInfoString);
      });
    }
  }

  Future<void> _loadStatsData() async {
    try {
      // 首先尝试加载本地数据
      final overview = await _statsService.getStatsOverview();

      // 检查本地数据是否为空
      final totalSeconds = overview['totalSeconds'] ?? 0;
      final todaySeconds = overview['todaySeconds'] ?? 0;

      // 如果本地数据为0，尝试从服务器拉取数据
      if (totalSeconds == 0 && todaySeconds == 0) {
        if (kDebugMode) {
          print('🔄 本地数据为空，尝试从服务器拉取数据...');
        }

        // 显示加载提示
        setState(() {
          _statsOverview = overview;
        });

        // 从服务器同步数据
        final syncSuccess = await _statsService.syncServerDataToLocal();

        if (syncSuccess) {
          if (kDebugMode) {
            print('✅ 服务器数据同步成功，重新加载本地数据');
          }

          // 重新加载本地数据（现在应该包含服务器数据）
          final newOverview = await _statsService.getStatsOverview();

          setState(() {
            _statsOverview = newOverview;
          });

          if (kDebugMode) {
            print('📊 同步后的听歌统计数据:');
            print('  - 总听歌时长: ${newOverview['totalSeconds']}秒');
            print('  - 今日听歌时长: ${newOverview['todaySeconds']}秒');
          }
        } else {
          if (kDebugMode) {
            print('❌ 服务器数据同步失败，使用本地空数据');
          }

          setState(() {
            _statsOverview = overview;
          });
        }
      } else {
        // 本地有数据，直接使用
        if (kDebugMode) {
          print('✅ 本地有数据，无需从服务器拉取');
        }

        setState(() {
          _statsOverview = overview;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载听歌统计数据失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStreak = _statsOverview['currentStreak'] ?? 0;
    final memoryUserInfo = aliyunDriveService.userInfo;
    // 优化头像获取逻辑，避免显示默认头像
    String? avatar;
    if (_userInfo?['avatar'] != null &&
        _userInfo?['avatar']?.toString().startsWith('http') == true) {
      avatar = _userInfo?['avatar'];
    } else if (memoryUserInfo?['avatar'] != null &&
        memoryUserInfo?['avatar']?.toString().startsWith('http') == true) {
      avatar = memoryUserInfo?['avatar'];
    } else if (aliyunDriveService.driveInfo?['avatar'] != null &&
        aliyunDriveService.driveInfo?['avatar']?.toString().startsWith(
              'http',
            ) ==
            true) {
      avatar = aliyunDriveService.driveInfo?['avatar'];
    }

    final name =
        _userInfo?['name'] ??
        memoryUserInfo?['name'] ??
        aliyunDriveService.driveInfo?['name'] ??
        aliyunDriveService.driveInfo?['nick_name'] ??
        '荧惑音乐';
    return Base(
      child: Column(
        children: [
          // 顶部导航栏
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),

            child: Row(
              children: [
                Re(),
                Expanded(child: Container()),
              ],
            ),
          ),
          SizedBox(height: 30.rpx(context)),
          Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            height: 80.rpx(context),
            child: Row(
              children: [
                // 头像
                avatar != null
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
                          fontSize: 28.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Color(0x2FD6E2F6),
                            Color(0xC7D5F9F6),
                            Color(0xFFFFFFFF),
                          ], // 绿色到蓝色
                        ),
                      ),
                      GradientText(
                        '已连续听歌：$currentStreak天，当前歌曲：${playerController.playlist[playerController.currentIndex.value]['title']}',
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0x95FFFFFF),
                            Color(0x1EFFFFFF),
                          ], // 绿色到蓝色
                        ),
                        style: TextStyle(fontSize: 20.rpx(context)),
                      ),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.topRight,
                  child: Obx(() {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GradientText(
                          '${playerController.playlist.length}',
                          style: TextStyle(
                            fontSize: 28.rpx(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nufei',
                            letterSpacing: 4.rpx(context),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color(0x31737CFF),
                              Color(0x95737CFF),
                              Color(0xFF737CFF),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.rpx(context)),
          // Container(
          //   height: 200.rpx(context),
          //   margin: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
          //   decoration: BoxDecoration(
          //     color: Colors.white10,
          //     borderRadius: BorderRadius.circular(50.rpx(context)),
          //   ),
          // ),
          // 内容区域
          Expanded(
            child: Obx(() {
              if (playerController.playlist.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.music_note,
                        size: 80.rpx(context),
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 20.rpx(context)),
                      Text(
                        '暂无播放列表',
                        style: TextStyle(
                          fontSize: 32.rpx(context),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              // 建立对 currentIndex 的依赖，确保切歌后父级 Obx 触发重建
              final _ci = playerController.currentIndex.value;
              return ListView.builder(
                padding: EdgeInsets.only(
                  top: 20.rpx(context),
                  bottom: 40.rpx(context),
                ),
                physics: BouncingScrollPhysics(),
                itemCount: playerController.playlist.length,
                itemBuilder: (context, index) {
                  final track = playerController.playlist[index];
                  return _buildItems(
                    context,
                    track,
                    index,
                    playerController.currentPlayingFileId,
                    playerController.isPlaying.value,
                    playerController,
                    playerController.currentLyric.value,
                    showLyrics,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(
    BuildContext context,
    Map<String, dynamic> item,
    int itemIndex,
    String? currentFileId,
    bool isPlaying,
    PlayerUIController controller,
    String currentLyric,
    bool showLyrics,
  ) {
    final coverUrl = item['cover'] ?? item['cover_url'] ?? '';
    final fileId = item['file_id'] ?? item['fileId'] ?? item['id'] ?? '';
    final bool isCurrent = currentFileId != null && currentFileId == fileId;

    // 获取文件扩展名和标签
    final ext =
        (item['extension'] ?? (item['name']?.toString().split('.').last ?? ''))
            .toLowerCase();
    String? tag;
    tag = ext.toUpperCase();
    // if (ext == 'flac' || ext == 'wav' || ext == 'ape' || ext == 'alac') {
    //   tag = '无损';
    // } else if (ext == 'mp3') {
    //   tag = 'MP3';
    // } else if (ext == 'aac') {
    //   tag = 'AAC';
    // } else if (ext == 'ogg') {
    //   tag = 'OGG';
    // } else if (ext == 'm4a') {
    //   tag = 'M4A';
    // } else if (item['category'] == 'audio') {
    //   tag = 'SQ';
    // }

    // 获取文件大小
    final fileSize = item['size'] as int? ?? 0;
    String sizeStr = fileSize > 0
        ? ('${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB')
        : '';

    // 获取艺术家信息
    String artist = item['artist']?.isNotEmpty == true
        ? item['artist']
        : (item['album']?.isNotEmpty == true ? item['album'] : '未知艺术家');

    // 获取标题
    String title = item['title'] ?? item['name'] ?? '';
    if (title.isEmpty || title == item['name']) {
      title = item['name'] ?? '';
      if (title.contains('.')) {
        title = title.substring(0, title.lastIndexOf('.'));
      }
    }

    return Container(
      margin: EdgeInsets.only(left: 40.rpx(context), right: 40.rpx(context)),
      child: Container(
        padding: EdgeInsets.all(20.rpx(context)),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.white10 : Colors.transparent,
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 255, 255, 255),
              Colors.transparent,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(40.rpx(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.rpx(context)),
          onTap: () async {
            // 添加点击反馈
            HapticFeedback.lightImpact();
            await playerController.onMusicItemTap(itemIndex);
          },
          child: Row(
            children: [
              // 序号
              SizedBox(
                width: 50.rpx(context),
                child: isCurrent
                    ? GradientText(
                        (itemIndex + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 30.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2379FF),
                            Color(0xFF1EFBE9),
                            Color(0xFFA2FF7C),
                          ],
                        ),
                      )
                    : Text(
                        (itemIndex + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 28.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              SizedBox(width: 20.rpx(context)),
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(30.rpx(context)),
                child: coverUrl.isNotEmpty
                    ? CachedImage(
                        imageUrl: coverUrl,
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 90.rpx(context),
                          height: 90.rpx(context),
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.music_note,
                            color: Colors.grey[600],
                            size: 30,
                          ),
                        ),
                        errorWidget: Image.asset(
                          'assets/images/Hi-Res.png',
                          width: 90.rpx(context),
                          height: 90.rpx(context),
                          fit: BoxFit.cover,
                        ),
                        cacheKey: fileId,
                      )
                    : Image.asset(
                        'assets/images/Hi-Res.png',
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
                      ),
              ),
              SizedBox(width: 30.rpx(context)),
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 歌名
                    Container(
                      child: isCurrent
                          ? GradientText(
                              title,
                              style: TextStyle(
                                fontSize: 30.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2379FF),
                                  Color(0xFF1EFBE9),
                                  Color(0xFFA2FF7C),
                                ],
                              ),
                            )
                          : GradientText(
                              title,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x78D7E0FF),
                                  Color(0xB4D7E0FF),
                                  Color(0xFFD7E0FF),
                                ],
                              ),
                              style: TextStyle(fontSize: 28.rpx(context)),
                            ),
                    ),
                    SizedBox(height: 5.rpx(context)),
                    // 歌手+标签+文件大小
                    Row(
                      children: [
                        if (tag != null && tag == '无损')
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.rpx(context),
                              vertical: 3.rpx(context),
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 2.rpx(context),
                                color: Colors.greenAccent,
                              ),
                              borderRadius: BorderRadius.circular(
                                12.rpx(context),
                              ),
                            ),
                            child: Text(
                              tag.toString(),
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 15.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (tag != null && tag != '无损')
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.rpx(context),
                              vertical: 3.rpx(context),
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 2.rpx(context),
                                color: const Color(0xFF40FFBF),
                              ),
                              borderRadius: BorderRadius.circular(
                                12.rpx(context),
                              ),
                            ),
                            child: Text(
                              tag.toString(),
                              style: TextStyle(
                                color: const Color(0xFF40FF90),
                                fontSize: 15.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 10.rpx(context)),
                        Flexible(
                          child: Text(
                            artist,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 24.rpx(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sizeStr.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              sizeStr,
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 24.rpx(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 播放状态
              if (isCurrent)
                Container(
                  width: 60.rpx(context),
                  height: 60.rpx(context),
                  margin: EdgeInsets.only(left: 8.rpx(context), right: 0),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.rpx(context),
                    vertical: 10.rpx(context),
                  ),
                  child: PlayerIcon(isPlaying: isPlaying),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
