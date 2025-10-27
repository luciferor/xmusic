import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlurOpacityController extends GetxController {
  var blurValue = 10.0.obs;
  var opacityValue = 0.0.obs;
  var lightValue = 50.0.obs;
  var sexiangValue = 0.0.obs;
  var baoheduValue = 0.0.obs;
  var isEnabled = false.obs; // 网络歌词开关状态
  var isNeoned = false.obs; //图片滤镜开关

  //全局
  var brightness = 1.0.obs; // 亮度调整 (0 到 2, 1为正常)
  var contrast = 1.0.obs; // 对比度调整 (0 到 2, 1为正常)
  var saturation = 1.0.obs; // 饱和度调整 (0 到 2, 1为正常)
  var hue = 0.0.obs; // 色相调整 (-180 到 180)
  var grayscale = 0.0.obs; // 灰度 (0 到 1, 0为正常, 1为完全灰度)
  var vibrance = 0.0.obs; // 自然饱和度/鲜艳度 (vibrance) (-1 到 1, 0 为正常)
  var exposure = 0.0.obs; // 曝光 (以档为单位，-2 到 2，0 为正常)
  var temperature = 0.0.obs; // 色温 (-1 到 1，0 为正常；>0 更暖 <0 更冷)
  var tint = 0.0.obs; // 色调/偏色 (tint) (-1 到 1，0 为正常；>0 更偏绿 <0 更偏洋红)
  var highlights = 0.0.obs; //高光 (-1 到 1，0 为正常)
  var shadows = 0.0.obs; //阴影 (-1 到 1，0 为正常)
  var clarity = 0.0.obs; //鲜明度/清晰度 (clarity) (-1 到 1，0 为正常)
  var sharpness = 0.0.obs; //锐度 (占位，当前未实现卷积锐化) (-1 到 1，0 为正常)
  var enabled = false.obs; //是否启用滤镜

  @override
  void onInit() {
    super.onInit();
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      blurValue.value = prefs.getDouble('blurValue') ?? 0.0;
      opacityValue.value = prefs.getDouble('opacityValue') ?? 0.0;
      lightValue.value = prefs.getDouble('lightValue') ?? 50;
      sexiangValue.value = prefs.getDouble('sexiangValue') ?? 0.0;
      baoheduValue.value = prefs.getDouble('baoheduValue') ?? 0.0;
      isEnabled.value = prefs.getBool('isEnabled') ?? true; // 加载开关状态
      isNeoned.value = prefs.getBool('isNeoned') ?? false;

      //全局
      brightness.value = prefs.getDouble('brightness') ?? 100.0;
      contrast.value = prefs.getDouble('contrast') ?? 100.0;
      saturation.value = prefs.getDouble('saturation') ?? 100.0;
      hue.value = prefs.getDouble('hue') ?? 0.0;
      grayscale.value = prefs.getDouble('grayscale') ?? 0.0;
      vibrance.value = prefs.getDouble('vibrance') ?? 0.0;
      exposure.value = prefs.getDouble('exposure') ?? 0.0;
      temperature.value = prefs.getDouble('temperature') ?? 0.0;
      tint.value = prefs.getDouble('tint') ?? 0.0;
      highlights.value = prefs.getDouble('highlights') ?? 0.0;
      shadows.value = prefs.getDouble('shadows') ?? 0.0;
      clarity.value = prefs.getDouble('clarity') ?? 0.0;
      sharpness.value = prefs.getDouble('sharpness') ?? 0.0;
      enabled.value = prefs.getBool('enabled') ?? false;

      if (kDebugMode) {
        print(
          '🔍 BlurOpacityController: 加载值 - blur: ${blurValue.value}, opacity: ${opacityValue.value}, isEnabled: ${isEnabled.value}',
        );
      }
    } catch (e) {
      // 如果读取失败，使用默认值
      blurValue.value = 10.0;
      opacityValue.value = 0.0;
      lightValue.value = 50;
      sexiangValue.value = 0.0;
      baoheduValue.value = 0.0;
      isEnabled.value = false;
      isNeoned.value = false;

      //全局
      brightness.value = 1.0; // 亮度调整 (0 到 2, 1为正常)
      contrast.value = 1.0; // 对比度调整 (0 到 2, 1为正常)
      saturation.value = 1.0; // 饱和度调整 (0 到 2, 1为正常)
      hue.value = 0.0; // 色相调整 (-180 到 180)
      grayscale.value = 0.0; // 灰度 (0 到 1, 0为正常, 1为完全灰度)
      vibrance.value = 0.0; // 自然饱和度/鲜艳度 (vibrance) (-1 到 1, 0 为正常)
      exposure.value = 0.0; // 曝光 (以档为单位，-2 到 2，0 为正常)
      temperature.value = 0.0; // 色温 (-1 到 1，0 为正常；>0 更暖 <0 更冷)
      tint.value = 0.0; // 色调/偏色 (tint) (-1 到 1，0 为正常；>0 更偏绿 <0 更偏洋红)
      highlights.value = 0.0; //高光 (-1 到 1，0 为正常)
      shadows.value = 0.0; //阴影 (-1 到 1，0 为正常)
      clarity.value = 0.0; //鲜明度/清晰度 (clarity) (-1 到 1，0 为正常)
      sharpness.value = 0.0; //锐度 (占位，当前未实现卷积锐化) (-1 到 1，0 为正常)
      enabled.value = false; //是否启用滤镜
      if (kDebugMode) {
        print('❌ BlurOpacityController: 加载失败，使用默认值');
      }
    }
  }

  Future<void> saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('blurValue', blurValue.value);
      await prefs.setDouble('opacityValue', opacityValue.value);
      await prefs.setDouble('lightValue', lightValue.value);
      await prefs.setDouble('sexiangtValue', sexiangValue.value);
      await prefs.setDouble('baoheduValue', baoheduValue.value);
      await prefs.setBool('isEnabled', isEnabled.value); // 保存开关状态
      await prefs.setBool('isNeoned', isNeoned.value);

      //全局
      await prefs.setDouble('brightness', brightness.value);
      await prefs.setDouble('contrast', contrast.value);
      await prefs.setDouble('saturation', saturation.value);
      await prefs.setDouble('hue', hue.value);
      await prefs.setDouble('grayscale', grayscale.value);
      await prefs.setDouble('vibrance', vibrance.value);
      await prefs.setDouble('exposure', exposure.value);
      await prefs.setDouble('temperature', temperature.value);
      await prefs.setDouble('tint', tint.value);
      await prefs.setDouble('highlights', highlights.value);
      await prefs.setDouble('shadows', shadows.value);
      await prefs.setDouble('clarity', clarity.value);
      await prefs.setDouble('sharpness', sharpness.value);
      await prefs.setBool('enabled', enabled.value);

      if (kDebugMode) {
        print(
          '💾 BlurOpacityController: 保存值 - blur: ${blurValue.value}, opacity: ${opacityValue.value}, isEnabled: ${isEnabled.value}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ BlurOpacityController: 保存失败 - $e');
      }
    }
  }

  void setBlurValue(double value) {
    blurValue.value = value;
    saveToLocal();
  }

  void setOpacityValue(double value) {
    opacityValue.value = value;
    saveToLocal();
  }

  void setLightValue(double value) {
    lightValue.value = value;
    saveToLocal();
  }

  void setSexiangValue(double value) {
    sexiangValue.value = value;
    saveToLocal();
  }

  void setBaoheduValue(double value) {
    baoheduValue.value = value;
    saveToLocal();
  }

  void toggleEnabled(bool value) {
    isEnabled.value = value;
    saveToLocal();
  }

  void toggleNeoned(bool value) {
    isNeoned.value = value;
    saveToLocal();
  }

  //全局

  void setBrightness(double value) {
    brightness.value = value;
    saveToLocal();
  }

  void setContrast(double value) {
    contrast.value = value;
    saveToLocal();
  }

  void setSaturation(double value) {
    saturation.value = value;
    saveToLocal();
  }

  void setHue(double value) {
    hue.value = value;
    saveToLocal();
  }

  void setGrayscale(double value) {
    grayscale.value = value;
    saveToLocal();
  }

  void setVibrance(double value) {
    vibrance.value = value;
    saveToLocal();
  }

  void setExposure(double value) {
    exposure.value = value;
    saveToLocal();
  }

  void setTemperature(double value) {
    temperature.value = value;
    saveToLocal();
  }

  void setTint(double value) {
    tint.value = value;
    saveToLocal();
  }

  void setHighlights(double value) {
    highlights.value = value;
    saveToLocal();
  }

  void setShadows(double value) {
    shadows.value = value;
    saveToLocal();
  }

  void setClarity(double value) {
    clarity.value = value;
    saveToLocal();
  }

  void setSharpness(double value) {
    sharpness.value = value;
    saveToLocal();
  }

  void setEnabled(bool value) {
    enabled.value = value;
    saveToLocal();
  }
}
