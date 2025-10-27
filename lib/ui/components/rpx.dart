import 'package:flutter/material.dart';

class Responsive {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double responsiveSize(
    double designSize,
    BuildContext context, {
    double designWidth = 750,
  }) {
    return designSize * (screenWidth(context) / designWidth);
  }
}

// 扩展方法版本（类似您的 rpx 用法）
extension ResponsiveExtension on num {
  double rpx(BuildContext context, {double designWidth = 750}) {
    return this * (MediaQuery.of(context).size.width / designWidth);
  }
}
