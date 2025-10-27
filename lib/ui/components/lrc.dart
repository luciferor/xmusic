import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:pretty_animated_text/pretty_animated_text.dart';

class Lrc extends StatefulWidget {
  const Lrc({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _LrcState createState() => _LrcState();
}

class _LrcState extends State<Lrc> with TickerProviderStateMixin {
  late AnimationController _scrollController;
  late AnimationController _fadeController;

  final ScrollController _scrollController2 = ScrollController();
  final PlayerUIController _playerController = Get.find<PlayerUIController>();

  int _currentLyricIndex = 0;
  bool _disposed = false;

  // 缓存 rpx 值
  double? _cachedItemHeight;
  double? _cachedPadding;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _scrollController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 监听歌词变化
    ever(_playerController.lyrics, (_) {
      if (!_disposed && mounted && _playerController.lyrics.isNotEmpty) {
        _fadeController.forward();
      }
    });

    // 监听播放进度变化来更新歌词
    ever(_playerController.progress, (progress) {
      if (!_disposed && mounted && _playerController.lyrics.isNotEmpty) {
        final index = _playerController.currentLyricIndex.value;
        if (index != _currentLyricIndex && index >= 0) {
          _currentLyricIndex = index;
          _scrollToCurrentLyric();
        }
      }
    });

    // 直接监听歌词索引变化，确保高亮更新
    ever(_playerController.currentLyricIndex, (index) {
      if (!_disposed && mounted && _playerController.lyrics.isNotEmpty) {
        if (index != _currentLyricIndex && index >= 0) {
          _currentLyricIndex = index;
          _scrollToCurrentLyric();
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    _fadeController.dispose();
    _scrollController2.dispose();
    super.dispose();
  }

  // 缓存 rpx 值
  void _cacheRpxValues() {
    if (mounted) {
      _cachedItemHeight = 60.rpx(context);
      _cachedPadding = 120.rpx(context);
    }
  }

  void _scrollToCurrentLyric() {
    if (_playerController.lyrics.isEmpty ||
        !mounted ||
        _cachedItemHeight == null ||
        _cachedPadding == null)
      return;

    // 使用缓存的 rpx 值进行计算
    final targetPosition =
        (_currentLyricIndex * _cachedItemHeight!) - _cachedPadding!;

    if (_scrollController2.hasClients) {
      final clampedPosition = targetPosition.clamp(
        0.0,
        _scrollController2.position.maxScrollExtent,
      );

      _scrollController2.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 缓存 rpx 值
    _cacheRpxValues();

    return Container(
      height: 300.rpx(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha((0.8 * 255).round()),
            Colors.black.withAlpha((0.4 * 255).round()),
            Colors.transparent,
          ],
        ),
      ),
      child: Obx(() {
        // 强制监听所有相关状态
        final lyrics = _playerController.lyrics;
        final currentIndex = _playerController.currentLyricIndex.value;
        final progress = _playerController.progress.value;

        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.rpx(context),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController2,
          padding: EdgeInsets.symmetric(vertical: 120.rpx(context)),
          physics: BouncingScrollPhysics(),
          itemCount: lyrics.length,
          itemBuilder: (context, index) {
            final lyric = lyrics[index];
            final isCurrent = index == currentIndex;

            // 强制刷新：使用 key 来确保组件重新构建
            return Container(
              key: ValueKey('lyric_${index}_${currentIndex}_$isCurrent'),
              height: 60.rpx(context),
              alignment: Alignment.center,
              child: _buildLyricText(lyric.text, isCurrent, index),
            );
          },
        );
      }),
    );
  }

  Widget _buildLyricText(String text, bool isCurrent, int index) {
    if (isCurrent) {
      // 当前播放的歌词 - 简单高亮效果
      return Container(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20.rpx(context),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      // 其他歌词 - 简单透明度调整
      final currentLyricIndex = _playerController.currentLyricIndex.value;
      final distance = (index - currentLyricIndex).abs();
      final opacity = (1.0 - distance * 0.2).clamp(0.5, 1.0);

      return Text(
        text,
        style: TextStyle(
          fontSize: 16.rpx(context),
          color: Colors.white.withAlpha((opacity * 255).round()),
          fontWeight: distance <= 1 ? FontWeight.w500 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}

// 高级歌词组件 - 带波形效果
class AdvancedLrc extends StatefulWidget {
  const AdvancedLrc({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AdvancedLrcState createState() => _AdvancedLrcState();
}

class _AdvancedLrcState extends State<AdvancedLrc>
    with TickerProviderStateMixin {
  final PlayerUIController _playerController = Get.find<PlayerUIController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(80.rpx(context)),
      height: double.infinity,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Obx(() {
        final lyrics = _playerController.lyrics;
        final currentLyric = _playerController.currentLyric.value;
        final isPlaying = _playerController.isPlaying.value;

        if (lyrics.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/empty.png',
                    width: 400.rpx(context),
                    opacity: AlwaysStoppedAnimation(0.5),
                  ),
                ),
                SizedBox(height: 16.rpx(context)),
                GradientText(
                  '暂无歌词',
                  style: TextStyle(
                    fontSize: 38.rpx(context),
                    fontWeight: FontWeight.bold,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0x62FFFFFF),
                      Color(0x13FFFFFF),
                    ], // 绿色到蓝色
                  ),
                ),
              ],
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: currentLyric.isNotEmpty
              ? BlurText(
                  key: ValueKey(currentLyric),
                  text: currentLyric,
                  textAlignment: TextAlignment.center,
                  textStyle: TextStyle(
                    fontSize: 89.rpx(context),
                    letterSpacing: 10.rpx(context),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF0F2FF),
                    shadows: [
                      Shadow(
                        blurRadius: 50.rpx(context), // 数值越大越“发光”
                        color: const Color(0xDE1E1BE8), // 发光色
                        offset: Offset(0, 0), // 发光一般用(0,0)
                      ),
                      Shadow(
                        blurRadius: 100.rpx(context), // 数值越大越“发光”
                        color: const Color(0xCE7E88F7), // 发光色
                        offset: Offset(0, 0), // 发光一般用(0,0)
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 500),
                  type: AnimationType.letter,
                  // slideType: SlideAnimationType.bottomTop,
                )
              : SizedBox.shrink(key: ValueKey('empty_lyric')),
        );
      }),
    );
  }
}
