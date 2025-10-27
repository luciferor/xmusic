import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:xmusic/services/image_color_service.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:get/get.dart';
import 'package:xmusic/ui/components/rpx.dart';

class PlayerIcon extends StatefulWidget {
  const PlayerIcon({
    super.key,
    required this.isPlaying,
    this.size,
    this.color = const Color(0xFF4285F4),
    this.imagePath,
    this.fileId,
    this.duration = const Duration(milliseconds: 700),
    this.showFrostOverlay = true,
    this.frostOpacity = 0.2,
    this.frostBlurSigma = 1.0,
  });

  final bool isPlaying;
  final double? size; // 可选
  final Color color;
  final String? imagePath;
  final String? fileId;
  final Duration duration;
  final bool showFrostOverlay;
  final double frostOpacity;
  final double frostBlurSigma;

  @override
  State<PlayerIcon> createState() => _PlayerIconState();
}

class _PlayerIconState extends State<PlayerIcon> with TickerProviderStateMixin {
  late final AnimationController _waveformController;
  final List<Animation<double>> _waveformAnimations = [];
  final int _maxBarCount = 5;
  int get _visibleBarCount => widget.isPlaying ? 5 : 3;
  final _random = Random();
  Color _currentColor = Colors.blue; // Default color
  ImageProvider? _imageProvider;
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _waveformController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.isPlaying) {
          _randomizeAnimations();
          _waveformController.forward(from: 0.0);
        }
      }
    });

    _randomizeAnimations();

    if (widget.isPlaying) {
      _waveformController.forward();
    }
    _updateImageProvider();
  }

  @override
  void didUpdateWidget(covariant PlayerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _randomizeAnimations();
        _waveformController.forward();
      } else {
        _waveformController.stop();
        _waveformController.reset();
      }
    }
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.fileId != widget.fileId) {
      _updateImageProvider();
    }
  }

  void _updateImageProvider() async {
    if (kDebugMode) {
      print('🖼️ PlayerIcon: _updateImageProvider called');
      print(
        '🖼️ PlayerIcon: imagePath=${widget.imagePath}, fileId=${widget.fileId}',
      );
    }

    // 优先 imagePath
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      if (kDebugMode) {
        print('🖼️ PlayerIcon: 使用提供的imagePath: ${widget.imagePath}');
      }
      _setImageProviderFromPath(widget.imagePath!);
      return;
    }
    // 其次 fileId
    if (widget.fileId != null && widget.fileId!.isNotEmpty) {
      final playerController = Get.isRegistered<PlayerUIController>()
          ? Get.find<PlayerUIController>()
          : null;
      String? coverPath;
      if (playerController != null) {
        // 优先使用当前播放曲目的完整信息
        final currentTrack = playerController.currentTrackInfo;
        Map<String, dynamic> track;

        if (kDebugMode) {
          print('🖼️ PlayerIcon: currentTrackInfo: $currentTrack');
        }

        if (currentTrack != null &&
            (currentTrack['file_id'] == widget.fileId ||
                currentTrack['fileId'] == widget.fileId ||
                currentTrack['id'] == widget.fileId)) {
          // 使用当前播放曲目的完整信息
          track = currentTrack;
          if (kDebugMode) {
            print('🖼️ PlayerIcon: 使用当前播放曲目信息');
          }
        } else {
          // 如果fileId不匹配，构造一个基本的track对象
          track = {
            'file_id': widget.fileId,
            'id': widget.fileId,
            'title': 'Unknown Track', // 添加默认title，避免getBestCoverPath返回空
            'name': 'Unknown Track', // 添加默认name
          };
          if (kDebugMode) {
            print('🖼️ PlayerIcon: 使用构造的track对象');
          }
        }

        coverPath = await playerController.getBestCoverPath(track);
        if (kDebugMode) {
          print(
            '🖼️ PlayerIcon: fileId=${widget.fileId}, coverPath=$coverPath',
          );
          print('🖼️ PlayerIcon: track info: $track');
        }
      } else {
        if (kDebugMode) {
          print('🖼️ PlayerIcon: PlayerUIController 未注册');
        }
      }
      if (coverPath != null && coverPath.isNotEmpty) {
        _setImageProviderFromPath(coverPath);
        return;
      } else {
        // fallback to default
        if (kDebugMode) {
          print('🖼️ PlayerIcon: 使用默认封面图片');
        }
        _setImageProviderFromPath('assets/images/Hi-Res.png');
        return;
      }
    }
    // fallback
    if (kDebugMode) {
      print('🖼️ PlayerIcon: 没有fileId，使用默认封面图片');
    }
    _setImageProviderFromPath('assets/images/Hi-Res.png');
  }

  void _setImageProviderFromPath(String path) {
    ImageProvider? newProvider;
    if (path.startsWith('http')) {
      newProvider = CachedNetworkImageProvider(path);
    } else if (path.startsWith('assets/')) {
      newProvider = AssetImage(path);
    } else {
      newProvider = FileImage(File(path));
    }
    if (_imageProvider != newProvider) {
      setState(() {
        _imageProvider = newProvider;
        _imageVersion++;
      });
      _updateColor();
    }
  }

  Future<void> _updateColor() async {
    if (_imageProvider != null) {
      final color = await ImageColorService().getDominantColor(
        _imageProvider!,
        defaultColor: widget.color,
      );
      if (mounted) {
        setState(() {
          _currentColor = color ?? widget.color;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentColor = widget.color;
        });
      }
    }
  }

  void _randomizeAnimations() {
    _waveformAnimations.clear();
    for (int i = 0; i < _maxBarCount; i++) {
      final peakHeight = _random.nextDouble() * 0.7 + 0.3;
      final startDelay = _random.nextDouble() * 0.6;
      final animationDuration = _random.nextDouble() * 0.3 + 0.4;
      _waveformAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.2,
              end: peakHeight,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: peakHeight,
              end: 0.2,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _waveformController,
            curve: Interval(
              startDelay,
              (startDelay + animationDuration).clamp(0.0, 1.0),
              curve: Curves.linear,
            ),
          ),
        ),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize =
            widget.size ??
            (constraints.hasBoundedWidth && constraints.hasBoundedHeight
                ? (constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight)
                : 72.0);

        // If no image is provided, fall back to the solid color icon.
        if (_imageProvider == null) {
          return _buildSolidColorIcon(iconSize);
        }

        // New implementation with image masking.
        return AnimatedOpacity(
          opacity: widget.isPlaying ? 1.0 : 0.2,
          duration: widget.duration,
          child: ClipOval(
            child: ClipPath(
              clipper: _BarsClipper(
                listenable: _waveformController,
                isPlaying: widget.isPlaying,
                animations: _waveformAnimations,
                visibleBarCount: _visibleBarCount,
              ),
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: widget.duration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: SizedBox(
                        key: ValueKey(_imageVersion),
                        width: iconSize,
                        height: iconSize,
                        child: Image(
                          image: _imageProvider!,
                          fit: BoxFit.cover,
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                    if (widget.showFrostOverlay)
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: widget.frostBlurSigma,
                            sigmaY: widget.frostBlurSigma,
                          ),
                          child: Container(
                            color: Colors.white.withValues(
                              alpha: widget.frostOpacity,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolidColorIcon(double iconSize) {
    return AnimatedOpacity(
      opacity: widget.isPlaying ? 1.0 : 0.2,
      duration: widget.duration,
      child: Center(
        child: AnimatedBuilder(
          animation: _waveformController,
          builder: (context, child) {
            if (!widget.isPlaying) {
              // 暂停时显示三个点
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(3, (index) {
                  final double dotSize = iconSize * 0.15;
                  final double horizontalMargin = iconSize * 0.05;
                  return Container(
                    width: dotSize,
                    height: dotSize,
                    margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                    decoration: BoxDecoration(
                      color: _currentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.35),
                          blurRadius: dotSize * 0.7,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 3.rpx(context),
                      ),
                    ),
                  );
                }),
              );
            }
            // 播放时显示5根竖条
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_visibleBarCount, (index) {
                if (index >= _waveformAnimations.length) {
                  return const SizedBox.shrink();
                }
                final double barWidth = iconSize * 0.12;
                final double horizontalMargin = iconSize * 0.04;
                final barHeight =
                    iconSize * 0.6 * _waveformAnimations[index].value;
                return Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: barWidth,
                    height: barHeight,
                    margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(barWidth / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors
                              .red, //_currentColor.withValues(alpha: 0.35),
                          blurRadius: barWidth * 2.2,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 3.rpx(context),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _BarsClipper extends CustomClipper<Path> {
  final Animation<double> listenable;
  final bool isPlaying;
  final List<Animation<double>> animations;
  final int visibleBarCount;

  _BarsClipper({
    required this.listenable,
    required this.isPlaying,
    required this.animations,
    required this.visibleBarCount,
  }) : super(reclip: listenable);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (!isPlaying) {
      // 暂停时显示三个点遮罩
      final double dotSize = size.width * 0.15;
      final double horizontalMargin = size.width * 0.05;
      final double totalContentWidth =
          (3 * dotSize) + (3 * 2 * horizontalMargin);
      double currentX = (size.width - totalContentWidth) / 2;
      for (int i = 0; i < 3; i++) {
        currentX += horizontalMargin;
        final rect = Rect.fromLTWH(
          currentX,
          (size.height - dotSize) / 2,
          dotSize,
          dotSize,
        );
        path.addOval(rect);
        currentX += dotSize + horizontalMargin;
      }
      return path;
    }
    // 播放时显示5根竖条遮罩
    final double barWidth = size.width * 0.12;
    final double horizontalMargin = size.width * 0.04;
    final double totalContentWidth =
        (visibleBarCount * barWidth) + (visibleBarCount * 2 * horizontalMargin);
    double currentX = (size.width - totalContentWidth) / 2;
    for (int i = 0; i < visibleBarCount; i++) {
      currentX += horizontalMargin;
      final barHeight = size.height * 0.6 * animations[i].value;
      final y = (size.height - barHeight) / 2;
      final rect = Rect.fromLTWH(currentX, y, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(barWidth / 2),
      );
      path.addRRect(rrect);
      currentX += barWidth + horizontalMargin;
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _BarsClipper oldClipper) {
    return oldClipper.isPlaying != isPlaying ||
        oldClipper.listenable != listenable;
  }
}
