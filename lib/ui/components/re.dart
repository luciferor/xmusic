import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:glossy/glossy.dart';
import 'package:xmusic/ui/components/rpx.dart';

class Re extends StatefulWidget {
  const Re({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ReState createState() => _ReState();
}

class _ReState extends State<Re> {
  @override
  Widget build(BuildContext context) {
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: GlossyContainer(
        width: 70.rpx(context),
        height: 70.rpx(context),
        strengthX: 10,
        strengthY: 10,
        gradient: GlossyLinearGradient(
          colors: [
            Color.fromARGB(0, 241, 255, 255),
            Color.fromARGB(0, 214, 255, 252),
            Color.fromARGB(0, 231, 255, 251),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          opacity: 0.0,
        ),
        border: BoxBorder.all(
          color: const Color.fromARGB(50, 255, 255, 255),
          width: 5.rpx(context),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(0, 168, 154, 154),
            blurRadius: 30.rpx(context),
          ),
        ],
        borderRadius: BorderRadius.circular(30.rpx(context)),
        child: Container(
          width: 70.rpx(context),
          height: 70.rpx(context),
          padding: EdgeInsets.all(5.rpx(context)),
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.chevron_back,
            size: 50.rpx(context),
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}
