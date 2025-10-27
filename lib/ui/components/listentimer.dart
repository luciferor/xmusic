import 'dart:convert';
import 'dart:math';

import 'package:cube_transition_plus/cube_transition_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:glossy/glossy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/services/favorite_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/pages/appinfo.dart';
import 'package:xmusic/ui/pages/mine.dart';
import 'package:xmusic/ui/pages/player.dart';

class Listentimer extends StatefulWidget {
  const Listentimer({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _ListentimerState createState() => _ListentimerState();
}

class _ListentimerState extends State<Listentimer> {
  final controller = Get.find<PlayerUIController>();
  final playlistService = Get.find<PlaylistService>();
  final aliyunDriveService = AliyunDriveService();
  Map<String, dynamic>? _userInfo;
  @override
  void initState() {
    super.initState();
    // 移除这里的初始化，改为在 build 中使用 Obx 响应式获取
    _loadUserInfo();
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

  @override
  Widget build(BuildContext context) {
    final favoriteService = Get.find<FavoriteService>();
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

    String? userid = _userInfo?['userid'];

    return SizedBox(
      height: 300.rpx(context),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(width: 7.rpx(context), color: Colors.white24),
              borderRadius: BorderRadius.circular(47.rpx(context)),
            ),
            child: _buildCollect(context, favoriteService),
          ),
          SizedBox(width: 20.rpx(context)),
          Expanded(
            child: Column(
              children: [
                _itemsbgs(
                  context,
                  Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.rpx(context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(width: 20.rpx(context)),
                            _buildSongInfo(context, controller),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(
                                  120.rpx(context),
                                ),
                              ),
                              padding: EdgeInsets.all(7.rpx(context)),
                              margin: EdgeInsets.all(10.rpx(context)),
                              width: 100.rpx(context),
                              height: 100.rpx(context),
                              child: _buildCoverImage(context, controller),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 32.rpx(context),
                        top: 10.rpx(context),
                        child: Obx(() {
                          final playlistLength = controller.playlist.length;
                          return Container(
                            alignment: Alignment.center,
                            child: Text(
                              playlistLength.toString(),
                              style: TextStyle(
                                fontSize: 20.rpx(context),
                                color: Colors.white12,
                                fontFamily: 'Nufei',
                              ),
                            ),
                          );
                        }),
                      ),
                      Positioned.fill(
                        child: Obx(() {
                          final progress = controller.progressPercentage;
                          return IgnorePointer(
                            child: CustomPaint(
                              painter: RRectProgressBorderPainter(
                                progress: progress,
                                borderWidth: 5.rpx(context),
                                borderRadius: 40.rpx(context),
                                colors: const [
                                  Color.fromARGB(10, 255, 255, 255),
                                  Color.fromARGB(50, 255, 255, 255),
                                  Color.fromARGB(150, 255, 255, 255),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  EdgeInsets.all(0),
                  double.infinity,
                  140.rpx(context),
                  40.rpx(context),
                  () {
                    // Get.toNamed('/player');
                    Navigator.of(context).push(
                      CubePageRoute(
                        enterPage: Player(),
                        exitPage: Base(child: Container()),
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20.rpx(context)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _itemsbgs(
                          context,
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    40.rpx(context),
                                  ),
                                  border: Border.all(
                                    width: 2.rpx(context),
                                    color: Colors.white10,
                                  ),
                                ),
                                child: Obx(() {
                                  final info =
                                      getRandomPlaylistCoverAndFileId();
                                  return Container(
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        39.rpx(context),
                                      ),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                      child: CachedImage(
                                        key: ValueKey(
                                          info['fileId'] ??
                                              info['coverUrl'] ??
                                              '',
                                        ),
                                        imageUrl: info['coverUrl'].toString(),
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.grey[800],
                                          child: Icon(
                                            CupertinoIcons.music_note,
                                            color: Colors.grey[600],
                                            size: 30,
                                          ),
                                        ),
                                        errorWidget: Image.asset(
                                          'assets/images/Hi-Res.png',
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                        cacheKey: info['fileId'],
                                        fadeIn: false,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: EdgeInsetsGeometry.all(
                                    20.rpx(context),
                                  ),
                                  child: GradientText(
                                    '我的歌单',
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.fromARGB(100, 255, 255, 255),
                                        Color.fromARGB(200, 255, 255, 255),
                                        Color.fromARGB(255, 255, 255, 255),
                                      ], // 绿色到蓝色
                                    ),
                                    style: TextStyle(
                                      fontSize: 32.rpx(context),
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          // 轻微下投影
                                          offset: Offset(0, 1),
                                          blurRadius: 3,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 20.rpx(context),
                                top: 10.rpx(context),
                                child: Text(
                                  '${playlistService.playlists.length}',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 49.rpx(context),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Mango',
                                    shadows: [
                                      Shadow(
                                        // 轻微下投影
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          EdgeInsets.all(0),
                          double.infinity,
                          140.rpx(context),
                          40.rpx(context),
                          () {
                            Get.toNamed('/songslib');
                          },
                        ),
                      ),
                      SizedBox(width: 20.rpx(context)),
                      _itemsbgs(
                        context,
                        Container(
                          color: Colors.transparent,
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 7.rpx(context),
                                  crossAxisSpacing: 7.rpx(context),
                                ),
                            itemCount: 4,
                            itemBuilder: (context, index) {
                              final item = controller.playlist[index];
                              final fileId =
                                  item['fileId'] ??
                                  item['file_id'] ??
                                  item['id'] ??
                                  '';
                              final coverUrl =
                                  item['cover_url'] ??
                                  item['cover'] ??
                                  item['thumbnail'] ??
                                  '';
                              return ClipRRect(
                                borderRadius: BorderRadiusGeometry.circular(
                                  20.rpx(context),
                                ),
                                child: CachedImage(
                                  imageUrl: coverUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.grey[800],
                                    child: Icon(
                                      Icons.music_note,
                                      color: Colors.grey[600],
                                      size: 30,
                                    ),
                                  ),
                                  errorWidget: Image.asset(
                                    'assets/images/Hi-Res.png',
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  cacheKey: fileId,
                                ),
                              ); //favoriteService.favoriteTracks
                            },
                          ),
                        ),
                        EdgeInsets.all(15.rpx(context)),
                        140.rpx(context),
                        140.rpx(context),
                        40.rpx(context),
                        () async {
                          HapticFeedback.lightImpact();
                          Get.toNamed('/listening');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> getRandomPlaylistCoverAndFileId() {
    if (playlistService.playlists.isEmpty) {
      return {'fileId': '', 'coverUrl': ''};
    }

    // 过滤掉 tracks 为空的
    final validPlaylists = playlistService.playlists
        .where((p) => p['tracks'] is List && (p['tracks']?.isNotEmpty ?? false))
        .toList();

    if (validPlaylists.isEmpty) {
      return {'fileId': '', 'coverUrl': ''};
    }

    // 随机挑一个
    final randomPlaylist =
        validPlaylists[Random().nextInt(validPlaylists.length)];
    final track = randomPlaylist['tracks'][0] as Map<String, dynamic>?;

    final fileId = track?['fileId'] ?? track?['file_id'] ?? track?['id'] ?? '';

    final coverUrl =
        track?['cover_url'] ?? track?['cover'] ?? track?['thumbnail'] ?? '';

    return {'fileId': fileId, 'coverUrl': coverUrl};
  }

  Widget _buildCollect(BuildContext context, FavoriteService favoriteService) {
    // 检查收藏列表是否为空
    if (favoriteService.favoriteTracks.isEmpty) {
      return _itemsbgs(
        context,
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.heart_slash,
              color: Colors.white60,
              size: 80.rpx(context),
            ),
            SizedBox(height: 20.rpx(context)),
            GradientText(
              '还没有喜欢的',
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(50, 255, 255, 255),
                  Color.fromARGB(100, 255, 255, 255),
                  Color.fromARGB(255, 255, 255, 255),
                ], // 绿色到蓝色
              ),
              style: TextStyle(
                fontSize: 28.rpx(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        EdgeInsets.all(30.rpx(context)),
        300.rpx(context),
        300.rpx(context),
        40.rpx(context),
        () {
          Get.toNamed('/favorites');
        },
      );
    }
    final favoriteTrack = favoriteService.favoriteTracks.toList()[0];
    final coverUrl =
        favoriteTrack['cover_url'] ??
        favoriteTrack['cover'] ??
        favoriteTrack['thumbnail'] ??
        '';
    final ffileId = favoriteTrack['file_id'] ?? favoriteTrack['id'] ?? '';
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Get.toNamed('/favorites');
          },
          child: Container(
            width: 300.rpx(context),
            height: 300.rpx(context),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40.rpx(context)),
            ),
            child: Hero(
              tag: 'tag-$ffileId',
              flightShuttleBuilder:
                  (context, animation, direction, fromContext, toContext) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(40.rpx(context)),
                      child: toContext.widget,
                    );
                  },
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 800),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: coverUrl.isNotEmpty
                    ? CachedImage(
                        imageUrl: coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.music_note,
                            color: Colors.grey[600],
                            size: 30,
                          ),
                        ),
                        errorWidget: Image.asset(
                          'assets/images/Hi-Res.png',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        cacheKey: ffileId,
                      )
                    : Image.asset(
                        'assets/images/Hi-Res.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(BuildContext context, PlayerUIController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100.rpx(context)),
      child: Obx(() {
        final playlist = controller.playlist;
        final idx = controller.currentIndex.value;
        final currentSong =
            playlist.isNotEmpty && idx >= 0 && idx < playlist.length
            ? playlist[idx]
            : null;

        // 使用旋转的封面组件，直接传递当前歌曲信息
        return RotatingCoverImage(
          currentSong: currentSong,
          isPlaying: controller.isPlaying.value,
          size: double.infinity,
          controller: controller,
        );
      }),
    );
  }

  Widget _buildSongInfo(BuildContext context, PlayerUIController controller) {
    return Expanded(
      child: Container(
        alignment: Alignment.centerLeft,
        color: Colors.transparent,
        child: Obx(() {
          final playlist = controller.playlist;
          final idx = controller.currentIndex.value;
          final currentSong =
              playlist.isNotEmpty && idx >= 0 && idx < playlist.length
              ? playlist[idx]
              : null;
          final title = currentSong?['title'] ?? '未知歌曲';
          final artist = currentSong?['artist'] ?? '未知艺术家';

          // 获取当前歌词
          final currentLyric = controller.currentLyric.value;

          // 检查歌词开关状态
          bool showLyrics = false;
          try {
            final boController = Get.find<BlurOpacityController>();
            showLyrics = boController.isEnabled.value;
          } catch (e) {
            // 如果获取开关状态失败，默认显示歌词
            showLyrics = false;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GradientText(
                '$title',
                style: TextStyle(
                  fontSize: 28.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
                gradient: LinearGradient(
                  colors: [
                    Color(0x13FFFFFF),
                    Color(0x63FFFFFF),
                    Color(0xFFFFFFFF),
                  ], // 绿色到蓝色
                ),
              ),
              SizedBox(height: 10.rpx(context)),
              // 歌曲信息
              GradientText(
                showLyrics && currentLyric.isNotEmpty
                    ? currentLyric
                    : '$title-$artist',
                style: TextStyle(
                  fontSize: 20.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 255, 255, 255),
                    Color.fromARGB(148, 255, 255, 255),
                    Color.fromARGB(0, 255, 255, 255),
                  ], // 绿色到蓝色
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _itemsbgs(
    BuildContext context,
    Widget childl,
    EdgeInsets padding,
    double width,
    double height,
    double radius,
    VoidCallback callback,
  ) {
    return Bounceable(
      onTap: () {
        // 添加点击反馈
        HapticFeedback.lightImpact();
        callback();
      },
      child: GlossyContainer(
        width: width,
        height: height,
        strengthX: 7,
        strengthY: 7,
        gradient: GlossyLinearGradient(
          colors: [
            Color.fromARGB(0, 241, 255, 255),
            Color.fromARGB(0, 214, 255, 252),
            Color.fromARGB(0, 231, 255, 251),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          opacity: 0.2,
        ),
        border: BoxBorder.all(
          color: const Color.fromARGB(30, 255, 255, 255),
          width: 1.rpx(context),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(0, 168, 154, 154),
            blurRadius: 30.rpx(context),
          ),
        ],
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: childl,
        ),
      ),
    );
  }
}

class RotatingCoverImage extends StatefulWidget {
  final Map<String, dynamic>? currentSong;
  final bool isPlaying;
  final double size;
  final PlayerUIController controller;

  const RotatingCoverImage({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.size,
    required this.controller,
  });

  @override
  // ignore: library_private_types_in_public_api
  _RotatingCoverImageState createState() => _RotatingCoverImageState();
}

class _RotatingCoverImageState extends State<RotatingCoverImage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    // 检查初始播放状态，如果正在播放就立即启动动画
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        widget.currentSong?['cover'] ?? widget.currentSong?['cover_url'] ?? '';
    final fileId =
        widget.currentSong?['file_id'] ??
        widget.currentSong?['fileId'] ??
        widget.currentSong?['id'] ??
        '';
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          RotationTransition(
            turns: _animationController,
            child: ClipOval(
              child: coverUrl.isNotEmpty
                  ? CachedImage(
                      imageUrl: coverUrl,
                      cacheKey: fileId,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        width: widget.size,
                        height: widget.size,
                        color: Colors.grey[800],
                        child: Center(
                          child: Image.asset('assets/images/Hi-Res.png'),
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/images/Hi-Res.png',
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned.fill(
            child: Container(
              width: widget.size * 0.2,
              height: widget.size * 0.2,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Bounceable(
                onTap: () async {
                  // 添加点击反馈
                  HapticFeedback.lightImpact();
                  await widget.controller.togglePlay();
                },
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Icon(
                    widget.isPlaying
                        ? CupertinoIcons.pause_solid
                        : CupertinoIcons.play_fill,
                    size: 40.rpx(context),
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SlideUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    final offsetAnimation = animation.drive(tween);

    // 只对新页面应用动画，背景页面保持不动
    return SlideTransition(position: offsetAnimation, child: child);
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

class SlideUpRoute extends PageRouteBuilder {
  final Widget child;

  SlideUpRoute({required this.child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;
}

// 绘制圆角矩形进度边框
class RRectProgressBorderPainter extends CustomPainter {
  final double progress; // 0.0 ~ 1.0
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;
  final Color baseTrackColor;
  final double baseTrackOpacity;

  RRectProgressBorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.borderRadius,
    required this.colors,
    this.baseTrackColor = Colors.transparent,
    this.baseTrackOpacity = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double p = progress;
    // 允许传 0-1 或 0-100 两种进度表示
    if (p > 1.0) {
      p = (p <= 100.0) ? (p / 100.0) : 1.0;
    }
    final clamped = p.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final double inset = borderWidth / 2.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(borderRadius - inset),
    );
    final path = Path()..addRRect(rect);

    final metrics = path.computeMetrics();
    if (!metrics.iterator.moveNext()) {
      return;
    }
    final metric = metrics.iterator.current;
    final drawLength = metric.length * clamped;

    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.5, 1.0],
    );

    // 背景轨道（完整边框，低透明度，便于可见性）
    final basePaint = Paint()
      ..color = baseTrackColor.withAlpha((baseTrackOpacity * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, basePaint);

    final paintStroke = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final extract = metric.extractPath(0, drawLength);
    canvas.drawPath(extract, paintStroke);
  }

  @override
  bool shouldRepaint(covariant RRectProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.colors != colors;
  }
}
