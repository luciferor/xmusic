import 'dart:io';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Appinfo extends StatefulWidget {
  const Appinfo({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AppinfoState createState() => _AppinfoState();
}

class _AppinfoState extends State<Appinfo> {
  String? currentIcon;
  bool? support;

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _init();
    _initPackinfo();
  }

  Future<void> _init() async {
    final isSupported = await FlutterDynamicIcon.supportsAlternateIcons;
    final iconName = await FlutterDynamicIcon.getAlternateIconName();
    setState(() {
      support = isSupported;
      currentIcon = iconName;
    });
  }

  Future<void> _initPackinfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Column(
        children: [
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),
            child: Row(
              children: [
                Re(),
                Expanded(child: Container(color: Colors.transparent)),
              ],
            ),
          ),
          SizedBox(height: 40.rpx(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (Platform.isIOS)
                  Hero(
                    tag: 'hero-avator',
                    flightShuttleBuilder:
                        (
                          context,
                          animation,
                          direction,
                          fromContext,
                          toContext,
                        ) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              800.rpx(context),
                            ),
                            child: toContext.widget,
                          );
                        },
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(
                        (currentIcon != null && currentIcon!.isNotEmpty)
                            ? 'assets/images/$currentIcon.png'
                            : 'assets/images/logo.png',
                      ),
                      radius: 120.rpx(context),
                    ),
                  ),

                if (Platform.isAndroid || Platform.isWindows)
                  Hero(
                    tag: 'hero-avator',
                    flightShuttleBuilder:
                        (
                          context,
                          animation,
                          direction,
                          fromContext,
                          toContext,
                        ) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              800.rpx(context),
                            ),
                            child: toContext.widget,
                          );
                        },
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                      radius: 120.rpx(context),
                    ),
                  ),
                SizedBox(height: 100.rpx(context)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GradientText(
                      '荧惑音乐',
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFA2FF7C),
                          Color(0xFF1EFBE9),
                          Color(0xFF2379FF),
                        ], // 绿色到蓝色
                      ),
                      style: TextStyle(
                        fontSize: 36.rpx(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.rpx(context)),
                    GradientText(
                      "VERSION${_packageInfo.version}",
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(50, 255, 255, 255),
                          Color.fromARGB(100, 255, 255, 255),
                          Color.fromARGB(255, 255, 255, 255),
                        ], // 绿色到蓝色
                      ),
                      style: TextStyle(fontSize: 24.rpx(context)),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    GradientText(
                      '打造永远不用续费的音乐播放软件',
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, 255, 255, 255),
                          Color.fromARGB(100, 255, 255, 255),
                          Color.fromARGB(50, 255, 255, 255),
                        ], // 绿色到蓝色
                      ),
                      style: TextStyle(fontSize: 24.rpx(context)),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    GradientText(
                      '邮箱：root@dsnbc.com',
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(50, 255, 255, 255),
                          Color.fromARGB(100, 255, 255, 255),
                          Color.fromARGB(255, 255, 255, 255),
                        ], // 绿色到蓝色
                      ),
                      style: TextStyle(fontSize: 24.rpx(context)),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    Container(
                      clipBehavior: Clip.hardEdge,
                      width: 350.rpx(context),
                      height: 350.rpx(context),
                      padding: EdgeInsets.all(10.rpx(context)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60.rpx(context)),
                      ),
                      child: Image.asset(
                        'assets/images/20250805175355.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    GradientText(
                      '扫一扫加QQ交流群',
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, 255, 255, 255),
                          Color.fromARGB(100, 255, 255, 255),
                          Color.fromARGB(50, 255, 255, 255),
                        ], // 绿色到蓝色
                      ),
                      style: TextStyle(fontSize: 24.rpx(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Copyright(),
        ],
      ),
    );
  }
}
