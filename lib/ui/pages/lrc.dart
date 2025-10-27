import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:glossy/glossy.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/ui/components/color_filter_widget.dart';
import 'package:xmusic/ui/components/customslider.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/lrc.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:simple_animations/simple_animations.dart';
// 尝试修正 CoverController 路径，如果没有则注释掉并提示用 PlayerUIController
// import 'package:xmusic/ui/components/cover_controller.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'dart:math';

class LrcPage extends StatefulWidget {
  const LrcPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LrcPageState createState() => _LrcPageState();
}

class SmokeParticle {
  final double startX;
  final double startY;
  final double radius;
  final double speed;
  final double startTime;
  final double alpha;
  final double blur;

  SmokeParticle({
    required this.startX,
    required this.startY,
    required this.radius,
    required this.speed,
    required this.startTime,
    required this.alpha,
    required this.blur,
  });
}

class _LrcPageState extends State<LrcPage> {
  final PlayerUIController _playerController = Get.find<PlayerUIController>();
  final List<SmokeParticle> _smokeParticles = List.generate(32, (i) {
    final rand = Random(i);
    return SmokeParticle(
      startX: 0.1 + rand.nextDouble() * 0.8,
      startY: 0.7 + rand.nextDouble() * 0.3,
      radius: 80 + rand.nextDouble() * 60,
      speed: 0.2 + rand.nextDouble() * 0.5,
      startTime: rand.nextDouble() - 0.5, // 让t有负值，粒子渐入
      alpha: 0.08 + rand.nextDouble() * 0.12,
      blur: 20 + rand.nextDouble() * 20,
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final track =
            _playerController.playlist.isNotEmpty &&
                _playerController.currentIndex.value <
                    _playerController.playlist.length
            ? _playerController.playlist[_playerController.currentIndex.value]
            : null;
        final fileId = track != null
            ? (track['file_id'] ?? track['id'] ?? '')
            : '';
        final brightness = Get.find<BlurOpacityController>().brightness.value;
        final contrast = Get.find<BlurOpacityController>().contrast.value;
        final saturation = Get.find<BlurOpacityController>().saturation.value;
        final hue = Get.find<BlurOpacityController>().hue.value;
        final grayscale = Get.find<BlurOpacityController>().grayscale.value;
        final vibrance = Get.find<BlurOpacityController>().vibrance.value;
        final exposure = Get.find<BlurOpacityController>().exposure.value;
        final temperature = Get.find<BlurOpacityController>().temperature.value;
        final tint = Get.find<BlurOpacityController>().tint.value;
        final highlights = Get.find<BlurOpacityController>().highlights.value;
        final shadows = Get.find<BlurOpacityController>().shadows.value;
        final clarity = Get.find<BlurOpacityController>().clarity.value;
        final sharpness = Get.find<BlurOpacityController>().sharpness.value;
        final enabled = Get.find<BlurOpacityController>().enabled.value;
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
          child: Stack(
            children: [
              // 歌曲封面背景（本地缓存封面，和CoverBase一致）
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  child: FutureBuilder<Uint8List?>(
                    key: ValueKey(fileId),
                    future: ImageCacheService().getFromLocalCache(fileId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.data != null) {
                        return NeonFilter(
                          colors: [Colors.pink, Colors.cyan, Colors.blue],
                          blendMode: BlendMode.color,
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        );
                      }
                      return NeonFilter(
                        colors: [Colors.pink, Colors.cyan, Colors.blue],
                        blendMode: BlendMode.color,
                        child: Image.asset(
                          'assets/images/bgs/1159626.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 烟雾动画
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomAnimationBuilder<double>(
                    control: Control.loop,
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 40),
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: SmokePainter(value, _smokeParticles),
                        child: Container(),
                      );
                    },
                  ),
                ),
              ),

              // // 背景色或渐变
              Positioned.fill(
                child: GlossyContainer(
                  width: double.infinity,
                  height: double.infinity,
                  strengthX: 10,
                  strengthY: 10,
                  gradient: GlossyLinearGradient(
                    colors: [
                      const Color(0xD2000000),
                      const Color(0xDA000000),
                      const Color(0xD2000000),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    opacity: 0.5,
                  ),
                  border: BoxBorder.all(
                    color: const Color(0x00000000),
                    width: 0.rpx(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x46000000),
                      blurRadius: 30.rpx(context),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(0.rpx(context)),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // 顶部控制栏
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 40.rpx(context),
                          ),
                          width: MediaQuery.of(context).size.width,
                          height: 80.rpx(context),
                          child: Row(
                            children: [
                              Re(),
                              Expanded(child: Container()),
                            ],
                          ),
                        ),
                        Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.fromLTRB(
                            40.rpx(context),
                            100.rpx(context),
                            40.rpx(context),
                            0.rpx(context),
                          ),
                          child: Obx(() {
                            final track = _playerController
                                .playlist[_playerController.currentIndex.value];
                            final title =
                                track['title'] ?? track['name'] ?? '未知歌曲';
                            final artist = track['artist'] ?? '';
                            return Column(
                              children: [
                                GradientText(
                                  title,
                                  style: TextStyle(
                                    fontSize: 49.rpx(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color.fromARGB(255, 224, 241, 242),
                                      Color.fromARGB(205, 158, 169, 170),
                                      Color(0x2BFAFFF8),
                                    ],
                                  ), // 绿色到蓝色
                                ),
                                SizedBox(height: 20.rpx(context)),
                                GradientText(
                                  artist,
                                  style: TextStyle(fontSize: 32.rpx(context)),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color.fromARGB(43, 255, 255, 255),
                                      Color.fromARGB(148, 255, 255, 255),
                                      Color.fromARGB(255, 255, 255, 255),
                                    ],
                                  ), // 绿色到蓝色
                                ),
                              ],
                            );
                          }),
                        ),

                        // 歌词显示区域
                        Expanded(child: AdvancedLrc()),
                        // 进度条
                        Container(
                          height: 100.rpx(context),
                          alignment: Alignment.bottomCenter,
                          padding: EdgeInsets.fromLTRB(
                            20.rpx(context),
                            20.rpx(context),
                            20.rpx(context),
                            0,
                          ),
                          child: Obx(() {
                            final progress = _playerController.progress.value;
                            final duration = _playerController.duration.value;
                            String formatTime(double seconds) {
                              final min = seconds ~/ 60;
                              final sec = (seconds % 60).toInt();
                              return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
                            }

                            return Row(
                              children: [
                                Text(
                                  formatTime(progress),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 22.rpx(context),
                                  ),
                                ),
                                Expanded(
                                  child: GradientSlider(
                                    enabled: false,
                                    value: duration > 0
                                        ? (progress / duration * 100).clamp(
                                            0,
                                            100,
                                          )
                                        : 0,
                                    onChanged: (v) {},
                                    onChangeEnd: (v) async {
                                      _playerController.seekTo(v);
                                    },
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.fromARGB(0, 236, 247, 255),
                                        Color.fromARGB(200, 218, 234, 250),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  formatTime(duration),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 22.rpx(context),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        // 底部播放控制
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 100.rpx(context),
                                height: 100.rpx(context),
                                child: IconButton(
                                  onPressed: () => _playerController.previous(),
                                  color: Color(0x63DDF2FF),
                                  iconSize: 60.rpx(context),
                                  splashColor: Colors.red,
                                  icon: Icon(CupertinoIcons.backward_end),
                                ),
                              ),
                              Bounceable(
                                onTap: () {},
                                child: Container(
                                  width: 160.rpx(context),
                                  height: 160.rpx(context),
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 20.rpx(context),
                                  ),
                                  child: Obx(
                                    () => GestureDetector(
                                      onTap: () async {
                                        // 添加点击反馈
                                        HapticFeedback.lightImpact();
                                        // 异步调用togglePlay
                                        await _playerController.togglePlay();
                                      },
                                      onTapDown: (_) {
                                        // 添加按下反馈
                                        HapticFeedback.selectionClick();
                                      },
                                      behavior: HitTestBehavior
                                          .opaque, // 确保整个区域都能接收点击
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          20.rpx(context),
                                        ),
                                        width: 160.rpx(context),
                                        height: 160.rpx(context),
                                        child: (Platform.isIOS)
                                            ? LiquidGlass(
                                                clipBehavior:
                                                    Clip.antiAliasWithSaveLayer,
                                                shape:
                                                    LiquidRoundedSuperellipse(
                                                      borderRadius:
                                                          Radius.circular(
                                                            50.rpx(context),
                                                          ),
                                                    ),
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  width: 120.rpx(context),
                                                  height: 120.rpx(context),
                                                  child: Icon(
                                                    size: 60.rpx(context),
                                                    color: const Color(
                                                      0xB8DDF2FF,
                                                    ),
                                                    _playerController
                                                            .isPlaying
                                                            .value
                                                        ? CupertinoIcons
                                                              .pause_fill
                                                        : CupertinoIcons
                                                              .play_fill,
                                                  ),
                                                ),
                                              )
                                            : GlossyContainer(
                                                width: 120.rpx(context),
                                                height: 120.rpx(context),
                                                strengthX: 30,
                                                strengthY: 30,
                                                gradient: GlossyLinearGradient(
                                                  colors: [
                                                    Color(0x93FFFDF1),
                                                    Color(0x93EAFFF6),
                                                    Color(0x93F3F5FF),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  opacity: 0.1,
                                                ),
                                                border: BoxBorder.all(
                                                  color: const Color(
                                                    0x4EDDF2FF,
                                                  ),
                                                  width: 5.rpx(context),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0x07FF0000,
                                                    ),
                                                    blurRadius: 30.rpx(context),
                                                  ),
                                                ],
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      50.rpx(context),
                                                    ),
                                                child: Center(
                                                  child: Icon(
                                                    size: 60.rpx(context),
                                                    color: const Color(
                                                      0xB8DDF2FF,
                                                    ),
                                                    _playerController
                                                            .isPlaying
                                                            .value
                                                        ? CupertinoIcons
                                                              .pause_fill
                                                        : CupertinoIcons
                                                              .play_fill,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100.rpx(context),
                                height: 100.rpx(context),
                                child: IconButton(
                                  onPressed: () => _playerController.next(),
                                  color: const Color(0x63DDF2FF),
                                  iconSize: 60.rpx(context),
                                  splashColor: Colors.red,
                                  icon: Icon(CupertinoIcons.forward_end),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// 优化后的SmokePainter类定义
class SmokePainter extends CustomPainter {
  final double value;
  final List<SmokeParticle> particles;

  SmokePainter(this.value, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      double t = ((value * p.speed + p.startTime) % 1.0);
      if (t < 0) t += 1.0;
      // 横向漂移：加一个正弦扰动
      double drift = sin((t + p.startX) * 3.14 * 2) * 0.07; // 0.07为漂移幅度
      double dx = size.width * (p.startX + drift * t);
      double dy = size.height * (p.startY - t * 0.8);
      double alpha = p.alpha * (1 - t);
      if (t < 0.1) alpha *= t / 0.1;
      // 粒子扩散：半径和模糊随t增大
      double radius = p.radius * (0.8 + 0.7 * t);
      double blur = p.blur * (1 + t);
      final paint = Paint()
        ..color = Colors.white.withAlpha((alpha * 255).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      // 用3个小圆叠加模拟不规则烟雾
      for (int j = 0; j < 3; j++) {
        double angle = (j / 3) * 2 * 3.14159 + t * 2;
        double offsetR = radius * 0.3 * (0.7 + t * 0.6);
        double cx = dx + cos(angle) * offsetR;
        double cy = dy + sin(angle) * offsetR * 0.7;
        canvas.drawCircle(
          Offset(cx, cy),
          radius * (0.7 + 0.2 * (j == 0 ? 1 : 0)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SmokePainter oldDelegate) => true;
}
