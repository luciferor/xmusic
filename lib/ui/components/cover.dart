import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:xmusic/services/cover_controller.dart';
import 'package:glossy/glossy.dart';
import 'package:xmusic/ui/components/color_filter_widget.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/rpx.dart';

// ignore: must_be_immutable
class CoverBase extends StatelessWidget {
  final Widget? child;
  const CoverBase({super.key, this.child});

  Future<Uint8List?> _loadCacheImage(String fileId) async {
    if (fileId.isEmpty) return null;
    return await ImageCacheService().getFromLocalCache(fileId);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
    return Scaffold(
      body: Obx(() {
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
              // 1. 背景图片
              Positioned.fill(
                child: NeonFilter(
                  colors: [Colors.pink, Colors.cyan, Colors.blue],
                  blendMode: BlendMode.color,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: FutureBuilder<Uint8List?>(
                      key: ValueKey(Get.find<CoverController>().fileId.value),
                      future: _loadCacheImage(
                        Get.find<CoverController>().fileId.value,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        }
                        return Image.asset(
                          'assets/images/bgs/1159626.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    ),
                  ),
                ),
              ),
              // 2. 液态玻璃效果（你的代码，绝不动）
              Positioned.fill(
                child: GlossyContainer(
                  width: double.infinity,
                  height: double.infinity,
                  strengthX: 10,
                  strengthY: 10,
                  gradient: GlossyLinearGradient(
                    colors: [
                      const Color.fromARGB(214, 0, 0, 0),
                      const Color.fromARGB(218, 0, 0, 0),
                      const Color.fromARGB(218, 0, 0, 0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    opacity: 0.5,
                  ),
                  border: BoxBorder.all(
                    color: const Color(0x31DEFDFF),
                    width: 0.rpx(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x07FF0000),
                      blurRadius: 30.rpx(context),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(0.rpx(context)),
                  child: SafeArea(child: child!),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
