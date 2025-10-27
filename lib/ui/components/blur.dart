import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/rpx.dart';

// ignore: must_be_immutable
class Blur extends StatelessWidget {
  Blur({
    super.key,
    this.child,
    this.radius,
    this.blur,
    this.opacity,
    this.width,
    this.height,
    this.padding,
    this.borderWidth = 1.0,
    this.borderColor,
  });
  final Widget? child;
  BorderRadiusGeometry? radius = BorderRadius.zero;
  double? blur = 0;
  double? opacity = 0.5;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double borderWidth;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            color: const Color(0x91000000),
            borderRadius: radius,
          ),
          child: renderRRect(
            context,
            radius!,
            blur!,
            opacity!,
            borderWidth,
            borderColor,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
          color: const Color(0x00000000),
          width: width,
          height: height,
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

Widget renderRRect(
  BuildContext context,
  BorderRadiusGeometry radius,
  double blur,
  double opacity,
  double borderWidth,
  Color? borderColor,
) {
  return ClipRRect(
    borderRadius: radius,
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: blur.rpx(context),
        sigmaY: blur.rpx(context),
      ),
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x00000000),
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white10,
              width: borderWidth,
            ),
          ),
        ),
      ),
    ),
  );
}
