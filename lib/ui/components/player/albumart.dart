import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/pages/lrc.dart';
import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// audio_visualizer 已移除

class AnimatedAlbumArt extends StatefulWidget {
  const AnimatedAlbumArt({super.key});

  @override
  State<AnimatedAlbumArt> createState() => _AnimatedAlbumArtState();
}

class _AnimatedAlbumArtState extends State<AnimatedAlbumArt>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late PlayerUIController playerController;
  bool _isDisposed = false; // 添加销毁标志
  // VisualizerPlayer? _visualizerPlayer;

  @override
  void initState() {
    super.initState();
    playerController = Get.find<PlayerUIController>();
    // 旋转动画控制器
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    // 已移除 audio_visualizer 初始化

    // 监听播放状态
    ever(playerController.isPlaying, (isPlaying) {
      // 检查组件是否已被销毁
      if (!_isDisposed && mounted) {
        if (isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });

    // 监听歌曲变化，更新封面颜色与可视化数据源
    ever(playerController.currentIndex, (index) {
      if (!_isDisposed && mounted) {
        _updateCoverColor();
        // 已移除 audio_visualizer 数据源设置
      }
    });

    // 初始化时检查当前播放状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        if (playerController.isPlaying.value) {
          _rotationController.repeat();
        }
        _updateCoverColor(); // 初始化时也更新颜色
        // 已移除 audio_visualizer 数据源设置
      }
    });
  }

  // 已移除 _initVisualizer

  // 已移除 _setVisualizerDataSourceForCurrent

  @override
  void dispose() {
    _isDisposed = true; // 设置销毁标志
    _rotationController.dispose();
    // 无可视化播放器可释放
    super.dispose();
  }

  // 更新封面颜色
  void _updateCoverColor() {
    final playlist = playerController.playlist;
    final idx = playerController.currentIndex.value;
    if (playlist.isEmpty || idx < 0 || idx >= playlist.length) return;

    final currentSong = playlist[idx];
    final coverUrl = currentSong['cover'] ?? currentSong['cover_url'] ?? '';

    if (coverUrl.isNotEmpty) {
      // 从图片提取颜色
      _extractColorFromImage(coverUrl);
    } else {
      playerController.coverColor.value = Colors.white;
    }
  }

  // 从本地缓存图片提取颜色
  Future<void> _extractColorFromImage(String url) async {
    try {
      // 从URL中提取fileId
      final uri = Uri.parse(url);
      final fileId = uri.pathSegments.last.split('.').first;

      // 获取缓存目录
      final dir = await getApplicationDocumentsDirectory();
      final imageCacheDir = Directory(p.join(dir.path, 'image_cache'));

      // 查找缓存文件
      File? cachedFile;
      for (final ext in ['jpg', 'png', 'jpeg', 'webp']) {
        final file = File(p.join(imageCacheDir.path, '$fileId.$ext'));
        if (await file.exists()) {
          cachedFile = file;
          break;
        }
      }

      if (cachedFile == null) {
        // 如果找不到缓存文件，使用URL生成颜色
        _generateColorFromUrl(url);
        return;
      }

      // 读取本地文件
      final bytes = await cachedFile.readAsBytes();

      // 使用image包解码图片
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw Exception('无法解码图片');

      // 提取主要颜色
      final dominantColor = _extractDominantColor(decodedImage);

      playerController.coverColor.value = dominantColor;
    } catch (e) {
      // 如果提取失败，使用URL生成颜色
      _generateColorFromUrl(url);
    }
  }

  // 提取主要颜色
  Color _extractDominantColor(img.Image image) {
    // 缩小图片以提高性能
    final resizedImage = img.copyResize(image, width: 50, height: 50);

    final Map<int, int> colorCount = {};

    // 统计颜色
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final color = Color.fromARGB(
          pixel.a.toInt(),
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );

        // 跳过透明和白色像素
        if (color.opacity < 0.1 ||
            (color.red > 250 && color.green > 250 && color.blue > 250)) {
          continue;
        }

        final colorValue = color.value;
        colorCount[colorValue] = (colorCount[colorValue] ?? 0) + 1;
      }
    }

    // 找到出现最多的颜色
    int maxCount = 0;
    Color dominantColor = Colors.grey;
    for (final entry in colorCount.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominantColor = Color(entry.key);
      }
    }

    return dominantColor;
  }

  // 根据URL生成颜色（备用方案）
  void _generateColorFromUrl(String url) {
    // 简单的颜色生成算法：基于URL的hash值
    int hash = 0;
    for (int i = 0; i < url.length; i++) {
      hash = ((hash << 5) - hash + url.codeUnitAt(i)) & 0xFFFFFFFF;
    }

    // 使用hash值生成颜色
    final hue = (hash % 360).toDouble();
    final saturation = 0.6 + (hash % 40) / 100.0; // 0.6-1.0
    final lightness = 0.4 + (hash % 30) / 100.0; // 0.4-0.7

    final hslColor = HSLColor.fromAHSL(1, hue, saturation, lightness);

    playerController.coverColor.value = hslColor.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final radius = 260.0.rpx(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 封面（旋转）
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * pi,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                    border: Border.all(
                      width: 15.rpx(context),
                      color: Colors.black26,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(20, 68, 65, 255),
                        blurRadius: 30.rpx(context),
                        spreadRadius: 0,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          padding: EdgeInsets.all(108.rpx(context)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              800.rpx(context),
                            ),
                          ),
                          child: Obx(() {
                            final playlist = playerController.playlist;
                            final idx = playerController.currentIndex.value;
                            final currentSong =
                                playlist.isNotEmpty &&
                                    idx >= 0 &&
                                    idx < playlist.length
                                ? playlist[idx]
                                : null;
                            final coverUrl =
                                currentSong?['cover'] ??
                                currentSong?['cover_url'] ??
                                '';
                            final fileId =
                                currentSong?['file_id'] ??
                                currentSong?['fileId'] ??
                                currentSong?['id'] ??
                                '';
                            return Material(
                              elevation: 8.0,
                              shape: const CircleBorder(),
                              color: Colors.transparent,
                              child: ClipOval(
                                child: coverUrl.isNotEmpty
                                    ? CachedImage(
                                        imageUrl: coverUrl,
                                        cacheKey: fileId,
                                        width: radius * 2,
                                        height: radius * 2,
                                        fit: BoxFit.cover,
                                        errorWidget: Container(
                                          width: radius * 2,
                                          height: radius * 2,
                                          color: Colors.grey[800],
                                          child: Center(
                                            child: Image.asset(
                                              'assets/images/Hi-Res.png',
                                            ),
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/images/Hi-Res.png',
                                        width: radius * 2,
                                        height: radius * 2,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.7,
                          child: Image.asset(
                            'assets/images/020c50ee383683fecb0.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 频谱可视化（环形）
          // Positioned.fill(
          //   child: IgnorePointer(
          //     child: AnimatedBuilder(
          //       animation: _rotationController,
          //       builder: (context, _) {
          //         final total = playerController.duration.value;
          //         final pos = playerController.progress.value;
          //         final p = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
          //         final size = 620.0.rpx(context);
          //         return Obx(() {
          //           final playing = playerController.isPlaying.value;
          //           return Center(
          //             child: SizedBox(
          //               width: size,
          //               height: size,
          //               child: CustomPaint(
          //                 painter: _CircularSpectrumPainter(
          //                   time: _rotationController.value,
          //                   progress: p,
          //                   isPlaying: playing,
          //                 ),
          //               ),
          //             ),
          //           );
          //         });
          //       },
          //     ),
          //   ),
          // ),
          // 已移除 audio_visualizer 频谱可视化层
          Positioned.fill(
            // 播放进度圆形进度条（自绘）
            child: Center(
              child: Obx(() {
                final total = playerController.duration.value; // 秒
                final pos = playerController.progress.value; // 秒
                final p = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                final size = 520.0.rpx(context);
                return SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: p,
                      backgroundColor: Colors.white10,
                      gradientColors: const [
                        ui.Color(0x137E7E7E), // pink
                        ui.Color(0x50DFDFDF), // orange
                      ],
                      strokeWidth: 12.0.rpx(context),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    color: Colors.transparent,
                    width: 200.rpx(context),
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < 0) {
                            HapticFeedback.lightImpact();
                            if (playerController.playlist.isNotEmpty) {
                              // 左滑，歌词
                              Get.to(() => LrcPage());
                            }
                          } else if (details.primaryVelocity! > 0) {
                            HapticFeedback.lightImpact();
                            // 右滑，返回上一页
                            Navigator.pop(context);
                          }
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! > 0) {
                            HapticFeedback.lightImpact();
                            // 下滑，返回上一页
                            Navigator.pop(context);
                          }
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (playerController.playlist.isNotEmpty) {
                          // 左滑，歌词
                          Get.to(() => LrcPage());
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color backgroundColor;
  final List<Color> gradientColors;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.gradientColors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final safeColors = (gradientColors.isNotEmpty)
        ? gradientColors
        : const [
            ui.Color(0x8969D0FF), // pink
            ui.Color(0xA2C8FF89), // orange
          ];

    // 弧线渐变：在当前弧度范围内进行细分插值，过渡更柔和
    List<Color> arcColors;
    if (safeColors.length == 2) {
      final from = HSLColor.fromColor(safeColors.first);
      final to = HSLColor.fromColor(safeColors.last);
      const steps = 6;
      arcColors = List<Color>.generate(steps, (i) {
        final t = i / (steps - 1);
        final h = from.hue + (to.hue - from.hue) * t;
        final s = from.saturation + (to.saturation - from.saturation) * t;
        final l = from.lightness + (to.lightness - from.lightness) * t;
        return HSLColor.fromAHSL(1, h, s, l).toColor();
      });
    } else {
      arcColors = safeColors;
    }

    // 背景环
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧（按段插值绘制，避免任何角度下的突变/错位）
    final sweep = 2 * pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -pi / 2; // 从顶部开始

    // 细分段数：每度≈1段，限制在[24, 240]
    int segments = max(24, min(240, (sweep * 180 / pi).round()));
    if (segments < 2) segments = 2;

    Color _lerpHsl(Color a, Color b, double t) {
      final ha = HSLColor.fromColor(a);
      final hb = HSLColor.fromColor(b);
      final h = ha.hue + (hb.hue - ha.hue) * t;
      final s = ha.saturation + (hb.saturation - ha.saturation) * t;
      final l = ha.lightness + (hb.lightness - ha.lightness) * t;
      return HSLColor.fromAHSL(1, h, s, l).toColor();
    }

    // 预生成插值颜色表
    List<Color> table;
    if (arcColors.length == 2) {
      table = List<Color>.generate(segments + 1, (i) {
        final t = i / segments;
        return _lerpHsl(arcColors.first, arcColors.last, t);
      });
    } else {
      // 多段颜色：分段线性插值
      table = List<Color>.generate(segments + 1, (i) {
        final t = i / segments;
        final p = t * (arcColors.length - 1);
        final idx = p.floor().clamp(0, arcColors.length - 2);
        final localT = p - idx;
        return _lerpHsl(arcColors[idx], arcColors[idx + 1], localT);
      });
    }

    for (int i = 0; i < segments; i++) {
      final a0 = start + sweep * (i / segments);
      final a1 = start + sweep * ((i + 1) / segments);
      final segPaint = Paint()
        ..color = table[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, a0, a1 - a0, false, segPaint);
    }

    // 端点圆点（发光）
    if (progress > 0) {
      final endAngle = start + sweep;
      final dotRadius = strokeWidth * 0.9;
      final dotCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      final tailColor = (arcColors.isNotEmpty
          ? arcColors.last
          : safeColors.last);

      final glowPaint = Paint()
        ..color = tailColor.withAlpha((0.55 * 255).round())
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(dotCenter, dotRadius * 1.4, glowPaint);

      final dotPaint = Paint()
        ..shader = RadialGradient(
          colors: [tailColor, tailColor.withAlpha((0.6 * 255).round())],
        ).createShader(Rect.fromCircle(center: dotCenter, radius: dotRadius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ignore: unused_element
class _CircularSpectrumPainter extends CustomPainter {
  final double time; // 0..1 from animation controller
  final double progress; // 0..1 播放进度，用于颜色或强度变化
  final bool isPlaying;

  _CircularSpectrumPainter({
    required this.time,
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) / 2 - 6;
    final innerRadius = outerRadius - 26; // 与进度环错开

    // 背景轻微粒子
    final rnd = Random(time.hashCode);
    final dots = 290;
    for (int i = 0; i < dots; i++) {
      final a = i / dots * 2 * pi + time * 2 * pi;
      final r = innerRadius - 10 - rnd.nextDouble() * 8;
      final c = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      final paint = Paint()
        ..color = const ui.Color.fromARGB(50, 158, 21, 250)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(c, 1.2, paint);
    }

    // 环形频谱柱
    // 外圈辐射柱
    const barCount = 140;
    for (int i = 0; i < barCount; i++) {
      final angle = i / barCount * 2 * pi;
      // 用噪声/正弦模拟幅值，可替换为真实 FFT 数据
      final base = (sin((i * 0.33) + time * 7.5) + 1) * 0.5; // 细微起伏
      final jitter = (sin((i * 0.17) - time * 5.3) + 1) * 0.5; // 微抖动

      // 旋转热点（围绕转动的能量包）
      final speed = 9.1; // 转速（圈/秒）
      final hotspotAngle = (time * 2 * pi * speed) % (2 * pi);
      double d = (angle - hotspotAngle).abs();
      if (d > pi) d = 2 * pi - d; // 最短角差
      const sigma = 0.7; // 热点宽度（弧度）
      final hotspot = mathExp(-(d * d) / (2 * sigma * sigma));

      // 可加第二个反向热点，增加层次
      final hotspot2Angle = (hotspotAngle + pi * 0.9) % (2 * pi);
      double d2 = (angle - hotspot2Angle).abs();
      if (d2 > pi) d2 = 2 * pi - d2;
      final hotspot2 = mathExp(-(d2 * d2) / (2 * sigma * sigma)) * 0.6;

      final envelope = (hotspot + hotspot2).clamp(0.0, 1.0);
      final playScale = isPlaying ? 1.0 : 0.0;
      final magnitude =
          (0.15 + base * 0.5 + jitter * 0.15) *
          (0.55 + progress * 0.7) *
          (0.6 + envelope * 0.9) *
          playScale;
      final barLen = 8 + magnitude * 44;

      final start = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final end = Offset(
        center.dx + (innerRadius + barLen) * cos(angle),
        center.dy + (innerRadius + barLen) * sin(angle),
      );

      final hue = (i / barCount * 360).toDouble();
      final color = HSLColor.fromAHSL(1, hue, 0.95, 0.60).toColor();

      // 柱体（从内到外的渐变）
      final paint = Paint()
        ..shader = ui.Gradient.linear(start, end, [
          color.withAlpha((0.12 * 255).round()),
          color,
        ])
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      // 外发光（始终朝外扩散）
      final glow = Paint()
        ..shader = ui.Gradient.linear(start, end, [
          color.withAlpha((0.0 * 255).round()),
          color.withAlpha((0.10 * 255).round()),
        ])
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(start, end, glow);
    }
  }

  // 高斯函数的快速实现
  double mathExp(double x) {
    return exp(x);
  }

  @override
  bool shouldRepaint(covariant _CircularSpectrumPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.progress != progress;
  }
}

class _WaveformBarPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final double gap;

  _WaveformBarPainter({
    required this.waveform,
    required this.color,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth =
        (size.width - gap * (waveform.length - 1)) / waveform.length;
    final startX = gap / 2;

    for (int i = 0; i < waveform.length; i++) {
      final barHeight = waveform[i] * size.height;
      final rect = Rect.fromLTWH(
        startX + i * (barWidth + gap),
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBarPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.color != color ||
        oldDelegate.gap != gap;
  }
}

class _WaveformCircularPainter extends CustomPainter {
  final List<double> waveform;
  final List<Color> colors;
  final double innerRadiusRatio; // 0..1 of min(size.w, size.h)/2
  final double maxBarLengthRatio; // 0..1 relative to radius
  final double barWidth;
  final double gapAngleDegrees; // angular gap between bars
  final double blurSigma;

  _WaveformCircularPainter({
    required this.waveform,
    required this.colors,
    required this.innerRadiusRatio,
    required this.maxBarLengthRatio,
    required this.barWidth,
    required this.gapAngleDegrees,
    required this.blurSigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) * innerRadiusRatio;
    final maxBarLen = (size.shortestSide / 2) * maxBarLengthRatio;

    final bars = waveform.length;
    final gapRad = gapAngleDegrees * (3.141592653589793 / 180.0);
    final full = 2 * 3.141592653589793;
    final sweep = full - bars * gapRad;
    final per = sweep / bars;

    for (int i = 0; i < bars; i++) {
      final theta = i * (per + gapRad);
      final amp = waveform[i].clamp(0.0, 1.0);
      final len = amp * maxBarLen;

      final start = Offset(
        center.dx + radius * cos(theta),
        center.dy + radius * sin(theta),
      );
      final end = Offset(
        center.dx + (radius + len) * cos(theta),
        center.dy + (radius + len) * sin(theta),
      );

      final t = i / (bars - 1).clamp(1, double.infinity);
      final color = _sampleGradient(colors, t);

      final stroke = Paint()
        ..shader = ui.Gradient.linear(start, end, [
          color.withAlpha((0.2 * 255).round()),
          color,
        ])
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      final glow = Paint()
        ..shader = ui.Gradient.linear(start, end, [
          color.withAlpha((0.0 * 255).round()),
          color.withAlpha((0.12 * 255).round()),
        ])
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawLine(start, end, stroke);
      canvas.drawLine(start, end, glow);
    }
  }

  Color _sampleGradient(List<Color> cols, double t) {
    if (cols.isEmpty) return const Color(0xFFFFFFFF);
    if (cols.length == 1) return cols.first;
    final scaled = t * (cols.length - 1);
    final i = scaled.floor().clamp(0, cols.length - 2);
    final f = scaled - i;
    final a = cols[i];
    final b = cols[i + 1];
    return Color.lerp(a, b, f) ?? b;
  }

  // 使用 dart:math 的 sin/cos
  double MathSin(double x) => sin(x);
  double MathCos(double x) => cos(x);

  @override
  bool shouldRepaint(covariant _WaveformCircularPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.colors != colors ||
        oldDelegate.innerRadiusRatio != innerRadiusRatio ||
        oldDelegate.maxBarLengthRatio != maxBarLengthRatio ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.gapAngleDegrees != gapAngleDegrees ||
        oldDelegate.blurSigma != blurSigma;
  }
}
