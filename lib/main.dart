import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmusic/app.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/services/cover_controller.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/services/favorite_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化友盟统计
  try {
    UmengCommonSdk.initCommon(
      '68a32839e563686f42815da9',
      '68a32405e563686f42815b0c',
      'official',
    );
  } catch (e) {
    print('_+++++++++++++++++++++++++++++++友盟初始化失败:$e');
  }

  final session = await AudioSession.instance;
  session.configure(AudioSessionConfiguration.music());
  // 初始化Hive
  await Hive.initFlutter();

  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarColor: Color(0x00FFFFFF),
        systemNavigationBarColor: Color(0x00EFF2F7),
      ),
    );
  } else if (Platform.isIOS) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark, // 改为light，状态栏文字为白色
        statusBarIconBrightness: Brightness.light, //状态栏图标为白色
        statusBarColor: Colors.transparent,
      ),
    );
  }
  // await _initUmengIfConfigured();

  Get.put(AliyunDriveService(), permanent: true);
  Get.put(PlayerUIController(), permanent: true);
  Get.put(FavoriteService(), permanent: true);

  // 初始化背景图片控制器
  Get.put(BackgroundController(), permanent: true);
  Get.put(BlurOpacityController(), permanent: true);
  Get.put(CoverController(), permanent: true);
  Get.put(PlaylistService(), permanent: true);

  debugPrintGestureArenaDiagnostics = false;

  runZonedGuarded(
    () async {
      // ...你的初始化代码...
      runApp(const App());
    },
    (error, stack) {
      if (kDebugMode) {
        print('全局异常: $error\n$stack');
      }
    },
  );
  // runApp(const App());
}
