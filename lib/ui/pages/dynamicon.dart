import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:xmusic/controllers/blurocontroller.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/customslider.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final boController = Get.find<BlurOpacityController>();

class Dynamicon extends StatefulWidget {
  const Dynamicon({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DynamiconState createState() => _DynamiconState();
}

class _DynamiconState extends State<Dynamicon> {
  // 图标配置
  final List<_IconInfo> icons = [
    _IconInfo('x', null, 'assets/images/logo.png'),
    _IconInfo('x', 'azora', 'assets/images/azora.png'),
    _IconInfo('x', 'adiohead', 'assets/images/adiohead.png'),
    _IconInfo('x', 'bqb', 'assets/images/bqb.png'),
    _IconInfo('x', 'dzq', 'assets/images/dzq.png'),
    _IconInfo('x', 'jay', 'assets/images/jay.png'),
    _IconInfo('x', 'xzq', 'assets/images/xzq.png'),
    _IconInfo('x', 'guns', 'assets/images/guns.png'),
    _IconInfo('x', 'jea', 'assets/images/jea.png'),
    _IconInfo('x', 'pat', 'assets/images/pat.png'),
    _IconInfo('x', 'peter', 'assets/images/peter.png'),
    _IconInfo('x', 'queen', 'assets/images/queen.png'),
    _IconInfo('x', 'the', 'assets/images/the.png'),
    _IconInfo('x', 'voodoo', 'assets/images/voodoo.png'),
    _IconInfo('x', 'x', 'assets/images/x.png'),
  ];

  String? currentIcon;
  bool? support;

  double blurValue = 50;
  double opacityValue = 50;
  double lightValue = 50;
  double sexiangValue = 0;
  double baoheduValue = 0;

  //全局
  double brightness = 1.0; // 亮度调整 (0 到 2, 1为正常)
  double contrast = 1.0; // 对比度调整 (0 到 2, 1为正常)
  double saturation = 1.0; // 饱和度调整 (0 到 2, 1为正常)
  double hue = 0.0; // 色相调整 (-180 到 180)
  double grayscale = 0.0; // 灰度 (0 到 1, 0为正常, 1为完全灰度)
  double vibrance = 0.0; // 自然饱和度/鲜艳度 (vibrance) (-1 到 1, 0 为正常)
  double exposure = 0.0; // 曝光 (以档为单位，-2 到 2，0 为正常)
  double temperature = 0.0; // 色温 (-1 到 1，0 为正常；>0 更暖 <0 更冷)
  double tint = 0.0; // 色调/偏色 (tint) (-1 到 1，0 为正常；>0 更偏绿 <0 更偏洋红)
  double highlights = 0.0; //高光 (-1 到 1，0 为正常)
  double shadows = 0.0; //阴影 (-1 到 1，0 为正常)
  double clarity = 0.0; //鲜明度/清晰度 (clarity) (-1 到 1，0 为正常)
  double sharpness = 0.0; //锐度 (占位，当前未实现卷积锐化) (-1 到 1，0 为正常)
  bool enabled = false; //是否启用滤镜

  // 背景图片列表
  List<String> backgroundImages = [];

  // 动态读取背景图片
  Future<void> _loadBackgroundImages() async {
    try {
      final manifestContent = await DefaultAssetBundle.of(
        context,
      ).loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      backgroundImages = manifestMap.keys
          .where((String key) => key.startsWith('assets/images/bgs/'))
          .toList();

      setState(() {});
    } catch (e) {
      print('读取背景图片失败: $e');
    }
  }

  String? selectedBackgroundImage;

  @override
  void initState() {
    super.initState();
    _init();
    _loadSelectedBackground();
    _loadBackgroundImages();
    _loadBlurValue();
  }

  Future<void> _loadBlurValue() async {
    final prefs = await SharedPreferences.getInstance();
    final b = prefs.getDouble('blurValue') ?? 0.0;
    final o = prefs.getDouble('opacityValue') ?? 0.0;
    final l = prefs.getDouble('lightValue') ?? 0.5;
    final s = prefs.getDouble('sexiangValue') ?? 0.0;
    final bhd = prefs.getDouble('baoheduValue') ?? 100.0;

    //全局
    final gb = prefs.getDouble('brightness') ?? 1.0;
    final gc = prefs.getDouble('contrast') ?? 1.0;
    final gs = prefs.getDouble('saturation') ?? 1.0;
    final gh = prefs.getDouble('hue') ?? 0.0;
    final gg = prefs.getDouble('grayscale') ?? 0.0;
    final gv = prefs.getDouble('vibrance') ?? 0.0;
    final ge = prefs.getDouble('exposure') ?? 0.0;
    final gt = prefs.getDouble('temperature') ?? 0.0;
    final gti = prefs.getDouble('tint') ?? 0.0;
    final ghi = prefs.getDouble('highlights') ?? 0.0;
    final gsh = prefs.getDouble('shadows') ?? 0.0;
    final gcl = prefs.getDouble('clarity') ?? 0.0;
    final gss = prefs.getDouble('sharpness') ?? 0.0;
    final gen = prefs.getBool('enabled') ?? false;

    boController.blurValue.value = b;
    boController.opacityValue.value = o;
    boController.lightValue.value = l;
    boController.sexiangValue.value = s;
    boController.baoheduValue.value = bhd;

    //全局
    boController.brightness.value = gb;
    boController.contrast.value = gc;
    boController.saturation.value = gs;
    boController.hue.value = gh;
    boController.grayscale.value = gg;
    boController.vibrance.value = gv;
    boController.exposure.value = ge;
    boController.temperature.value = gt;
    boController.tint.value = gti;
    boController.highlights.value = ghi;
    boController.shadows.value = gsh;
    boController.clarity.value = gcl;
    boController.sharpness.value = gss;
    boController.enabled.value = gen;

    setState(() {
      blurValue = b;
      opacityValue = o;
      lightValue = l;
      sexiangValue = s;
      baoheduValue = bhd;

      //全局
      brightness = gb;
      contrast = gc;
      saturation = gs;
      hue = gh;
      grayscale = gg;
      vibrance = gv;
      exposure = ge;
      temperature = gt;
      tint = gti;
      highlights = ghi;
      shadows = gsh;
      clarity = gcl;
      sharpness = gss;
      enabled = gen;
    }); // 你的本地变量同步
    print('🔍 dynamicon: 加载值 - blur: $b, opacity: $o');
  }

  Future<void> _init() async {
    // 只在 iOS 上使用动态图标功能
    if (Platform.isIOS) {
      try {
        final isSupported = await FlutterDynamicIcon.supportsAlternateIcons;
        final iconName = await FlutterDynamicIcon.getAlternateIconName();
        setState(() {
          support = isSupported;
          currentIcon = iconName;
        });
      } catch (e) {
        print('动态图标初始化失败: $e');
        setState(() {
          support = false;
          currentIcon = null;
        });
      }
    } else {
      // Android 和其他平台不支持
      setState(() {
        support = false;
        currentIcon = null;
      });
    }
  }

  // 加载用户选择的背景图片
  Future<void> _loadSelectedBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBackground = prefs.getString('selected_background_image');
      if (savedBackground != null) {
        setState(() {
          selectedBackgroundImage = savedBackground;
        });
      }
    } catch (e) {
      print('加载背景图片失败: $e');
    }
  }

