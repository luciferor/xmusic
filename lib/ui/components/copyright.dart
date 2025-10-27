import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/rpx.dart';

class Copyright extends StatelessWidget {
  const Copyright({super.key});

  @override
  Widget build(BuildContext context) {
    String yeal = DateTime.now().year.toString();
    return Center(
      child: GradientText(
        '©Copyright.all Rights Resive.$yeal.荧惑音乐.',
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(20, 215, 224, 255),
            Color.fromARGB(100, 215, 224, 255),
            Color.fromARGB(200, 215, 224, 255),
          ], // 绿色到蓝色
        ),
        style: TextStyle(fontSize: 20.rpx(context)),
      ),
      // Text(
      //   '©Copyright.all Rights Resive.$yeal.荧惑音乐.',
      //   style: TextStyle(color: Colors.white38, fontSize: 24.rpx(context)),
      // ),
    );
  }
}
