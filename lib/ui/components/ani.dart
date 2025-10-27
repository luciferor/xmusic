// ignore_for_file: must_be_immutable
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class Ani extends StatelessWidget {
  Ani({super.key, this.child, required this.pages, this.radius});

  final Widget? child;
  final StatefulWidget pages;
  double? radius = 0;
  @override
  Widget build(BuildContext context) {
    double dp = MediaQuery.of(context).size.width / 750;
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (BuildContext context, VoidCallback _) {
        return pages;
      },
      closedElevation: 0.0,
      openElevation: 4.0,
      closedShape: RoundedRectangleBorder(
        side: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(radius! * dp)),
      ),
      closedColor: const Color(0x00000000),
      openColor: const Color(0x00000000),
      middleColor: const Color(0x00000000),
      closedBuilder: (BuildContext context, VoidCallback openContainer) {
        return child as Widget;
      },
    );
  }
}
