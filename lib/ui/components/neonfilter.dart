import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xmusic/controllers/blurocontroller.dart';

class NeonFilter extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final BlendMode blendMode;

  const NeonFilter({
    super.key,
    required this.child,
    this.colors = const [Colors.orange, Colors.green, Colors.blue],
    this.blendMode = BlendMode.color,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<BlurOpacityController>();
    return Obx(() {
      if (!ctrl.isNeoned.value) return child;
      return ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        blendMode: blendMode,
        child: child,
      );
    });
  }
}
