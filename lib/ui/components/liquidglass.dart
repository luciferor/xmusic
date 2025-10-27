import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui' as ui;
import 'package:xmusic/controllers/blurocontroller.dart';

final boController = Get.find<BlurOpacityController>();

class LiquidGlassContainer extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;
  final double blurRadius;

  const LiquidGlassContainer({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.blurRadius,
  });

  @override
  // ignore: library_private_types_in_public_api
  _LiquidGlassContainerState createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ClipRRect(
            child: Stack(
              children: [
                // 液态玻璃背景
                _buildLiquidGlassBackground(boController),
                Positioned.fill(
                  child: Obx(() {
                    return Container(
                      color: const Color(0xFF000000).withOpacity(
                        boController.lightValue.value / 100 - 0.3 < 0.3
                            ? 0.3
                            : boController.lightValue.value / 100 - 0.3,
                      ),
                    );
                  }),
                ),
                // 内容
                Container(child: widget.child),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiquidGlassBackground(BlurOpacityController blurController) {
    return Positioned.fill(
      child: Obx(
        () => BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: blurController.blurValue.value / 10 * 2,
            sigmaY: blurController.blurValue.value / 10 * 2,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(
                    0xFF4400B3,
                  ).withOpacity(blurController.opacityValue.value / 100),
                  Colors.black.withOpacity(
                    blurController.opacityValue.value / 100,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
