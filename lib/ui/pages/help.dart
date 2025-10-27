import 'package:flutter/material.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HelpState createState() => _HelpState();
}

class _HelpState extends State<Help> {
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Column(
        children: [
          // 顶部导航栏
          Container(
            margin: EdgeInsets.only(bottom: 40.rpx(context)),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            child: Row(
              children: [
                Re(),
                Expanded(child: Container(color: Colors.transparent)),
              ],
            ),
          ),
          // 可滚动的内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 40.rpx(context)),
              child: Column(
                children: [
                  // App使用说明
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 20.rpx(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.rpx(context),
                          ),
                          child: _buildText(
                            context,
                            text:
                                '首次使用取决于你的云盘有没有音频文件,若没有请自行到阿里云网页或者其它端上传音频,上传完成之后可以刷新列表就会读取到上传的文件.',
                            fontSize: 24.rpx(context),
                          ),
                        ),
                        SizedBox(height: 20.rpx(context)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.rpx(context),
                          ),
                          child: _buildText(
                            context,
                            text: '首次播放由于阿里云的路径可能在线播放不成功，你可能需要等待缓存成功之后可以正常播放.',
                            fontSize: 24.rpx(context),
                          ),
                        ),
                        SizedBox(height: 20.rpx(context)),
                        Divider(
                          height: 1.rpx(context),
                          color: Colors.white10,
                          indent: 20.rpx(context),
                          endIndent: 30.rpx(context),
                        ),

                        // 注意事项
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.rpx(context)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.orange,
                                    size: 24.rpx(context),
                                  ),
                                  SizedBox(width: 10.rpx(context)),
                                  Text(
                                    '注意事项',
                                    style: TextStyle(
                                      fontSize: 32.rpx(context),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15.rpx(context)),
                              Text(
                                '• 支持的音频格式：MP3、FLAC、WAV、AAC、OGG等\n'
                                '• 文件大小建议不超过50MB\n'
                                '• 需要稳定的网络连接\n'
                                '• 首次加载可能需要一些时间，请耐心等待',
                                style: TextStyle(
                                  fontSize: 28.rpx(context),
                                  color: Colors.white38,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.rpx(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  title,
                  style: TextStyle(fontSize: 30.rpx(context)),
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 255, 255, 255),
                      Color.fromARGB(150, 255, 255, 255),
                      Color.fromARGB(10, 255, 255, 255),
                    ],
                  ),
                ),
                SizedBox(height: 8.rpx(context)),
                GradientText(
                  description,
                  style: TextStyle(fontSize: 30.rpx(context)),
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(10, 255, 255, 255),
                      Color.fromARGB(150, 255, 255, 255),
                      Color.fromARGB(255, 255, 255, 255),
                    ],
                  ),
                ),
              ],
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
  }) {
    final LinearGradient gradient = LinearGradient(
      colors: isleft
          ? [Color(0xFFFFFFFF), Color(0xB4FFFFFF), Color(0x8FFFFFFF)]
          : [Color(0x50EBEEFF), Color(0x95EBEEFF), Color(0xFFEBEEFF)], // 绿色到蓝色
    );
    final TextStyle style = TextStyle(fontSize: 30.rpx(context));
    return Container(
      alignment: isleft ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.only(left: isSpace ? 40.rpx(context) : 0),
      child: ShaderMask(
        shaderCallback: (bounds) => gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: Text(text, style: style.copyWith(color: Colors.white)),
      ),
    );
  }
}
