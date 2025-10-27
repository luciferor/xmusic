import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:xmusic/ui/components/neonfilter.dart';

class CachedImage extends StatefulWidget {
  final String imageUrl;
  final String? cacheKey; // 新增：自定义缓存key（如fileId）
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool showLoadingIndicator;
  final bool fadeIn; // 新增：是否启用淡入效果

  const CachedImage({
    Key? key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.showLoadingIndicator = true,
    this.fadeIn = true, // 默认启用淡入效果
  }) : super(key: key);

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isImageReady = false; // 图片是否准备就绪
  final ImageCacheService _imageCacheService = ImageCacheService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true; // 保持 State，不会因页面切换被销毁

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当 URL 变化时才重新加载
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _isImageReady = false;
      });
      return;
    }

    final cacheKey = widget.cacheKey ?? widget.imageUrl;

    // ===== 1. 优先检查内存缓存（直接同步赋值，不 setState，不闪烁） =====
    final memoryData = _imageCacheService.getFromMemoryCache(cacheKey);
    if (memoryData != null) {
      _imageData = memoryData;
      _isLoading = false;
      _hasError = false;
      _isImageReady = true;

      if (widget.fadeIn) {
        _animationController.value = 1.0; // 已缓存的图片直接显示
      }
      return; // 命中内存缓存直接结束，不触发 setState
    }

    // ===== 2. 检查本地缓存（也不显示loading） =====
    final isCached = await _imageCacheService.isCachedLocally(cacheKey);
    if (isCached) {
      final localData = await _imageCacheService.getFromLocalCache(cacheKey);
      if (localData != null) {
        _imageData = localData;
        _isLoading = false;
        _hasError = false;
        _isImageReady = true;

        if (widget.fadeIn) {
          _animationController.forward();
        }
        if (mounted) setState(() {}); // 本地缓存命中，直接刷新
        return;
      }
    }

    // ===== 3. 网络加载（显示 loading） =====
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isImageReady = false;
      });
    }

    try {
      final imageData = await _imageCacheService.getImageData(
        widget.imageUrl,
        cacheKey: widget.cacheKey,
      );

      if (mounted) {
        _imageData = imageData;
        _isLoading = false;
        _hasError = imageData == null;
        _isImageReady = imageData != null;

        if (_isImageReady && widget.fadeIn) {
          _animationController.forward();
        }
        setState(() {});
      }
    } catch (e) {
      print('❌ CachedImage 图片加载异常: $e');
      if (mounted) {
        _isLoading = false;
        _hasError = true;
        _isImageReady = false;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAlive 必须调用
    Widget imageWidget;

    if (_isLoading && !_isImageReady) {
      imageWidget =
          widget.placeholder ??
          (widget.showLoadingIndicator
              ? Container(
                  width: widget.width,
                  height: widget.height,
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[600]!,
                      ),
                    ),
                  ),
                )
              : Container(
                  width: widget.width,
                  height: widget.height,
                  color: Colors.grey[300],
                ));
    } else if (_hasError || _imageData == null) {
      imageWidget =
          widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600], size: 30),
          );
    } else {
      imageWidget = Image.memory(
        _imageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey[300],
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[600],
                  size: 30,
                ),
              );
        },
      );
    }

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    if (widget.fadeIn && _isImageReady && !_isLoading) {
      imageWidget = FadeTransition(opacity: _fadeAnimation, child: imageWidget);
    }

    return NeonFilter(
      colors: [Colors.pink, Colors.cyan, Colors.blue],
      blendMode: BlendMode.color,
      child: imageWidget,
    );
  }
}

// 预加载工具
class ImagePreloader {
  static final ImageCacheService _imageCacheService = ImageCacheService();

  static Future<void> preloadImage(String url) async {
    await _imageCacheService.preloadImage(url);
  }

  static Future<void> preloadImages(List<String> urls) async {
    final uniqueUrls = urls.toSet().toList();
    print('⭐️ ImagePreloader: 预加载 ${uniqueUrls.length} 张图片（去重后）⭐️');
    await _imageCacheService.preloadImages(uniqueUrls);
  }

  static Future<void> preloadPlaylistCovers(
    List<Map<String, dynamic>> playlist,
  ) async {
    final coverUrls = <String>[];
    for (final track in playlist) {
      final coverUrl = track['cover'] ?? track['cover_url'] ?? '';
      if (coverUrl.isNotEmpty && coverUrl.startsWith('http')) {
        coverUrls.add(coverUrl);
      }
    }
    if (coverUrls.isNotEmpty) {
      await preloadImages(coverUrls);
    }
  }
}
