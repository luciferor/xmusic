import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:glossy/glossy.dart';
import 'package:like_button/like_button.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/cover.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/player/albumart.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/pages/lrc.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'dart:io';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:xmusic/services/favorite_service.dart';

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  State<Player> createState() => _Player();
}

class _Player extends State<Player> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerUIController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [_buildBackground(context, controller)]),
    );
  }

  Widget _buildBackground(BuildContext context, PlayerUIController controller) {
    return CoverBase(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),
            child: Row(
              children: [
                SizedBox(
                  width: 80.rpx(context),
                  height: 80.rpx(context),
                  child: IconButton(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.all(0),
                    iconSize: 50.rpx(context),
                    color: const Color(0x70FFFFFF),
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 50.rpx(context),
                    ),
                  ),
                ),
                Expanded(child: Container(color: Colors.transparent)),
                Container(
                  width: 80.rpx(context),
                  height: 80.rpx(context),
                  alignment: Alignment.centerRight,
                  child: Obx(() {
                    final playlist = controller.playlist;
                    final idx = controller.currentIndex.value;
                    final currentSong =
                        (playlist.isNotEmpty &&
                            idx >= 0 &&
                            idx < playlist.length)
                        ? playlist[idx]
                        : null;

                    final fileId =
                        currentSong?['file_id'] ??
                        currentSong?['fileId'] ??
                        currentSong?['id'] ??
                        '';

                    // 读取收藏状态（依赖 FavoriteService().favoriteTracks 触发响应）
                    final favoriteService = FavoriteService();
                    final isFav =
                        fileId.isNotEmpty && favoriteService.isFavorite(fileId);

                    return LikeButton(
                      key: ValueKey('player_like_$fileId'),
                      onTap: (bool isLiked) async {
                        HapticFeedback.lightImpact();
                        if (currentSong == null || fileId.isEmpty) {
                          return isLiked;
                        }
                        await favoriteService.toggleFavorite(
                          currentSong.cast<String, dynamic>(),
                        );
                        // 返回最新状态以更新 LikeButton 内部 UI
                        return favoriteService.isFavorite(fileId);
                      },
                      padding: EdgeInsets.all(0),
                      likeCountPadding: EdgeInsets.all(0),
                      size: 60.rpx(context),
                      isLiked: isFav,
                      circleColor: CircleColor(
                        start: Color(0xFFA200FF),
                        end: Color(0xFF4E00CC),
                      ),
                      bubblesColor: BubblesColor(
                        dotPrimaryColor: Color(0xFF6D008F),
                        dotSecondaryColor: Color(0xFF44009C),
                      ),
                      likeBuilder: (bool liked) {
                        final effectiveLiked =
                            currentSong != null && (liked || isFav);
                        return Icon(
                          effectiveLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: effectiveLiked
                              ? Colors.deepPurpleAccent
                              : Colors.grey,
                          size: 50.rpx(context),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      60.rpx(context),
                      100.rpx(context),
                      60.rpx(context),
                      0,
                    ),
                    child: Obx(() {
                      final playlist = controller.playlist;
                      final idx = controller.currentIndex.value;
                      final currentSong =
                          playlist.isNotEmpty &&
                              idx >= 0 &&
                              idx < playlist.length
                          ? playlist[idx]
                          : null;
                      final title = currentSong?['title'] ?? '未知歌曲';
                      final artist = currentSong?['artist'] ?? '未知艺术家';
                      return Column(
                        children: [
                          // 歌曲标题
                          Container(
                            margin: EdgeInsets.only(bottom: 10.rpx(context)),
                            child: GradientText(
                              title,
                              style: TextStyle(
                                fontSize: 49.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0x92FFFFFF),
                                  Color(0x13FFFFFF),
                                ],
                              ), // 绿色到蓝色
                            ),
                          ),
                          SizedBox(height: 20.rpx(context)),
                          // 歌手or歌词
                          GestureDetector(
                            onTap: () {
                              if (controller.playlist.isNotEmpty) {
                                // 左滑，歌词
                                Get.to(() => LrcPage());
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 20.rpx(context)),
                              child: GradientText(
                                controller.lyrics.isNotEmpty &&
                                        controller
                                            .currentLyric
                                            .value
                                            .isNotEmpty &&
                                        Get.find<BlurOpacityController>()
                                            .isEnabled
                                            .value
                                    ? controller.currentLyric.value
                                    : artist,
                                style: TextStyle(fontSize: 30.rpx(context)),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white10,
                                    Colors.white38,
                                    Colors.white,
                                  ], // 绿色到蓝色
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.transparent,
                      child: AnimatedAlbumArt(),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: EdgeInsets.fromLTRB(
                          20.rpx(context),
                          0,
                          10.rpx(context),
                          0,
                        ),
                        alignment: Alignment.center,
                        child: Obx(
                          () => GradientText(
                            controller.currentTimeString,
                            style: TextStyle(fontSize: 30.rpx(context)),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(10, 248, 255, 245),
                                Color.fromARGB(100, 248, 255, 245),
                                Color.fromARGB(255, 238, 106, 255),
                              ], // 绿色到蓝色
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 80.rpx(context),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.all(
                              Radius.circular(30.rpx(context)),
                            ),
                          ),
                          child: Obx(() {
                            return controller.waveformData.isNotEmpty
                                ? CustomWaveform(
                                    waveformData: controller.waveformData,
                                    width: double.infinity,
                                    height: 80.rpx(context),
                                    progress: controller.progressPercentage,
                                    onTap: (value) {
                                      // 使用与显示一致的时间源，确保进度条点击准确性
                                      final displayDuration =
                                          controller.duration.value;
                                      if (displayDuration > 0) {
                                        final newPosition =
                                            value * displayDuration;
                                        controller.seekTo(newPosition);
                                      }
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      '波形加载中...',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 24.rpx(context),
                                      ),
                                    ),
                                  );
                          }),
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.fromLTRB(
                          10.rpx(context),
                          0,
                          80.rpx(context),
                          0,
                        ),
                        alignment: Alignment.center,
                        child: Obx(
                          () => GradientText(
                            controller.durationString,
                            style: TextStyle(fontSize: 30.rpx(context)),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 130, 247, 255),
                                Color.fromARGB(100, 248, 255, 245),
                                Color.fromARGB(10, 248, 255, 245),
                              ], // 绿色到蓝色
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 50.rpx(context)),
                  // 播放进度条
                  SizedBox(
                    height: 160.rpx(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Bounceable(
                          onTap: () {
                            // 添加点击反馈
                            HapticFeedback.lightImpact();
                          },
                          child: SizedBox(
                            width: 80.rpx(context),
                            height: 80.rpx(context),
                            child: IconButton(
                              onPressed: () {
                                if (controller.playlist.isNotEmpty) {
                                  showCupertinoModalBottomSheet(
                                    topRadius: Radius.circular(60.rpx(context)),
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    expand: false,
                                    builder: (context) => SongListBottomSheet(
                                      controller: controller,
                                    ),
                                  );
                                }
                              },
                              color: const Color(0x63DDF2FF),
                              iconSize: 45.rpx(context),
                              splashColor: Colors.red,
                              icon: Icon(CupertinoIcons.music_albums), //shuffle
                            ),
                          ),
                        ),
                        Bounceable(
                          onTap: () {
                            // 添加点击反馈
                            HapticFeedback.lightImpact();
                          },
                          child: SizedBox(
                            width: 100.rpx(context),
                            height: 100.rpx(context),
                            child: IconButton(
                              onPressed: () => controller.previous(),
                              color: const Color(0x63DDF2FF),
                              iconSize: 60.rpx(context),
                              splashColor: Colors.red,
                              icon: Icon(CupertinoIcons.backward_end),
                            ),
                          ),
                        ),
                        Bounceable(
                          onTap: () {},
                          child: SizedBox(
                            width: 160.rpx(context),
                            height: 160.rpx(context),
                            child: Obx(
                              () => GestureDetector(
                                onTap: () async {
                                  // 添加点击反馈
                                  HapticFeedback.lightImpact();
                                  // 异步调用togglePlay
                                  await controller.togglePlay();
                                },
                                onTapDown: (_) {
                                  // 添加按下反馈
                                  HapticFeedback.selectionClick();
                                },
                                behavior:
                                    HitTestBehavior.opaque, // 确保整个区域都能接收点击
                                child: Container(
                                  padding: EdgeInsets.all(20.rpx(context)),
                                  width: 160.rpx(context),
                                  height: 160.rpx(context),
                                  child: (Platform.isIOS)
                                      ? LiquidGlass(
                                          clipBehavior:
                                              Clip.antiAliasWithSaveLayer,
                                          shape: LiquidRoundedSuperellipse(
                                            borderRadius: Radius.circular(
                                              50.rpx(context),
                                            ),
                                          ),
                                          child: Container(
                                            alignment: Alignment.center,
                                            width: 120.rpx(context),
                                            height: 120.rpx(context),
                                            child: Icon(
                                              size: 60.rpx(context),
                                              color: const Color(0xB8DDF2FF),
                                              controller.isPlaying.value
                                                  ? CupertinoIcons.pause_fill
                                                  : CupertinoIcons.play_fill,
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
                                            color: const Color(0x4DDDF2FF),
                                            width: 5.rpx(context),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0x07FF0000),
                                              blurRadius: 30.rpx(context),
                                            ),
                                          ],
                                          borderRadius: BorderRadius.circular(
                                            50.rpx(context),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              size: 60.rpx(context),
                                              color: const Color(0xB8DDF2FF),
                                              controller.isPlaying.value
                                                  ? CupertinoIcons.pause_fill
                                                  : CupertinoIcons.play_fill,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Bounceable(
                          onTap: () {
                            // 添加点击反馈
                            HapticFeedback.lightImpact();
                          },
                          child: SizedBox(
                            width: 100.rpx(context),
                            height: 100.rpx(context),
                            child: IconButton(
                              onPressed: () => controller.next(),
                              color: const Color(0x63DDF2FF),
                              iconSize: 60.rpx(context),
                              splashColor: Colors.red,
                              icon: Icon(CupertinoIcons.forward_end),
                            ),
                          ),
                        ),
                        Bounceable(
                          onTap: () {
                            // 添加点击反馈
                            HapticFeedback.lightImpact();
                          },
                          child: SizedBox(
                            width: 80.rpx(context),
                            height: 80.rpx(context),
                            child: Obx(
                              () => IconButton(
                                onPressed: () => controller.togglePlayMode(),
                                color: const Color(0x63DDF2FF),
                                iconSize: 45.rpx(context),
                                splashColor: Colors.red,
                                icon: Icon(controller.getPlayModeIcon()),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 50.rpx(context)),
                  Copyright(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) {
            if (onTap != null) {
              // 使用实际约束的宽度来计算相对位置
              final relativeX = details.localPosition.dx / actualWidth;
              final clampedValue = relativeX.clamp(0.0, 1.0);
              onTap!(clampedValue);
            }
          },
          child: SizedBox(
            width: actualWidth,
            height: height,
            child: CustomPaint(
              painter: WaveformPainter(waveformData, progress),
              size: Size(actualWidth, height),
            ),
          ),
        );
      },
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

class SongListBottomSheet extends StatelessWidget {
  final PlayerUIController controller;
  const SongListBottomSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final minHeightPx = 100.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final minChildSize = minHeightPx / screenHeight;

    // 根据内容动态计算最大高度：内容少则不超过内容高度，多则接近全屏
    final headerHeightPx = 80.rpx(context); // 顶部拖拽条区域高度
    final rowHeightPx =
        80.rpx(context) + 2 * 10.rpx(context) + 2 * 5.rpx(context);
    final contentHeightPx =
        headerHeightPx + rowHeightPx * controller.playlist.length;
    final desiredMaxChildSize = contentHeightPx / screenHeight;
    final computedMaxChildSize = desiredMaxChildSize.clamp(
      minChildSize,
      0.95,
    ); // 不小于最小高度，不超过0.95
    final initialSize = 0.5;
    final computedInitialChildSize = initialSize.clamp(
      minChildSize,
      computedMaxChildSize,
    ); // 初始高度不超过最大、不小于最小
    final snaps = <double>{
      computedInitialChildSize.toDouble(),
      computedMaxChildSize.toDouble(),
    }.toList()..sort();
    return DraggableScrollableSheet(
      initialChildSize: computedInitialChildSize.toDouble(),
      minChildSize: minChildSize, // 动态最小高度
      maxChildSize: (computedMaxChildSize as num).toDouble(),
      snap: true,
      snapSizes: snaps.length > 1 ? snaps : [snaps.first],
      expand: false,
      builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return GlossyContainer(
              width: MediaQuery.of(context).size.width,
              height: constraints.maxHeight,
              strengthX: 10,
              strengthY: 10,
              gradient: GlossyLinearGradient(
                colors: [
                  Color(0x78DCFAE6),
                  Color(0x67E4EFFD),
                  Color(0x5FF5E2FD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                opacity: 0.2,
              ),
              border: BoxBorder.all(color: Colors.transparent, width: 0),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(95, 1, 4, 34),
                  blurRadius: 30.rpx(context),
                ),
              ],
              borderRadius: BorderRadius.circular(0.rpx(context)),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // 顶部拖拽条（仅装饰，无手势）
                    Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 80.rpx(context),
                      child: Container(
                        width: 80.rpx(context),
                        height: 10.rpx(context),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10.rpx(context)),
                        ),
                      ),
                    ),
                    // 内容区
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        physics:
                            const AlwaysScrollableScrollPhysics(), // 关键，保证可自由拖动
                        itemCount: controller.playlist.length,
                        itemBuilder: (context, index) {
                          final track = controller.playlist[index];
                          final isCurrent =
                              controller.currentIndex.value == index;
                          final title = track['title'] ?? track['name'] ?? '未知';
                          final artist = track['artist'] ?? '';
                          return InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                              await controller.onMusicItemTap(index);
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5.rpx(context),
                                horizontal: 40.rpx(context),
                              ),
                              padding: EdgeInsets.all(10.rpx(context)),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Color.fromARGB(68, 230, 247, 255)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  40.rpx(context),
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: Color.fromARGB(51, 71, 71, 71),
                                          blurRadius: 20.rpx(context),
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: NeonFilter(
                                      colors: [
                                        Colors.pink,
                                        Colors.cyan,
                                        Colors.blue,
                                      ],
                                      blendMode: BlendMode.color,
                                      child: FutureBuilder<String>(
                                        future: controller.getBestCoverPath(
                                          track,
                                        ),
                                        builder: (context, snapshot) {
                                          final coverPath = snapshot.data;
                                          Widget imageWidget;
                                          if (coverPath != null &&
                                              coverPath.isNotEmpty) {
                                            imageWidget = Image.file(
                                              File(coverPath),
                                              width: 80.rpx(context),
                                              height: 80.rpx(context),
                                              fit: BoxFit.cover,
                                            );
                                          } else {
                                            imageWidget = Image.asset(
                                              'assets/images/Hi-Res.png',
                                              width: 80.rpx(context),
                                              height: 80.rpx(context),
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return ClipOval(child: imageWidget);
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.rpx(context)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        GradientText(
                                          title,
                                          style: TextStyle(
                                            fontSize: 30.rpx(context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          gradient: LinearGradient(
                                            colors: isCurrent
                                                ? [
                                                    Color(0xFFFFFFFF),
                                                    Color(0xB4FFFFFF),
                                                    Color(0x8FFFFFFF),
                                                  ]
                                                : [
                                                    Color(0x50EBEEFF),
                                                    Color(0x95EBEEFF),
                                                    Color(0xFFEBEEFF),
                                                  ],
                                          ),
                                        ),
                                        GradientText(
                                          artist.isNotEmpty ? artist : '未知艺术家',
                                          style: TextStyle(
                                            fontSize: 24.rpx(context),
                                          ),
                                          gradient: LinearGradient(
                                            colors: isCurrent
                                                ? [
                                                    Color(0x1DEBEEFF),
                                                    Color(0x79EBEEFF),
                                                    Color(0xFFEBEEFF),
                                                  ]
                                                : [
                                                    Color(0xFFEBEEFF),
                                                    Color(0x79EBEEFF),
                                                    Color(0x1DEBEEFF),
                                                  ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    SizedBox(
                                      width: 60.rpx(context),
                                      height: 60.rpx(context),
                                      child: PlayerIcon(
                                        isPlaying: controller.isPlaying.value,
                                        fileId:
                                            controller
                                                .playlist[index]['file_id'] ??
                                            controller
                                                .playlist[index]['fileId'] ??
                                            controller.playlist[index]['id'] ??
                                            '',
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
          },
        );
      },
    );
  }
}
