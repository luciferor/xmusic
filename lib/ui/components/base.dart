import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/ui/components/color_filter_widget.dart';
import 'package:xmusic/ui/components/liquidglass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math';
import 'package:xmusic/ui/components/neonfilter.dart';

// 背景图片控制器
class BackgroundController extends GetxController {
  static BackgroundController get to => Get.find();

  final selectedBackgroundImage = RxString('');
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSelectedBackground();
  }

  Future<void> _loadSelectedBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBackground = prefs.getString('selected_background_image');
      selectedBackgroundImage.value = savedBackground ?? '';
      isLoading.value = false;
      // ignore: empty_catches
    } catch (e) {}
  }

  // 更新背景图片
  Future<void> updateBackgroundImage(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_background_image', imagePath);
      selectedBackgroundImage.value = imagePath;
      // ignore: empty_catches
    } catch (e) {}
  }
}

// ignore: must_be_immutable
class Base extends StatefulWidget {
  Base({super.key, this.child});
  Widget? child;

  @override
  // ignore: library_private_types_in_public_api
  _BaseState createState() => _BaseState();
}

class _BaseState extends State<Base> {
  late BackgroundController _backgroundController;
  late BlurOpacityController _boController;

  @override
  void initState() {
    super.initState();
    _backgroundController = Get.find<BackgroundController>();
    _boController = Get.find<BlurOpacityController>();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark, // iOS白字
        statusBarIconBrightness: Brightness.light, // Android白字
        statusBarColor: Colors.transparent,
      ),
    );
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Obx(() {
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
          child: Stack(
            children: [
              // 1. 背景图片
              Positioned.fill(
                child: ColorFiltered(
                  key: ValueKey(
                    '${_boController.sexiangValue.value.toStringAsFixed(2)}_${_boController.baoheduValue.value.toStringAsFixed(2)}',
                  ),
                  colorFilter: ColorFilter.matrix(
                    _createHueSaturationMatrix(
                      _boController.sexiangValue.value / 100,
                      _boController.baoheduValue.value / 100,
                    ),
                  ),
                  child: NeonFilter(
                    colors: [Colors.pink, Colors.cyan, Colors.blue],
                    blendMode: BlendMode.color,
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 800),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: _backgroundController.isLoading.value
                          ? Image.asset(
                              'assets/images/bgs/1159626.jpg', // 默认背景
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Image.asset(
                              _backgroundController
                                      .selectedBackgroundImage
                                      .value
                                      .isNotEmpty
                                  ? _backgroundController
                                        .selectedBackgroundImage
                                        .value
                                  : 'assets/images/bgs/1159626.jpg',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                    ),
                  ),
                ),
              ),
              // 3. 液态玻璃效果（定位到底部）
              Positioned.fill(
                child: LiquidGlassContainer(
                  width: screenWidth, // 宽度全屏
                  height: screenHeight,
                  blurRadius: 0, // 保持原高度或根据需要调整
                  child: SafeArea(child: widget.child!),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<double> _createHueSaturationMatrix(double hue, double saturation) {
    // 色相旋转 (0-1 范围转换为 0-360 度)
    double hueDegrees = hue * 360.0;
    double hueRad = hueDegrees * pi / 180.0;

    // 饱和度调整 (0-1 范围)
    double sat = saturation;

    // 创建色相旋转矩阵 (在 RGB 色彩空间中)
    // 使用标准的色相旋转公式
    double cosHue = cos(hueRad);
    double sinHue = sin(hueRad);

    // 色相旋转矩阵 (3x3 RGB 变换)
    double r1 = 0.213 + 0.787 * cosHue - 0.213 * sinHue;
    double r2 = 0.213 - 0.213 * cosHue + 0.143 * sinHue;
    double r3 = 0.213 - 0.213 * cosHue - 0.787 * sinHue;

    double g1 = 0.715 - 0.715 * cosHue - 0.715 * sinHue;
    double g2 = 0.715 + 0.285 * cosHue + 0.140 * sinHue;
    double g3 = 0.715 - 0.715 * cosHue + 0.715 * sinHue;

    double b1 = 0.072 - 0.072 * cosHue + 0.928 * sinHue;
    double b2 = 0.072 - 0.072 * cosHue - 0.283 * sinHue;
    double b3 = 0.072 + 0.928 * cosHue + 0.072 * sinHue;

    // 饱和度调整
    double satFactor = 1.0 + sat;

    // 返回 4x5 矩阵 (Flutter ColorFilter 需要 20 个元素)
    // 格式: [R1, R2, R3, R4, R5, G1, G2, G3, G4, G5, B1, B2, B3, B4, B5, A1, A2, A3, A4, A5]
    return [
      r1 * satFactor, r2 * satFactor, r3 * satFactor, 0, 0, // R行
      g1 * satFactor, g2 * satFactor, g3 * satFactor, 0, 0, // G行
      b1 * satFactor, b2 * satFactor, b3 * satFactor, 0, 0, // B行
      0, 0, 0, 1, 0, // A行 (Alpha通道保持不变)
    ];
  }
}
