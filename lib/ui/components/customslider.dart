import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/rpx.dart';

// ignore: unused_element
class GradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Gradient gradient;
  final bool showText;
  final bool enabled; // 新增属性
  const GradientSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.gradient,
    this.min = 0,
    this.max = 100,
    this.showText = false,
    this.onChangeEnd,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10.rpx(context),
              thumbShape: RectangularSliderThumbShape(
                width: 20.rpx(context),
                height: 30.rpx(context),
              ),
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: _GradientTrackShape(gradient: gradient),
              inactiveTrackColor: Colors.white24,
              activeTrackColor: Colors.transparent,
              thumbColor: const Color.fromARGB(137, 73, 85, 255),
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        if (showText)
          SizedBox(
            width: 100.rpx(context),
            child: GradientText(
              '${((value - min) / (max - min) * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 24.rpx(context)),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2379FF),
                  Color(0xFF1EFBE9),
                  Color(0xFFA2FF7C),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GradientTrackShape extends SliderTrackShape {
  final Gradient gradient;
  const _GradientTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackLeft = offset.dx + 16;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - 32;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    Offset? secondaryOffset,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final Paint paint = Paint()..shader = gradient.createShader(trackRect);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(4)),
      paint,
    );
  }
}

class RectangularSliderThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  const RectangularSliderThumbShape({this.width = 24, this.height = 12});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final paint = Paint()..color = sliderTheme.thumbColor ?? Colors.white;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(3)),
      paint,
    );
  }
}
