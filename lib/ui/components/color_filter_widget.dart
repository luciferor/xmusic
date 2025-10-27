import 'dart:math';
import 'package:flutter/material.dart';

/// 滤镜组件 - 支持色相、饱和度、灰度、翻转等效果
class ColorFilterWidget extends StatefulWidget {
  final Widget child;

  // 色相调整 (-180 到 180)
  final double hue;

  // 饱和度调整 (0 到 2, 1为正常)
  final double saturation;

  // 自然饱和度/鲜艳度 (vibrance) (-1 到 1, 0 为正常)
  final double vibrance;

  // 灰度 (0 到 1, 0为正常, 1为完全灰度)
  final double grayscale;

  // 亮度调整 (0 到 2, 1为正常)
  final double brightness;

  // 对比度调整 (0 到 2, 1为正常)
  final double contrast;

  // 曝光 (以档为单位，-2 到 2，0 为正常)
  final double exposure;

  // 色温 (-1 到 1，0 为正常；>0 更暖 <0 更冷)
  final double temperature;

  // 色调/偏色 (tint) (-1 到 1，0 为正常；>0 更偏绿 <0 更偏洋红)
  final double tint;

  // 高光 (-1 到 1，0 为正常)
  final double highlights;

  // 阴影 (-1 到 1，0 为正常)
  final double shadows;

  // 鲜明度/清晰度 (clarity) (-1 到 1，0 为正常)
  final double clarity;

  // 锐度 (占位，当前未实现卷积锐化) (-1 到 1，0 为正常)
  final double sharpness;

  // 是否水平翻转
  final bool flipHorizontal;

  // 是否垂直翻转
  final bool flipVertical;

  // 是否启用滤镜
  final bool enabled;

  const ColorFilterWidget({
    super.key,
    required this.child,
    this.hue = 0.0,
    this.saturation = 1.0,
    this.vibrance = 0.0,
    this.grayscale = 0.0,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.exposure = 0.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.clarity = 0.0,
    this.sharpness = 0.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.enabled = true,
  });

  @override
  State<ColorFilterWidget> createState() => _ColorFilterWidgetState();
}

class _ColorFilterWidgetState extends State<ColorFilterWidget> {
  late List<double> _matrix;
  late bool _hasColorFilter;
  late bool _hasTransform;

  @override
  void initState() {
    super.initState();
    _updateMatrix();
  }

