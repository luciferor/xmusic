import 'package:flutter/material.dart';

class CircularCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const CircularCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: value ? Colors.blue : Colors.grey,
            width: 2.0,
          ),
          color: value ? Colors.blue : Colors.transparent,
        ),
        child: value
            ? Center(
                child: Icon(Icons.check, size: size * 0.6, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final List<Color> gradientColors;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.gradientColors,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent, // 背景透明，便于显示渐变
        shadowColor: Colors.transparent, // 可选：去掉阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      onPressed: onPressed,
      child: Ink(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Container(
          padding: padding,
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
    );
  }
}
