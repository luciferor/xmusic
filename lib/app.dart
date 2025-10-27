import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:xmusic/ui/components/player/widget.dart';
import 'package:xmusic/ui/pages/appinfo.dart';
import 'package:xmusic/ui/pages/cachesmusic.dart';
import 'package:xmusic/ui/pages/catchs.dart';
import 'package:xmusic/ui/pages/dynamicon.dart';
import 'package:xmusic/ui/pages/favorites.dart';
import 'package:xmusic/ui/pages/help.dart';
import 'package:xmusic/ui/pages/index.dart';
import 'package:xmusic/ui/pages/listen_ing.dart';
import 'package:xmusic/ui/pages/login.dart';
import 'package:xmusic/ui/pages/mine.dart';
import 'package:xmusic/ui/pages/mz.dart';
import 'package:xmusic/ui/pages/player.dart';
import 'package:xmusic/ui/pages/sliblist.dart';
import 'package:xmusic/ui/pages/songlib.dart';
import 'package:xmusic/ui/pages/users.dart';

// 全局路由观察者
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ignore: must_be_immutable
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: '荧惑音乐',
      theme: ThemeData.light().copyWith(
        platform: TargetPlatform.iOS,
        scaffoldBackgroundColor: const Color(0xFFEFF2F7),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => PageWithPlayer(child: Index()),
        '/login': (context) => const Login(),
        '/mine': (context) => const Mine(),
        '/player': (context) => const Player(),
        '/dynamicon': (context) => const Dynamicon(),
        '/setting': (context) => const Dynamicon(),
        '/catchs': (context) => const Catchs(),
        '/appinfo': (context) => const Appinfo(),
        '/help': (context) => const Help(),
        '/mz': (context) => const Mz(),
        '/favorites': (context) => PageWithPlayer(child: Favorites()),
        '/songslib': (context) => PageWithPlayer(child: Songlib()),
        '/songlist': (context) => PageWithPlayer(child: Sliblist()),
        '/cachemusic': (context) => const Cachesmusic(),
        '/users': (context) => const Users(),
        '/listening': (context) => const ListenIng(),
      },
      builder: (context, child) {
        return FlutterSmartDialog(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          ),
        );
      },
      navigatorObservers: [FlutterSmartDialog.observer, routeObserver],
    );
  }
}
