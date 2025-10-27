import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/player/mini_player.dart';

class PageWithPlayer extends StatelessWidget {
  final Widget child;

  const PageWithPlayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
        ],
      ),
    );
  }
}
