import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/rpx.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final bool isOver = true;

  const GradientText(
    this.text, {
    required this.gradient,
    required this.style,
    isOver,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style.copyWith(
          color: Colors.white,
          // shadows: [
          //   Shadow(
          //     blurRadius: 10.rpx(context),
          //     color: Colors.black54,
          //     offset: Offset(0, 0),
          //   ),
          //   Shadow(
          //     blurRadius: 20.rpx(context),
          //     color: Colors.black87,
          //     offset: Offset(0, 0),
          //   ),
          // ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
