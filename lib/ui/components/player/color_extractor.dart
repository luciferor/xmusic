import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ColorExtractor {
  // 从图片数据提取主要颜色
  static Future<Map<String, Color>> extractColorsFromImageData(Uint8List imageData) async {
    try {
      final decodedImage = img.decodeImage(imageData);
      if (decodedImage == null) throw Exception('无法解码图片');
      
      // 缩小图片以提高性能
      final resizedImage = img.copyResize(decodedImage, width: 50, height: 50);
      
      final Map<int, int> colorCount = {};
      final List<Color> vibrantColors = [];
      final List<Color> mutedColors = [];
      
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
          
          // 分类颜色
          final hsl = HSLColor.fromColor(color);
          if (hsl.saturation > 0.3 && hsl.lightness > 0.2 && hsl.lightness < 0.8) {
            vibrantColors.add(color);
          } else {
            mutedColors.add(color);
          }
        }
      }
      
      // 找到出现最多的颜色
      int maxCount = 0;
      Color? dominantColor;
      for (final entry in colorCount.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          dominantColor = Color(entry.key);
        }
      }
      
      // 获取鲜艳颜色
      Color? vibrantColor;
      if (vibrantColors.isNotEmpty) {
        vibrantColor = vibrantColors.reduce((a, b) {
          final hslA = HSLColor.fromColor(a);
          final hslB = HSLColor.fromColor(b);
          return hslA.saturation > hslB.saturation ? a : b;
        });
      }
      
      // 获取柔和颜色
      Color? mutedColor;
      if (mutedColors.isNotEmpty) {
        mutedColor = mutedColors.reduce((a, b) {
          final hslA = HSLColor.fromColor(a);
          final hslB = HSLColor.fromColor(b);
          return hslA.saturation < hslB.saturation ? a : b;
        });
      }
      
      return {
        'dominant': dominantColor ?? Colors.grey,
        'vibrant': vibrantColor ?? dominantColor ?? Colors.grey,
        'muted': mutedColor ?? dominantColor ?? Colors.grey,
      };
    } catch (e) {
      return {
        'dominant': Colors.grey,
        'vibrant': Colors.grey,
        'muted': Colors.grey,
      };
    }
  }

  // 从网络图片URL提取颜色
  static Future<Map<String, Color>> extractColorsFromUrl(String imageUrl) async {
    try {
      // 这里需要实现网络图片下载逻辑
      // 由于需要网络请求，这里只是示例
      return {
        'dominant': Colors.grey,
        'vibrant': Colors.grey,
        'muted': Colors.grey,
      };
    } catch (e) {
      return {
        'dominant': Colors.grey,
        'vibrant': Colors.grey,
        'muted': Colors.grey,
      };
    }
  }
} 