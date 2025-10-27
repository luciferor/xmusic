import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/rpx.dart';

class AvatarHero extends StatefulWidget {
  final String avatar;
  final double size;
  final String heroTag;
  final double radius;

  const AvatarHero({
    super.key,
    required this.avatar,
    required this.size,
    this.heroTag = 'hero-avator',
    required this.radius,
  });

  @override
  State<AvatarHero> createState() => _AvatarHeroState();
}

class _AvatarHeroState extends State<AvatarHero> {
  final ImageCacheService _imageCacheService = ImageCacheService();
  String? _lastLoadedUrl;
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _preloadImage();
  }

  @override
  void didUpdateWidget(AvatarHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar != widget.avatar) {
      _lastLoadedUrl = oldWidget.avatar; // 保存旧头像URL
      _preloadImage();
    }
  }

  Future<void> _preloadImage() async {
    if (!widget.avatar.startsWith('http') || _isPreloading) return;

    _isPreloading = true;

    try {
      // 先尝试从缓存获取
      final imageData = await _imageCacheService.getImageData(widget.avatar);
      if (mounted && imageData != null) {
        setState(() {
          _lastLoadedUrl = widget.avatar;
        });
        if (kDebugMode) {
          print('✅ 从缓存加载头像成功');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取头像缓存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: toContext.widget,
                );
              },
            );
          },
      child: Container(
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 5.rpx(context)),
          borderRadius: BorderRadius.circular(widget.radius + 6.rpx(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: NeonFilter(
            colors: [Colors.pink, Colors.cyan, Colors.blue],
            blendMode: BlendMode.color,
            child: widget.avatar.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: widget.avatar,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 0),
                    fadeOutDuration: const Duration(milliseconds: 0),
                    placeholder: (context, url) {
                      // 如果有上一个加载成功的头像，显示它
                      if (_lastLoadedUrl != null &&
                          _lastLoadedUrl != widget.avatar) {
                        return CachedNetworkImage(
                          imageUrl: _lastLoadedUrl!,
                          width: widget.size,
                          height: widget.size,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              _buildDefaultAvatar(),
                        );
                      }
                      return _buildDefaultAvatar();
                    },
                    errorWidget: (context, url, error) => _buildDefaultAvatar(),
                    imageBuilder: (context, imageProvider) {
                      _lastLoadedUrl = widget.avatar; // 更新最后成功加载的URL
                      return Image(image: imageProvider, fit: BoxFit.cover);
                    },
                  )
                : _buildDefaultAvatar(),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.person_fill,
        color: Colors.grey[600],
        size: widget.size * 0.4,
      ),
    );
  }
}
