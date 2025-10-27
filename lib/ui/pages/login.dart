import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:glossy/glossy.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _isLoading = false;
  String? _errorMessage;
  final AliyunDriveService _aliyunService = AliyunDriveService();
  bool _agreed = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 获取授权URL
      final authUrl = _aliyunService.getAuthorizationUrl();

      // 2. 使用 flutter_web_auth_2 发起授权
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: "xmusic", // 这里必须和 AndroidManifest.xml 里声明的 scheme 一致
      );

      // 3. 从返回的URL中解析出 `code`
      final code = Uri.parse(result).queryParameters['code'];

      if (code != null) {
        // 4. 使用 code 换取 token
        final tokenData = await _aliyunService.getAccessToken(code);

        if (tokenData != null) {
          Fluttertoast.showToast(msg: '登录成功，正在跳转...');
          Get.offAllNamed('/'); // 跳转到主页
        } else {
          throw Exception('获取Token失败');
        }
      } else {
        throw Exception('未能从回调中获取授权码');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '授权过程出错: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Base(
        child: Stack(
          children: [
            // 登录内容
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
                child: Column(
                  children: [
                    // 背景头像
                    Center(
                      child: Hero(
                        tag: 'hero-avatar',
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
                                  0.rpx(context),
                                ),
                                child: toContext.widget,
                              );
                            },
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 270.rpx(context),
                          height: 270.rpx(context),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 160.rpx(context)),
                    // 标题
                    GradientText(
                      '欢迎使用荧惑音乐',
                      style: TextStyle(
                        fontSize: 48.rpx(context),
                        fontWeight: FontWeight.bold,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFA2FF7C),
                          Color(0x9B1EFBE9),
                          Color(0x1E2377FF),
                        ], // 绿色到蓝色
                      ),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    // 副标题
                    _buildText(
                      context,
                      text: '连接阿里云盘，享受云端音乐',
                      fontSize: 28.rpx(context),
                      isleft: false,
                      alignleft: false,
                    ),
                    SizedBox(height: 140.rpx(context)),
                    // 协议勾选区
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircularCheckbox(
                          value: _agreed,
                          size: 30.rpx(context),
                          onChanged: (val) {
                            setState(() => _agreed = val);
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _agreed = !_agreed;
                            });
                          },
                          child: Row(
                            children: [
                              SizedBox(width: 10.rpx(context)),
                              Text(
                                '阅读并同意',
                                style: TextStyle(
                                  fontSize: 28.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 10.rpx(context)),
                              GestureDetector(
                                onTap: () {
                                  showCupertinoModalBottomSheet(
                                    topRadius: Radius.circular(60.rpx(context)),
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    expand: false,
                                    builder: (context) =>
                                        _buildUserAgreement(context),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.only(top: 6.rpx(context)),
                                  child: Text(
                                    '《用户协议》',
                                    style: TextStyle(
                                      fontSize: 28.rpx(context),
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.rpx(context)),
                              Text(
                                '和',
                                style: TextStyle(
                                  fontSize: 28.rpx(context),
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 10.rpx(context)),
                              GestureDetector(
                                onTap: () {
                                  showCupertinoModalBottomSheet(
                                    topRadius: Radius.circular(60.rpx(context)),
                                    backgroundColor: Colors.transparent,
                                    context: context,
                                    expand: false,
                                    builder: (context) =>
                                        _buildSecretAgreement(context),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.only(top: 6.rpx(context)),
                                  child: Text(
                                    '《隐私协议》',
                                    style: TextStyle(
                                      fontSize: 28.rpx(context),
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 50.rpx(context)),

                    // 阿里云盘授权按钮
                    SizedBox(
                      width: 360.rpx(context),
                      height: 80.rpx(context),
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_agreed) ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.lightBlue,
                          disabledIconColor: Colors.white24,
                          disabledBackgroundColor: Colors.white10,
                          disabledForegroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              25.rpx(context),
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20.rpx(context),
                                height: 20.rpx(context),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.amber,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud, size: 40.rpx(context)),
                                  SizedBox(width: 15.rpx(context)),
                                  Text(
                                    '阿里云盘授权',
                                    style: TextStyle(
                                      fontSize: 32.rpx(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // 错误信息
                    if (_errorMessage != null) ...[
                      SizedBox(height: 20.rpx(context)),
                      Container(
                        padding: EdgeInsets.all(15.rpx(context)),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(10.rpx(context)),
                          border: Border.all(
                            color: Colors.red.withAlpha((0.3 * 255).round()),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 16.rpx(context),
                            ),
                            SizedBox(width: 10.rpx(context)),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14.rpx(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //用户协议
  Widget _buildUserAgreement(BuildContext context) {
    return GlossyContainer(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height - 300.rpx(context),
      strengthX: 15,
      strengthY: 15,
      gradient: GlossyLinearGradient(
        colors: [Color(0x78DCFAE6), Color(0x67E4EFFD), Color(0x5FF5E2FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        opacity: 0.2,
      ),
      border: BoxBorder.all(color: Colors.transparent, width: 0),
      boxShadow: [
        BoxShadow(color: const Color(0x76000000), blurRadius: 30.rpx(context)),
      ],
      borderRadius: BorderRadius.circular(0.rpx(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: 80.rpx(context),
            child: Container(
              width: 80.rpx(context),
              height: 10.rpx(context),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(10.rpx(context)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(40.rpx(context)),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(bottom: 40.rpx(context)),
                    child: Text(
                      '用户使用协议',
                      style: TextStyle(
                        fontSize: 36.rpx(context),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildText(
                    context,
                    text:
                        '欢迎使用本应用（以下简称“荧惑音乐”）。在您使用本应用前，请仔细阅读以下协议内容，确保您充分理解本协议的所有条款。若您不同意本协议任何内容，请勿使用本应用。',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '一、服务内容',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '1. 用户在本软件中播放的音频文件必须由用户自行获取并存储于其本地设备（如手机、电脑存储空间）或用户拥有合法访问权限的云存储服务中。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本应用为用户提供音频播放工具，帮助用户管理、播放其个人云盘中的音频文件。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 本应用不提供任何形式的音频内容搜索、推荐、下载、购买或分享服务。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '二、用户权责',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '1. 用户应确保其上传、播放的音频文件具有合法来源，且不侵犯任何第三方的知识产权、肖像权、隐私权等合法权益。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 用户不得使用本应用传播、储存或分享非法或侵权内容。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '3. 如用户上传的内容涉及侵权、违法或违反本协议条款的行为，用户将独立承担由此引起的一切法律责任，与本应用无关。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '三、内容管理',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本应用不对用户上传、播放的内容进行任何形式的存储、分析或索引。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 本应用不会主动访问或分享用户的任何音频内容，也不会对音频内容进行内容识别或推荐。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '3. 所有播放、缓存行为均由用户主动触发，仅用于提升用户体验。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '四、缓存机制',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本应用在本地设备加密缓存用户播放的音频数据，以提升播放体验。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 缓存数据为临时使用，用户可随时清除。本应用不保证缓存的完整性与持久性。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '3. 缓存数据不对其他应用或用户开放，也不得用于任何形式的导出、复制或分发。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(context, text: '五、其他', fontSize: 28.rpx(context)),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本协议自用户首次使用本应用起生效。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '2. 本应用有权根据实际运营情况对本协议进行修改，修改后的协议将在更新时提示或展示，用户如继续使用视为同意。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                ],
              ),
            ),
          ),
          // 同意按钮
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 40.rpx(context),
              horizontal: 180.rpx(context),
            ),
            alignment: Alignment.center,
            child: GradientButton(
              onPressed: () {
                setState(() {
                  _agreed = true;
                });
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              gradientColors: [
                Color.fromARGB(10, 28, 62, 255),
                Color.fromARGB(60, 28, 62, 255),
                Color.fromARGB(255, 28, 62, 255),
              ],
              padding: EdgeInsetsGeometry.symmetric(
                vertical: 10.rpx(context),
                horizontal: 0.rpx(context),
              ),
              borderRadius: 20.rpx(context),
              child: Text(
                '同意《用户使用协议》',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w100,
                  fontSize: 28.rpx(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //隐私协议
  Widget _buildSecretAgreement(BuildContext context) {
    return GlossyContainer(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height - 300.rpx(context),
      strengthX: 15,
      strengthY: 15,
      gradient: GlossyLinearGradient(
        colors: [Color(0x78DCFAE6), Color(0x67E4EFFD), Color(0x5FF5E2FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        opacity: 0.2,
      ),
      border: BoxBorder.all(color: Colors.transparent, width: 0),
      boxShadow: [
        BoxShadow(color: const Color(0x76000000), blurRadius: 30.rpx(context)),
      ],
      borderRadius: BorderRadius.circular(0.rpx(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: 80.rpx(context),
            child: Container(
              width: 80.rpx(context),
              height: 10.rpx(context),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(10.rpx(context)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(40.rpx(context)),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(bottom: 40.rpx(context)),
                    child: Text(
                      '隐私协议',
                      style: TextStyle(
                        fontSize: 36.rpx(context),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildText(
                    context,
                    text:
                        '本应用尊重并保护所有使用服务用户的个人隐私权。本隐私政策说明了我们在您使用本应用时，如何收集、使用、保护和处理您的信息。',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '一、信息收集',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本应用不会主动收集用户的音频内容或云盘数据。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '2. 为保障播放功能的正常运行，应用可能获取以下权限：(网络访问权限（用于播放远程文件）、存储权限（用于本地缓存）)。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '3. 所有缓存内容仅用于应用内部使用，不会上传至任何服务器。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '二、信息使用',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 本地缓存仅为提升播放性能，并且加密存储且供用户私有，数据不用于任何商业用途。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 本应用不会将您的任何信息用于广告推送、用户画像或行为追踪。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '三、信息保护',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 所有缓存文件储存在本地沙盒中，其他应用无法访问。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 缓存数据采用加密或私有路径管理，防止被第三方导出。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '四、第三方服务',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '1. 本应用可能接入少量第三方广告服务，用于支持产品的持续运营。我们承诺：（不进行过度广告投放、不在用户播放核心功能过程中打断或强制展示广告、不开启定向广告或兴趣推荐）',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '2. 本应用使用基础统计服务，用于了解应用使用情况（如用户数量、设备类型、访问频率等），以便优化产品体验。统计数据不包含任何可识别用户个人身份的信息，不会用于广告追踪或出售。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text:
                        '3. 若将来接入第三方广告或统计 SDK，我们将严格遵循相关隐私政策，并在更新版本中公示所用服务与权限用途。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 20.rpx(context)),
                  _buildText(
                    context,
                    text: '五、变更与说明',
                    fontSize: 28.rpx(context),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '1. 隐私政策可能随功能调整进行修改，届时会通过更新版本通知用户。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                  SizedBox(height: 10.rpx(context)),
                  _buildText(
                    context,
                    isSpace: true,
                    text: '2. 若用户不同意修改内容，应立即停止使用本应用。',
                    fontSize: 28.rpx(context),
                    isleft: false,
                  ),
                ],
              ),
            ),
          ),
          // 同意按钮
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 40.rpx(context),
              horizontal: 180.rpx(context),
            ),
            alignment: Alignment.center,
            child: GradientButton(
              onPressed: () {
                setState(() {
                  _agreed = true;
                });
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              gradientColors: [
                Color.fromARGB(10, 28, 62, 255),
                Color.fromARGB(60, 28, 62, 255),
                Color.fromARGB(255, 28, 62, 255),
              ],
              padding: EdgeInsetsGeometry.symmetric(
                vertical: 10.rpx(context),
                horizontal: 0.rpx(context),
              ),
              borderRadius: 20.rpx(context),
              child: Text(
                '我已阅读完毕，并知晓',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w100,
                  fontSize: 28.rpx(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(
    BuildContext context, {
    double fontSize = 14,
    String text = '',
    bool isleft = true,
    bool isSpace = false,
    bool alignleft = true,
  }) {
    final LinearGradient gradient = LinearGradient(
      colors: isleft
          ? [Color(0xFFFFFFFF), Color(0xB4FFFFFF), Color(0x8FFFFFFF)]
          : [Color(0x50EBEEFF), Color(0x95EBEEFF), Color(0xFFEBEEFF)], // 绿色到蓝色
    );
    return Container(
      alignment: alignleft ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.only(left: isSpace ? 40.rpx(context) : 0),
      child: ShaderMask(
        shaderCallback: (bounds) => gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.none,
            fontSize: fontSize,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