  // 保存用户选择的背景图片
  Future<void> _saveSelectedBackground(String imagePath) async {
    try {
      // 使用BackgroundController更新背景图片
      if (Get.isRegistered<BackgroundController>()) {
        final backgroundController = Get.find<BackgroundController>();
        await backgroundController.updateBackgroundImage(imagePath);
      } else {
        // 如果BackgroundController未注册，使用传统方式
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_background_image', imagePath);
      }

      setState(() {
        selectedBackgroundImage = imagePath;
      });
    } catch (e) {
      print('保存背景图片失败: $e');
    }
  }

  Future<void> _setIcon(String? iconName) async {
    // 只在 iOS 上支持动态图标
    if (!Platform.isIOS) {
      Fluttertoast.showToast(
        msg: '当前平台不支持动态图标',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
      return;
    }

    try {
      print('🔄 开始切换图标: ${iconName ?? "默认"}');

      // 添加延迟，避免频繁切换
      await Future.delayed(Duration(milliseconds: 500));

      await FlutterDynamicIcon.setAlternateIconName(iconName);

      setState(() {
        currentIcon = iconName;
      });

      print('✅ 图标切换成功: ${iconName ?? "默认"}');
      Fluttertoast.showToast(
        msg: '切换成功: ${iconName ?? "默认"}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    } catch (e) {
      print('❌ 图标切换失败: $e');

      // 检查是否是权限相关错误
      String errorMessage = '切换失败';
      if (e.toString().contains('NSOSStatusErrorDomain') ||
          e.toString().contains('permission was denied')) {
        errorMessage = '权限不足，请检查系统设置';
      } else if (e.toString().contains('LaunchServices')) {
        errorMessage = '系统服务错误，请重试';
      } else {
        errorMessage = '切换失败: $e';
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            width: double.infinity,
            height: 80.rpx(context),
            padding: EdgeInsets.only(left: 40.rpx(context)),
            child: Re(),
          ),
          SizedBox(height: 40.rpx(context)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 20.rpx(context)),

                  //模块分割线----------------------------------------------------------------
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      40.rpx(context),
                      0.rpx(context),
                      40.rpx(context),
                      20.rpx(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.fromLTRB(
                            0.rpx(context),
                            0.rpx(context),
                            0.rpx(context),
                            10.rpx(context),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.timelapse,
                                      color: Color.fromARGB(46, 255, 255, 255),
                                      size: 40.rpx(context),
                                    ),
                                    SizedBox(width: 10.rpx(context)),
                                    GradientText(
                                      '全局滤镜',
                                      style: TextStyle(
                                        fontSize: 30.rpx(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(46, 255, 255, 255),
                                          Color.fromARGB(141, 255, 255, 255),
                                          Color.fromARGB(255, 255, 255, 255),
                                        ],
                                      ), // 绿色到蓝色
                                    ),
                                  ],
                                ),
                              ),
                              //启用关闭。
                              Obx(
                                () => GestureDetector(
                                  onTap: () {
                                    boController.setEnabled(
                                      !boController.enabled.value,
                                    );
                                  },
                                  child: Container(
                                    width: 80.rpx(context),
                                    height: 40.rpx(context),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0x01C8E0FF),
                                          Color(0x31C8E0FF),
                                          Color(0xD0C8E0FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        20.rpx(context),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 20.rpx(context),
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        AnimatedPositioned(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          left: boController.enabled.value
                                              ? 42.rpx(context)
                                              : 2.rpx(context),
                                          top: 2.rpx(context),
                                          child: Container(
                                            width: 36.rpx(context),
                                            height: 36.rpx(context),
                                            decoration: BoxDecoration(
                                              color: boController.isNeoned.value
                                                  ? const Color(0xFF434DFF)
                                                  : Colors.white38,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    20.rpx(context),
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 10.rpx(context),
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.rpx(context),
                          indent: 50.rpx(context),
                          endIndent: 0.rpx(context),
                        ),
                        SizedBox(height: 40.rpx(context)),
                        Container(
                          padding: EdgeInsets.only(left: 30.rpx(context)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '亮度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: brightness,
                                      min: 0.0,
                                      max: 2.0,
                                      onChanged: (v) {
                                        boController.brightness.value = v;
                                        setState(() => brightness = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('brightness', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(0, 236, 247, 255),
                                          Color.fromARGB(100, 218, 234, 250),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    brightness.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),

                              SizedBox(height: 30.rpx(context)),

                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '对比度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: contrast,
                                      min: 0.0,
                                      max: 2.0,
                                      onChanged: (v) {
                                        boController.contrast.value = v;
                                        setState(() => contrast = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('contrast', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(0, 236, 247, 255),
                                          Color.fromARGB(100, 218, 234, 250),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    contrast.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '饱和度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: saturation,
                                      min: 0.0,
                                      max: 2.0,
                                      onChanged: (v) {
                                        boController.saturation.value = v;
                                        setState(() => saturation = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('saturation', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(0, 236, 247, 255),
                                          Color.fromARGB(100, 218, 234, 250),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    saturation.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '色相',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: hue,
                                      min: -180.0,
                                      max: 180.0,
                                      onChanged: (v) {
                                        boController.hue.value = v;
                                        setState(() => hue = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('hue', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    hue.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '灰度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: grayscale,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.grayscale.value = v;
                                        setState(() => grayscale = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('grayscale', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    grayscale.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '鲜艳度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: vibrance,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.vibrance.value = v;
                                        setState(() => vibrance = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('vibrance', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    vibrance.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '曝光',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: exposure,
                                      min: -2.0,
                                      max: 2.0,
                                      onChanged: (v) {
                                        boController.exposure.value = v;
                                        setState(() => exposure = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('exposure', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    exposure.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '色温',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: temperature,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.temperature.value = v;
                                        setState(() => temperature = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('temperature', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    temperature.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '色调',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: tint,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.tint.value = v;
                                        setState(() => tint = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('tint', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    tint.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '高光',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: highlights,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.highlights.value = v;
                                        setState(() => highlights = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('highlights', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    highlights.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '阴影',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: shadows,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.shadows.value = v;
                                        setState(() => shadows = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('shadows', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    shadows.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '鲜明度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: clarity,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.clarity.value = v;
                                        setState(() => clarity = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('clarity', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    clarity.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                              Row(
                                children: [
                                  Container(
                                    alignment: Alignment.centerRight,
                                    width: 100.rpx(context),
                                    child: Text(
                                      '锐度',
                                      style: TextStyle(
                                        fontSize: 24.rpx(context),
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: GradientSlider(
                                      showText: false,
                                      value: sharpness,
                                      min: -1.0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        boController.sharpness.value = v;
                                        setState(() => sharpness = v);
                                      },
                                      onChangeEnd: (v) async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setDouble('sharpness', v);
                                      },
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00ECF7FF),
                                          Color(0x63DAEAFA),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    sharpness.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30.rpx(context)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  //模块分割线----------------------------------------------------------------
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
                    margin: EdgeInsets.only(bottom: 10.rpx(context)),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.photo,
                          color: Color.fromARGB(98, 255, 255, 255),
                          size: 40.rpx(context),
                        ),
                        SizedBox(width: 10.rpx(context)),
                        GradientText(
                          '背景图片',
                          style: TextStyle(
                            fontSize: 30.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color.fromARGB(98, 255, 255, 255),
                              Color.fromARGB(141, 255, 255, 255),
                              Color.fromARGB(255, 255, 255, 255),
                            ],
                          ), // 绿色到蓝色
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.white12,
                    height: 1.rpx(context),
                    indent: 90.rpx(context),
                    endIndent: 40.rpx(context),
                  ),
                  SizedBox(height: 40.rpx(context)),
                  // 背景图片选择区域
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      40.rpx(context),
                      0,
                      40.rpx(context),
                      40.rpx(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 背景图片网格
                        Container(
                          padding: EdgeInsets.only(left: 50.rpx(context)),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 20.rpx(context),
                                  mainAxisSpacing: 20.rpx(context),
                                  childAspectRatio: 1.5,
                                ),
                            itemCount: backgroundImages.length,
                            itemBuilder: (context, index) {
                              final imagePath = backgroundImages[index];
                              final isSelected =
                                  selectedBackgroundImage == imagePath;

                              return Bounceable(
                                onTap: () {
                                  // 添加点击反馈
                                  HapticFeedback.lightImpact();
                                  _saveSelectedBackground(imagePath);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      30.rpx(context),
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xA32332FF)
                                          : Colors.white24,
                                      width: 3.rpx(context),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF6338FF,
                                                // ignore: deprecated_member_use
                                              ).withAlpha((0.8 * 255).round()),
                                              blurRadius: 30.rpx(context),
                                              spreadRadius: 10.rpx(context),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Opacity(
                                    opacity: isSelected ? 1 : 0.8,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        28.rpx(context),
                                      ),
                                      child: Stack(
                                        children: [
                                          NeonFilter(
                                            colors: [
                                              Colors.pink,
                                              Colors.cyan,
                                              Colors.blue,
                                            ],
                                            blendMode: BlendMode.color,
                                            child: Image.asset(
                                              imagePath,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 5.rpx(context),
                                              right: 5.rpx(context),
                                              child: Container(
                                                padding: EdgeInsets.all(
                                                  3.rpx(context),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF1100FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10.rpx(context),
                                                      ),
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.checkmark_alt,
                                                  color: Color(0xFF93FAAD),
                                                  size: 30.rpx(context),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
                    margin: EdgeInsets.only(bottom: 10.rpx(context)),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.gamecontroller,
                          color: Color.fromARGB(98, 255, 255, 255),
                          size: 40.rpx(context),
                        ),
                        SizedBox(width: 10.rpx(context)),
                        GradientText(
                          '模糊/透明度',
                          style: TextStyle(
                            fontSize: 30.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color.fromARGB(98, 255, 255, 255),
                              Color.fromARGB(141, 255, 255, 255),
                              Color.fromARGB(255, 255, 255, 255),
                            ],
                          ), // 绿色到蓝色
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.white12,
                    height: 1.rpx(context),
                    indent: 90.rpx(context),
                    endIndent: 40.rpx(context),
                  ),
                  SizedBox(height: 40.rpx(context)),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      65.rpx(context),
                      0,
                      10.rpx(context),
                      40.rpx(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.centerRight,
                              width: 100.rpx(context),
                              child: Text(
                                '透明度',
                                style: TextStyle(
                                  fontSize: 24.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GradientSlider(
                                showText: true,
                                value: opacityValue,
                                onChanged: (v) {
                                  boController.opacityValue.value = v;
                                  setState(() => opacityValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble('opacityValue', v);
                                },
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(0, 236, 247, 255),
                                    Color.fromARGB(100, 218, 234, 250),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.rpx(context)),
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.centerRight,
                              width: 100.rpx(context),
                              child: Text(
                                '模糊度',
                                style: TextStyle(
                                  fontSize: 24.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GradientSlider(
                                showText: true,
                                value: blurValue,
                                onChanged: (v) {
                                  boController.blurValue.value = v;
                                  setState(() => blurValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble('blurValue', v);
                                },
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(0, 63, 107, 253),
                                    Color.fromARGB(202, 47, 50, 255),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.rpx(context)),
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.centerRight,
                              width: 100.rpx(context),
                              child: Text(
                                '明暗度',
                                style: TextStyle(
                                  fontSize: 24.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GradientSlider(
                                showText: true,
                                value: lightValue,
                                onChanged: (v) {
                                  boController.lightValue.value = v;
                                  setState(() => lightValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble('lightValue', v);
                                },
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(0, 255, 255, 255),
                                    Color.fromARGB(50, 255, 255, 255),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.rpx(context)),
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.centerRight,
                              width: 100.rpx(context),
                              child: Text(
                                '色相',
                                style: TextStyle(
                                  fontSize: 24.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GradientSlider(
                                showText: true,
                                value: sexiangValue,
                                onChanged: (v) {
                                  boController.sexiangValue.value = v;
                                  setState(() => sexiangValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble('sexiangValue', v);
                                },
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(0, 255, 255, 255),
                                    Color.fromARGB(50, 255, 255, 255),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.rpx(context)),
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.centerRight,
                              width: 100.rpx(context),
                              child: Text(
                                '饱和度',
                                style: TextStyle(
                                  fontSize: 24.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GradientSlider(
                                showText: true,
                                value: baoheduValue,
                                onChanged: (v) {
                                  boController.baoheduValue.value = v;
                                  setState(() => baoheduValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble('baoheduValue', v);
                                },
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(0, 255, 255, 255),
                                    Color.fromARGB(50, 255, 255, 255),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  //模块分割线----------------------------------------------------------------
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      40.rpx(context),
                      0.rpx(context),
                      40.rpx(context),
                      20.rpx(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.fromLTRB(
                            0.rpx(context),
                            0.rpx(context),
                            0.rpx(context),
                            10.rpx(context),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.circle_grid_hex,
                                      color: Color.fromARGB(46, 255, 255, 255),
                                      size: 40.rpx(context),
                                    ),
                                    SizedBox(width: 10.rpx(context)),
                                    GradientText(
                                      '图片滤镜',
                                      style: TextStyle(
                                        fontSize: 30.rpx(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(46, 255, 255, 255),
                                          Color.fromARGB(141, 255, 255, 255),
                                          Color.fromARGB(255, 255, 255, 255),
                                        ],
                                      ), // 绿色到蓝色
                                    ),
                                  ],
                                ),
                              ),
                              //启用关闭。
                              Obx(
                                () => GestureDetector(
                                  onTap: () {
                                    boController.toggleNeoned(
                                      !boController.isNeoned.value,
                                    );
                                  },
                                  child: Container(
                                    width: 80.rpx(context),
                                    height: 40.rpx(context),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0x01C8E0FF),
                                          Color(0x31C8E0FF),
                                          Color(0xD0C8E0FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        20.rpx(context),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 20.rpx(context),
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        AnimatedPositioned(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          left: boController.isNeoned.value
                                              ? 42.rpx(context)
                                              : 2.rpx(context),
                                          top: 2.rpx(context),
                                          child: Container(
                                            width: 36.rpx(context),
                                            height: 36.rpx(context),
                                            decoration: BoxDecoration(
                                              color: boController.isNeoned.value
                                                  ? const Color(0xFF434DFF)
                                                  : Colors.white38,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    20.rpx(context),
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 10.rpx(context),
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.rpx(context),
                          indent: 50.rpx(context),
                          endIndent: 0.rpx(context),
                        ),
                        SizedBox(height: 40.rpx(context)),
                      ],
                    ),
                  ),

                  //模块分割线----------------------------------------------------------------
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      40.rpx(context),
                      0.rpx(context),
                      40.rpx(context),
                      20.rpx(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.fromLTRB(
                            0.rpx(context),
                            0.rpx(context),
                            0.rpx(context),
                            10.rpx(context),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.text_alignleft,
                                      color: Color.fromARGB(46, 255, 255, 255),
                                      size: 40.rpx(context),
                                    ),
                                    SizedBox(width: 10.rpx(context)),
                                    GradientText(
                                      '网络歌词',
                                      style: TextStyle(
                                        fontSize: 30.rpx(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(46, 255, 255, 255),
                                          Color.fromARGB(141, 255, 255, 255),
                                          Color.fromARGB(255, 255, 255, 255),
                                        ],
                                      ), // 绿色到蓝色
                                    ),
                                  ],
                                ),
                              ),
                              //启用关闭。
                              Obx(
                                () => GestureDetector(
                                  onTap: () {
                                    boController.toggleEnabled(
                                      !boController.isEnabled.value,
                                    );
                                  },
                                  child: Container(
                                    width: 80.rpx(context),
                                    height: 40.rpx(context),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0x01C8E0FF),
                                          Color(0x31C8E0FF),
                                          Color(0xD0C8E0FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        20.rpx(context),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 20.rpx(context),
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        AnimatedPositioned(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          left: boController.isEnabled.value
                                              ? 42.rpx(context)
                                              : 2.rpx(context),
                                          top: 2.rpx(context),
                                          child: Container(
                                            width: 36.rpx(context),
                                            height: 36.rpx(context),
                                            decoration: BoxDecoration(
                                              color:
                                                  boController.isEnabled.value
                                                  ? const Color(0xFF434DFF)
                                                  : Colors.white38,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    20.rpx(context),
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 10.rpx(context),
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.rpx(context),
                          indent: 50.rpx(context),
                          endIndent: 0.rpx(context),
                        ),
                        SizedBox(height: 40.rpx(context)),
                      ],
                    ),
                  ),

                  //模块分割线----------------------------------------------------------------
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      40.rpx(context),
                      0.rpx(context),
                      40.rpx(context),
                      20.rpx(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.fromLTRB(
                            0.rpx(context),
                            0.rpx(context),
                            0.rpx(context),
                            10.rpx(context),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.layers_alt,
                                      color: Color.fromARGB(48, 255, 255, 255),
                                      size: 40.rpx(context),
                                    ),
                                    SizedBox(width: 10.rpx(context)),
                                    GradientText(
                                      '图标',
                                      style: TextStyle(
                                        fontSize: 30.rpx(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(48, 255, 255, 255),
                                          Color.fromARGB(141, 255, 255, 255),
                                          Color.fromARGB(255, 255, 255, 255),
                                        ],
                                      ), // 绿色到蓝色
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.rpx(context),
                          indent: 50.rpx(context),
                          endIndent: 0.rpx(context),
                        ),
                        SizedBox(height: 40.rpx(context)),
                        if (support == false)
                          Text(
                            '当前平台不支持动态图标',
                            style: TextStyle(
                              color: const Color(0xFF514EFF),
                              fontSize: 28.rpx(context),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        if (support != false)
                          Container(
                            margin: EdgeInsets.only(left: 40.rpx(context)),
                            child: GridView.count(
                              crossAxisCount: 5,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 5.rpx(context),
                              crossAxisSpacing: 5.rpx(context),
                              children: icons.map((icon) {
                                return Bounceable(
                                  onTap: () {
                                    // 添加点击反馈
                                    HapticFeedback.lightImpact();
                                    _setIcon(icon.iconName);
                                  },
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(5.rpx(context)),
                                        width: 100.rpx(context),
                                        height: 100.rpx(context),
                                        margin: EdgeInsets.only(
                                          right: 0,
                                        ), // GridView自动分列
                                        decoration: BoxDecoration(
                                          color:
                                              (currentIcon == icon.iconName ||
                                                  (icon.iconName == null &&
                                                      currentIcon == null))
                                              ? Colors.white
                                              : Colors.white10,
                                          border: Border.all(
                                            color:
                                                (currentIcon == icon.iconName ||
                                                    (icon.iconName == null &&
                                                        currentIcon == null))
                                                ? const Color(0xFF4F1EFF)
                                                : const Color.fromARGB(
                                                    0,
                                                    0,
                                                    12,
                                                    182,
                                                  ),
                                            width: 5.rpx(context),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30.rpx(context),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            30.rpx(context),
                                          ),
                                          child: Opacity(
                                            opacity:
                                                (currentIcon == icon.iconName ||
                                                    (icon.iconName == null &&
                                                        currentIcon == null))
                                                ? 1
                                                : 0.9,
                                            child: NeonFilter(
                                              colors: [
                                                Colors.pink,
                                                Colors.cyan,
                                                Colors.blue,
                                              ],
                                              blendMode: BlendMode.color,
                                              child: Image.asset(
                                                icon.asset,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (support != false)
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.fromLTRB(
                        90.rpx(context),
                        0.rpx(context),
                        0.rpx(context),
                        40.rpx(context),
                      ),
                      width: double.infinity,
                      child: GradientText(
                        'iOS支持主图标切换\nAndroid仅支持添加快捷方式（不会改变主图标）',
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(120, 215, 224, 255),
                            Color.fromARGB(180, 215, 224, 255),
                            Color.fromARGB(255, 215, 224, 255),
                          ], // 绿色到蓝色
                        ),
                        style: TextStyle(fontSize: 24.rpx(context)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Copyright(),
        ],
      ),
    );
  }
}

class _IconInfo {
  final String label;
  final String? iconName;
  final String asset;
  const _IconInfo(this.label, this.iconName, this.asset);
}

// class _GradientSlider extends StatelessWidget {
//   final double value;
//   final ValueChanged<double> onChanged;
//   final ValueChanged<double>? onChangeEnd;
//   final Gradient gradient;
//   const _GradientSlider({
//     required this.value,
//     required this.onChanged,
//     required this.gradient,
//     this.onChangeEnd,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: SliderTheme(
//             data: SliderTheme.of(context).copyWith(
//               trackHeight: 10.rpx(context),
//               thumbShape: RectangularSliderThumbShape(
//                 width: 20.rpx(context),
//                 height: 30.rpx(context),
//               ), // 用矩形滑块
//               overlayShape: SliderComponentShape.noOverlay,
//               trackShape: _GradientTrackShape(gradient: gradient),
//               inactiveTrackColor: Colors.white24,
//               activeTrackColor: Colors.transparent,
//               thumbColor: const Color.fromARGB(137, 73, 85, 255),
//             ),
//             child: Slider(
//               min: 0,
//               max: 100,
//               value: value,
//               onChanged: onChanged,
//               onChangeEnd: onChangeEnd,
//             ),
//           ),
//         ),
//         SizedBox(
//           width: 100.rpx(context),
//           child: GradientText(
//             '${value.toInt()}%',
//             style: TextStyle(fontSize: 24.rpx(context)),
//             gradient: LinearGradient(
//               colors: [Color(0xFF2379FF), Color(0xFF1EFBE9), Color(0xFFA2FF7C)],
//             ), // 绿色到蓝色
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _GradientTrackShape extends SliderTrackShape {
//   final Gradient gradient;
//   const _GradientTrackShape({required this.gradient});

//   @override
//   Rect getPreferredRect({
//     required RenderBox parentBox,
//     Offset offset = Offset.zero,
//     required SliderThemeData sliderTheme,
//     bool isEnabled = false,
//     bool isDiscrete = false,
//   }) {
//     final double trackHeight = sliderTheme.trackHeight ?? 4.0;
//     final double trackLeft = offset.dx + 16;
//     final double trackTop =
//         offset.dy + (parentBox.size.height - trackHeight) / 2;
//     final double trackWidth = parentBox.size.width - 32;
//     return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
//   }

//   @override
//   void paint(
//     PaintingContext context,
//     Offset offset, {
//     required RenderBox parentBox,
//     required SliderThemeData sliderTheme,
//     required Animation<double> enableAnimation,
//     required TextDirection textDirection,
//     required Offset thumbCenter,
//     bool isEnabled = false,
//     bool isDiscrete = false,
//     Offset? secondaryOffset,
//     double additionalActiveTrackHeight = 0,
//   }) {
//     final Rect trackRect = getPreferredRect(
//       parentBox: parentBox,
//       offset: offset,
//       sliderTheme: sliderTheme,
//       isEnabled: isEnabled,
//       isDiscrete: isDiscrete,
//     );
//     final Paint paint = Paint()..shader = gradient.createShader(trackRect);
//     context.canvas.drawRRect(
//       RRect.fromRectAndRadius(trackRect, Radius.circular(4)),
//       paint,
//     );
//   }
// }

// class RectangularSliderThumbShape extends SliderComponentShape {
//   final double width;
//   final double height;
//   const RectangularSliderThumbShape({this.width = 24, this.height = 12});

//   @override
//   Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

//   @override
//   void paint(
//     PaintingContext context,
//     Offset center, {
//     required Animation<double> activationAnimation,
//     required Animation<double> enableAnimation,
//     required bool isDiscrete,
//     required TextPainter labelPainter,
//     required RenderBox parentBox,
//     required SliderThemeData sliderTheme,
//     required TextDirection textDirection,
//     required double value,
//     required double textScaleFactor,
//     required Size sizeWithOverflow,
//   }) {
//     final rect = Rect.fromCenter(center: center, width: width, height: height);
//     final paint = Paint()..color = sliderTheme.thumbColor ?? Colors.white;
//     context.canvas.drawRRect(
//       RRect.fromRectAndRadius(rect, Radius.circular(3)),
//       paint,
//     );
//   }
// }
