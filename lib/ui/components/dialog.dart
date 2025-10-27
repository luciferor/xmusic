import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:glossy/glossy.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/rpx.dart';

class XDialog extends StatefulWidget {
  const XDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.showTitle = true,
    required this.onCancel,
    required this.onConfirm,
  });
  final String title;
  final String content;
  final bool showTitle;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  // ignore: library_private_types_in_public_api
  _XDialogState createState() => _XDialogState();
}

class _XDialogState extends State<XDialog> with TickerProviderStateMixin {
  late AnimationController enterController;
  late AnimationController exitController;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    enterController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    )..forward();

    exitController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _handleClose(VoidCallback callback) async {
    if (_isExiting) return;
    _isExiting = true;
    await exitController.forward(); // 播放退出动画
    if (mounted) Navigator.of(context).pop();
    callback();
  }

  @override
  void dispose() {
    enterController.dispose();
    exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await _handleClose(() {});
        return false;
      },
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([enterController, exitController]),
          builder: (context, child) {
            final entering = 1.0 - enterController.value;
            final exiting = exitController.value;

            // 合并动画状态（根据不同阶段选择动画）
            final slide = Offset(
              entering * 1.0 + exiting * 0.0,
              -exiting * 0.3,
            );
            final rotationY = (entering * pi / 2);
            final scale = exiting > 0
                ? 1.0 - exiting * 0.5
                : 0.8 + (enterController.value * 0.2);
            final opacity = 1.0 - exiting;

            return Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(
                    slide.dx * MediaQuery.of(context).size.width,
                    slide.dy * MediaQuery.of(context).size.height,
                  )
                  ..rotateY(rotationY)
                  ..scale(scale),
                child: child,
              ),
            );
          },
          child: _buildCommonContent(
            widget.title,
            widget.content,
            widget.showTitle,
            widget.cancelText,
            widget.confirmText,
            widget.onCancel,
            widget.onConfirm,
          ),
        ),
      ),
    );
  }

  Widget _buildCommonContent(
    String title,
    String content,
    bool showTitle,
    String cancelText,
    String confirmText,
    VoidCallback onCancel,
    VoidCallback onConfirm,
  ) {
    return GlossyContainer(
      width: 600.rpx(context),
      height: 450.rpx(context),
      strengthX: 5,
      strengthY: 5,
      gradient: GlossyLinearGradient(
        colors: [Color(0x92000000), Color(0x92000000), Color(0x92000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        opacity: 0.1,
      ),
      border: BoxBorder.all(
        color: const Color(0x4DFFFFFF),
        width: 1.rpx(context),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(0, 168, 154, 154),
          blurRadius: 30.rpx(context),
        ),
      ],
      borderRadius: BorderRadius.circular(70.rpx(context)),
      child: Container(
        padding: EdgeInsets.all(40.rpx(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 40.rpx(context)),
            if (showTitle)
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.rpx(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: 40.rpx(context)),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Color.fromARGB(255, 215, 224, 255),
                  Color.fromARGB(150, 215, 224, 255),
                  Color.fromARGB(50, 215, 224, 255),
                ], // 绿色到蓝色
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 32.rpx(context),
                ).copyWith(color: Colors.white),
              ),
            ),

            SizedBox(height: 40.rpx(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GradientButton(
                  onPressed: () => _handleClose(widget.onCancel),
                  gradientColors: [
                    Color.fromARGB(20, 255, 255, 255),
                    Color.fromARGB(20, 255, 255, 255),
                    Color.fromARGB(20, 255, 255, 255),
                  ],
                  padding: EdgeInsetsGeometry.symmetric(
                    vertical: 18.rpx(context),
                    horizontal: 80.rpx(context),
                  ),
                  borderRadius: 25.rpx(context),
                  child: Text(
                    cancelText,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 28.rpx(context),
                    ),
                  ),
                ),
                SizedBox(width: 40.rpx(context)),
                GradientButton(
                  onPressed: () => _handleClose(onConfirm),
                  gradientColors: [
                    Color.fromARGB(155, 28, 62, 255),
                    Color.fromARGB(155, 28, 62, 255),
                    Color.fromARGB(155, 28, 62, 255),
                  ],
                  padding: EdgeInsetsGeometry.symmetric(
                    vertical: 18.rpx(context),
                    horizontal: 80.rpx(context),
                  ),
                  borderRadius: 25.rpx(context),
                  child: Text(
                    confirmText,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 28.rpx(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
