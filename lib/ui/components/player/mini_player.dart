import 'package:cube_transition_plus/cube_transition_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/blur.dart';
import 'package:xmusic/ui/components/color_filter_widget.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/pages/index.dart';
import 'package:xmusic/ui/pages/player.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/controllers/blurocontroller.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late BlurOpacityController _boController;

  @override
  void initState() {
    super.initState();
    _boController = Get.find<BlurOpacityController>();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerUIController>();
    return Container(
      height: 100.rpx(context),
      margin: EdgeInsets.fromLTRB(
        40.rpx(context),
        0,
        40.rpx(context),
        MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(80.rpx(context)),
        gradient: LinearGradient(
          colors: [
            Color(0xFFB8B8B8).withValues(alpha: 0.1),
            Color(0xFFD4D4D4).withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Obx(() {
        final brightness = _boController.brightness.value;
        final contrast = _boController.contrast.value;
        final saturation = _boController.saturation.value;
        final hue = _boController.hue.value;
        final grayscale = _boController.grayscale.value;
        final vibrance = _boController.vibrance.value;
        final exposure = _boController.exposure.value;
        final temperature = _boController.temperature.value;
        final tint = _boController.tint.value;
        final highlights = _boController.highlights.value;
        final shadows = _boController.shadows.value;
        final clarity = _boController.clarity.value;
        final sharpness = _boController.sharpness.value;
        final enabled = _boController.enabled.value;
        return ColorFilterWidget(
          brightness: brightness, // 亮度调整 (0 到 2, 1为正常)
          contrast: contrast, // 对比度调整 (0 到 2, 1为正常)
          saturation: saturation, // 饱和度调整 (0 到 2, 1为正常)
          hue: hue, // 色相调整 (-180 到 180)
          grayscale: grayscale, // 灰度 (0 到 1, 0为正常, 1为完全灰度)
          vibrance: vibrance, // 自然饱和度/鲜艳度 (vibrance) (-1 到 1, 0 为正常)
          exposure: exposure, // 曝光 (以档为单位，-2 到 2，0 为正常)
          temperature: temperature, // 色温 (-1 到 1，0 为正常；>0 更暖 <0 更冷)
          tint: tint, // 色调/偏色 (tint) (-1 到 1，0 为正常；>0 更偏绿 <0 更偏洋红)
          highlights: highlights, //高光 (-1 到 1，0 为正常)
          shadows: shadows, //阴影 (-1 到 1，0 为正常)
          clarity: clarity, //鲜明度/清晰度 (clarity) (-1 到 1，0 为正常)
          sharpness: sharpness, //锐度 (占位，当前未实现卷积锐化) (-1 到 1，0 为正常)
          enabled: enabled, //是否启用滤镜
          child: Blur(
            radius: BorderRadius.circular(200.rpx(context)),
            height: 80.rpx(context),
            opacity: 1,
            blur: 20.rpx(context),
            child: Stack(
              children: [
                _buildWaveform(context, controller),
                Positioned(
                  child: Row(
                    children: [
                      SizedBox(width: 15.rpx(context)),
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity != null) {
                              if (details.primaryVelocity! < 0) {
                                // 左滑，下一曲
                                controller.next();
                              } else if (details.primaryVelocity! > 0) {
                                // 右滑，上一曲
                                controller.previous();
                              }
                            }
                          },
                          // onTap: () => Get.to(() => Player()),
                          onTap: () {
                            // Navigator.of(
                            //   context,
                            // ).push(SlideUpRoute(child: const Player()));
                            Navigator.of(context).push(
                              CubePageRoute(
                                enterPage: Player(),
                                exitPage: Base(child: Container()),
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              _buildCoverImage(context, controller),
                              SizedBox(width: 10.rpx(context)),
                              _buildSongInfo(context, controller),
                            ],
                          ),
                        ),
                      ),
                      _buildPlayButton(context, controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWaveform(BuildContext context, PlayerUIController controller) {
    return Positioned(
      top: 0,
      left: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(80.rpx(context)),
        child: Obx(() {
          return controller.waveformData.isNotEmpty
              ? CustomWaveform(
                  waveformData: controller.waveformData,
                  width: MediaQuery.of(context).size.width - 80.rpx(context),
                  height: 100.rpx(context),
                  progress: controller.progressPercentage,
                )
              : Container(
                  width: MediaQuery.of(context).size.width - 40.rpx(context),
                  height: 100.rpx(context),
                  color: Colors.transparent,
                );
        }),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, PlayerUIController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(80.rpx(context)),
      child: GestureDetector(
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
            size: 70.rpx(context),
          );
        }),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, PlayerUIController controller) {
    return Expanded(
      child: Container(
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
              // 歌曲信息
              GradientText(
                showLyrics && currentLyric.isNotEmpty
                    ? currentLyric
                    : '$title - $artist',
                style: TextStyle(
                  fontSize: 30.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(100, 254, 255, 254),
                    Color(0x957CFFE0),
                    Color(0xFFA2FF7C),
                  ], // 绿色到蓝色
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, PlayerUIController controller) {
    return Obx(() {
      return IconButton(
        onPressed: () => controller.togglePlay(),
        icon: Icon(
          controller.isPlaying.value
              ? CupertinoIcons.pause_fill
              : CupertinoIcons.play_fill,
          color: Colors.white70,
          size: 50.rpx(context),
        ),
        iconSize: 80.rpx(context),
      );
    });
  }
}

class CustomWaveform extends StatelessWidget {
  final List<double> waveformData;
  final double width;
  final double height;
  final double progress; // 播放进度 (0.0 - 1.0)
  final Function(double)? onTap; // 点击回调

  const CustomWaveform({
    super.key,
    required this.waveformData,
    required this.width,
    required this.height,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onTap != null) {
          final relativeX = details.localPosition.dx / width;
          onTap!(relativeX.clamp(0.0, 1.0));
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: WaveformPainter(waveformData, progress),
          size: Size(width, height),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;

  WaveformPainter(this.waveformData, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final barCount = waveformData.length;
    final barWidth = size.width / (barCount * 1.2); // 1.2让柱子之间有间隔
    final gap = barWidth * 0.2;
    final centerY = size.height / 2;
    final progressIndex = (progress * barCount).floor();

    // 渐变色
    final gradient = LinearGradient(
      colors: [Colors.pinkAccent, Colors.purpleAccent, Colors.cyanAccent],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    final gradientPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    for (int i = 0; i < barCount; i++) {
      final amplitude = waveformData[i] * (size.height / 2 * 0.95);
      final x = i * (barWidth + gap) + barWidth / 2;
      final isPlayed = i <= progressIndex;

      final paint = Paint()
        ..shader = gradientPaint.shader
        // ignore: deprecated_member_use
        ..color = isPlayed
            ? Colors.white
            : Colors.white.withAlpha((0.3 * 255).round());

      // 画竖条（带圆角）
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: barWidth,
          height: amplitude * 2,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RotatingCoverImage extends StatefulWidget {
  final Map<String, dynamic>? currentSong;
  final bool isPlaying;
  final double size;

  const RotatingCoverImage({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.size,
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
    // 首次构建时根据当前播放状态启动/停止动画
    if (widget.isPlaying) {
      _animationController.repeat();
    } else {
      _animationController.stop();
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
    return RotationTransition(
      turns: _animationController,
      child: ClipOval(
        child: Hero(
          tag: 'tag-$fileId',
          flightShuttleBuilder:
              (context, animation, direction, fromContext, toContext) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(800.rpx(context)),
                  child: toContext.widget,
                );
              },
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
  bool get barrierDismissible => false; // 避免与底部弹窗的快速下滑手势冲突导致上层页面被误关闭

  @override
  // ignore: deprecated_member_use
  Color? get barrierColor => Colors.black.withAlpha((0.001 * 255).round()); // 透明屏障拦截手势，避免触发下层路由

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;
}