  @override
  void didUpdateWidget(ColorFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hue != widget.hue ||
        oldWidget.saturation != widget.saturation ||
        oldWidget.vibrance != widget.vibrance ||
        oldWidget.grayscale != widget.grayscale ||
        oldWidget.brightness != widget.brightness ||
        oldWidget.contrast != widget.contrast ||
        oldWidget.exposure != widget.exposure ||
        oldWidget.temperature != widget.temperature ||
        oldWidget.tint != widget.tint ||
        oldWidget.highlights != widget.highlights ||
        oldWidget.shadows != widget.shadows ||
        oldWidget.clarity != widget.clarity ||
        oldWidget.sharpness != widget.sharpness ||
        oldWidget.flipHorizontal != widget.flipHorizontal ||
        oldWidget.flipVertical != widget.flipVertical ||
        oldWidget.enabled != widget.enabled) {
      _updateMatrix();
    }
  }

  void _updateMatrix() {
    _matrix = _getColorMatrix();
    _hasColorFilter =
        widget.hue != 0.0 ||
        widget.saturation != 1.0 ||
        widget.vibrance != 0.0 ||
        widget.grayscale > 0.0 ||
        widget.brightness != 1.0 ||
        widget.contrast != 1.0 ||
        widget.exposure != 0.0 ||
        widget.temperature != 0.0 ||
        widget.tint != 0.0 ||
        widget.highlights != 0.0 ||
        widget.shadows != 0.0 ||
        widget.clarity != 0.0;
    _hasTransform = widget.flipHorizontal || widget.flipVertical;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    Widget result = widget.child;

    // 应用颜色滤镜
    if (_hasColorFilter) {
      result = RepaintBoundary(
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_matrix),
          child: result,
        ),
      );
    }

    // 应用翻转
    if (_hasTransform) {
      result = Transform(
        transform: Matrix4.identity()
          ..setEntry(0, 0, widget.flipHorizontal ? -1 : 1)
          ..setEntry(1, 1, widget.flipVertical ? -1 : 1),
        alignment: Alignment.center,
        child: result,
      );
    }

    return result;
  }

  /// 获取颜色矩阵
  List<double> _getColorMatrix() {
    // 基础矩阵 - 单位矩阵 (20个元素)
    List<double> matrix = [
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // 曝光（乘法增益，类似提高/降低整体曝光）
    if (widget.exposure != 0.0) {
      matrix = _multiplyMatrices([matrix, _getExposureMatrix(widget.exposure)]);
    }

    // 色温
    if (widget.temperature != 0.0) {
      matrix = _multiplyMatrices([
        matrix,
        _getTemperatureMatrix(widget.temperature),
      ]);
    }

    // 色调/偏色 (tint)
    if (widget.tint != 0.0) {
      matrix = _multiplyMatrices([matrix, _getTintMatrix(widget.tint)]);
    }

    // 应用色相
    if (widget.hue != 0.0) {
      matrix = _multiplyMatrices([matrix, _getHueMatrix(widget.hue)]);
    }

    // 应用饱和度 + 自然饱和度(近似)
    final double effectiveSaturation =
        widget.saturation * (1.0 + widget.vibrance * 0.5);
    if (effectiveSaturation != 1.0) {
      matrix = _multiplyMatrices([
        matrix,
        _getSaturationMatrix(effectiveSaturation),
      ]);
    }

    // 应用灰度
    if (widget.grayscale > 0.0) {
      matrix = _multiplyMatrices([
        matrix,
        _getGrayscaleMatrix(widget.grayscale),
      ]);
    }

    // 阴影/高光(近似到亮度/对比度)
    final double brightnessFromHighlightsShadows =
        1.0 + (widget.highlights * 0.1) - (widget.shadows * 0.1);
    final double contrastFromHighlightsShadows =
        1.0 + (widget.highlights * 0.2) - (widget.shadows * 0.2);

    // 应用亮度
    final double effectiveBrightness =
        widget.brightness * brightnessFromHighlightsShadows;
    if (effectiveBrightness != 1.0) {
      matrix = _multiplyMatrices([
        matrix,
        _getBrightnessMatrix(effectiveBrightness),
      ]);
    }

    // 应用对比度 + 鲜明度(近似)
    final double effectiveContrast =
        widget.contrast *
        contrastFromHighlightsShadows *
        (1.0 + widget.clarity * 0.3);
    if (effectiveContrast != 1.0) {
      matrix = _multiplyMatrices([
        matrix,
        _getContrastMatrix(effectiveContrast),
      ]);
    }

    return matrix;
  }

  /// 色相矩阵 (20个元素)
  List<double> _getHueMatrix(double hue) {
    final rad = hue * pi / 180;
    final cosVal = cos(rad);
    final sinVal = sin(rad);

    return [
      (0.213 + cosVal * 0.787 - sinVal * 0.213),
      (0.213 - cosVal * 0.213 + sinVal * 0.143),
      (0.213 - cosVal * 0.213 - sinVal * 0.787),
      0.0,
      0.0,
      (0.715 - cosVal * 0.715 - sinVal * 0.715),
      (0.715 + cosVal * 0.285 + sinVal * 0.140),
      (0.715 - cosVal * 0.715 + sinVal * 0.715),
      0.0,
      0.0,
      (0.072 - cosVal * 0.072 + sinVal * 0.072),
      (0.072 - cosVal * 0.072 - sinVal * 0.283),
      (0.072 + cosVal * 0.928 + sinVal * 0.072),
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 饱和度矩阵 (20个元素)
  List<double> _getSaturationMatrix(double saturation) {
    final s = saturation;
    return [
      (0.213 + 0.787 * s),
      (0.213 - 0.213 * s),
      (0.213 - 0.213 * s),
      0.0,
      0.0,
      (0.715 - 0.715 * s),
      (0.715 + 0.285 * s),
      (0.715 - 0.715 * s),
      0.0,
      0.0,
      (0.072 - 0.072 * s),
      (0.072 - 0.072 * s),
      (0.072 + 0.928 * s),
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 灰度矩阵 (20个元素)
  List<double> _getGrayscaleMatrix(double grayscale) {
    final g = grayscale;
    return [
      (1.0 - g) + g * 0.213,
      g * 0.715,
      g * 0.072,
      0.0,
      0.0,
      g * 0.213,
      (1.0 - g) + g * 0.715,
      g * 0.072,
      0.0,
      0.0,
      g * 0.213,
      g * 0.715,
      (1.0 - g) + g * 0.072,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 亮度矩阵 (20个元素)
  List<double> _getBrightnessMatrix(double brightness) {
    return [
      1.0,
      0.0,
      0.0,
      0.0,
      (brightness - 1.0) * 255,
      0.0,
      1.0,
      0.0,
      0.0,
      (brightness - 1.0) * 255,
      0.0,
      0.0,
      1.0,
      0.0,
      (brightness - 1.0) * 255,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 对比度矩阵 (20个元素)
  List<double> _getContrastMatrix(double contrast) {
    return [
      contrast,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      contrast,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      contrast,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 曝光矩阵 (20个元素) - 通过整体增益调整
  List<double> _getExposureMatrix(double exposure) {
    final double gain = pow(2.0, exposure).toDouble();
    return [
      gain,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      gain,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      gain,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 色温矩阵 (20个元素) - 调整 R/B 通道增益
  List<double> _getTemperatureMatrix(double temperature) {
    final double t = temperature.clamp(-1.0, 1.0);
    final double r = 1.0 + 0.1 * t;
    final double b = 1.0 - 0.1 * t;
    return [
      r,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      b,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 色调/偏色矩阵 (20个元素) - 调整 G 通道相对 R/B 的增益
  List<double> _getTintMatrix(double tint) {
    final double t = tint.clamp(-1.0, 1.0);
    final double g = 1.0 + 0.1 * t;
    final double rb = 1.0 - 0.05 * t;
    return [
      rb,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      g,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      rb,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// 矩阵乘法 (20个元素)
  List<double> _multiplyMatrices(List<List<double>> matrices) {
    if (matrices.isEmpty) {
      return [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
    }
    if (matrices.length == 1) return matrices.first;

    List<double> result = matrices.first;
    for (int i = 1; i < matrices.length; i++) {
      result = _multiplyTwoMatrices(result, matrices[i]);
    }
    return result;
  }

  /// 两个矩阵相乘 (20个元素)
  List<double> _multiplyTwoMatrices(List<double> a, List<double> b) {
    List<double> result = List.filled(20, 0.0);

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 5; j++) {
        for (int k = 0; k < 4; k++) {
          result[i * 5 + j] += a[i * 5 + k] * b[k * 5 + j];
        }
      }
    }

    return result;
  }
}

/// 预设滤镜效果
class FilterPresets {
  /// 复古效果
  static ColorFilterWidget vintage(Widget child) => ColorFilterWidget(
    child: child,
    hue: 30.0,
    saturation: 0.8,
    brightness: 1.1,
    contrast: 1.2,
  );

  /// 黑白效果
  static ColorFilterWidget blackAndWhite(Widget child) =>
      ColorFilterWidget(child: child, grayscale: 1.0);

  /// 冷色调
  static ColorFilterWidget coolTone(Widget child) =>
      ColorFilterWidget(child: child, hue: -30.0, saturation: 1.2);

  /// 暖色调
  static ColorFilterWidget warmTone(Widget child) =>
      ColorFilterWidget(child: child, hue: 30.0, saturation: 1.2);

  /// 高对比度
  static ColorFilterWidget highContrast(Widget child) =>
      ColorFilterWidget(child: child, contrast: 1.5, saturation: 1.3);

  /// 柔和效果
  static ColorFilterWidget soft(Widget child) => ColorFilterWidget(
    child: child,
    saturation: 0.8,
    brightness: 1.1,
    contrast: 0.9,
  );

  /// 锐化效果
  static ColorFilterWidget sharp(Widget child) =>
      ColorFilterWidget(child: child, contrast: 1.3, saturation: 1.1);

  /// 深色光晕效果 - 模拟图片中的深色基底+紫色光晕
  static ColorFilterWidget darkGlow(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.3, // 深色基底
    contrast: 1.8, // 高对比度
    saturation: 1.4, // 增强色彩
    hue: 60, // 向紫色偏移
    grayscale: 0.0, // 保持彩色
  );

  /// 紫色梦幻效果
  static ColorFilterWidget purpleDream(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.4,
    contrast: 1.6,
    saturation: 1.5,
    hue: 90, // 更强的紫色偏移
    grayscale: 0.0,
  );

  /// 品红光晕效果
  static ColorFilterWidget magentaGlow(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.35,
    contrast: 1.7,
    saturation: 1.6,
    hue: 45, // 品红色偏移
    grayscale: 0.0,
  );

  /// 赛博朋克效果 - 绿色/青色霓虹光
  static ColorFilterWidget cyberpunk(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.25, // 深色基底
    contrast: 2.2, // 高对比度
    saturation: 1.8, // 高饱和度
    hue: -120, // 绿色/青色偏移
    grayscale: 0.0, // 保持彩色
  );

  /// 霓虹绿效果
  static ColorFilterWidget neonGreen(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.3,
    contrast: 2.0,
    saturation: 1.9,
    hue: -90, // 绿色偏移
    grayscale: 0.0,
  );

  /// 青色科技感
  static ColorFilterWidget cyanTech(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.28,
    contrast: 2.1,
    saturation: 1.7,
    hue: -150, // 青色偏移
    grayscale: 0.0,
  );

  /// 荧光黄效果 - 模拟图片中的亮黄色/荧光绿风格
  static ColorFilterWidget fluorescentYellow(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.8, // 适中的亮度
    contrast: 1.8, // 高对比度
    saturation: 2.2, // 极高饱和度
    hue: 75, // 亮黄色/荧光绿偏移
    grayscale: 0.0, // 保持彩色
  );

  /// 暖黄光晕效果
  static ColorFilterWidget warmYellowGlow(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.7,
    contrast: 1.6,
    saturation: 2.0,
    hue: 50, // 暖黄色偏移
    grayscale: 0.0,
  );

  /// 亮绿科技感
  static ColorFilterWidget brightGreenTech(Widget child) => ColorFilterWidget(
    child: child,
    brightness: 0.75,
    contrast: 1.9,
    saturation: 2.1,
    hue: 90, // 亮绿色偏移
    grayscale: 0.0,
  );
}

/// 便捷的滤镜构建器
class FilterBuilder {
  double _hue = 0.0;
  double _saturation = 1.0;
  double _grayscale = 0.0;
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _enabled = true;

  FilterBuilder hue(double value) {
    _hue = value;
    return this;
  }

  FilterBuilder saturation(double value) {
    _saturation = value;
    return this;
  }

  FilterBuilder grayscale(double value) {
    _grayscale = value;
    return this;
  }

  FilterBuilder brightness(double value) {
    _brightness = value;
    return this;
  }

  FilterBuilder contrast(double value) {
    _contrast = value;
    return this;
  }

  FilterBuilder flipHorizontal() {
    _flipHorizontal = true;
    return this;
  }

  FilterBuilder flipVertical() {
    _flipVertical = true;
    return this;
  }

  FilterBuilder disable() {
    _enabled = false;
    return this;
  }

  ColorFilterWidget build(Widget child) {
    return ColorFilterWidget(
      child: child,
      hue: _hue,
      saturation: _saturation,
      grayscale: _grayscale,
      brightness: _brightness,
      contrast: _contrast,
      flipHorizontal: _flipHorizontal,
      flipVertical: _flipVertical,
      enabled: _enabled,
    );
  }
}
