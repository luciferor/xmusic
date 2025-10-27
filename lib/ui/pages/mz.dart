import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';

class Mz extends StatelessWidget {
  const Mz({super.key});

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
                Expanded(child: Container()),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(40.rpx(context)),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildText(
                      context,
                      text: '请仔细阅读本免责声明',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text:
                          '一.  软件性质与功能：本音乐播放器软件（以下简称“本软件”）是一款技术工具，其主要功能是提供音频文件的播放、管理和组织能力。本软件本身不包含、不预装、不存储、不托管任何音乐或其他受版权保护的音频内容。',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text:
                          '二.  无内置内容：用户理解并同意，本软件不提供任何音乐库、歌曲、专辑或其他音频文件。软件运行所需的音频内容完全来源于用户自身。',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(context, text: '三.  用户内容来源与责任：'),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '1. 用户在本软件中播放的音频文件必须由用户自行获取并存储于其本地设备（如手机、电脑存储空间）或用户拥有合法访问权限的云存储服务中。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '2. 用户有完全且唯一的责任确保其播放的音频文件是通过合法授权的渠道获得，并拥有相应的版权许可或属于合理使用范畴（例如，用户自己创作的音乐或已进入公共领域的作品）。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '3. 本软件仅为用户提供的音频文件提供播放功能，对用户文件内容的合法性、版权状态不进行任何审查、验证或保证。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text:
                          '四.  第三方服务链接（如适用）：如果本软件提供了与第三方音乐流媒体服务或在线内容平台的集成或链接功能：',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text: '1. 用户理解通过此类链接访问的音频内容完全由该第三方服务提供。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text: '2. 用户使用任何第三方服务时，需遵守该服务的服务条款、隐私政策及版权政策。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '3. 本软件的开发者、运营方与这些第三方服务无隶属关系，不对其提供的任何内容的可用性、准确性、合法性或版权状态负责。用户与第三方服务之间的任何争议应直接与该服务解决。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(context, text: '五.  版权侵权责任免除：'),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '1. 鉴于本软件不提供、不存储、不托管任何受版权保护的音频内容本身，用户因播放其个人持有的音频文件或通过第三方服务获取的音频文件而产生的任何版权侵权问题，均与开发者、运营方无关。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 10.rpx(context)),
                    _buildText(
                      context,
                      isSpace: true,
                      text:
                          '2. 用户因使用本软件播放未经授权的版权内容而产生的一切法律责任和后果，均由用户自行承担。开发者、运营方明确免除由此产生的任何直接、间接、附带、特殊、惩罚性或后果性的损害赔偿责任。',
                      fontSize: 24.rpx(context),
                      isleft: false,
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text:
                          '六.  遵守法律：用户承诺在使用本软件时，将严格遵守所有适用的著作权法、知识产权法及其他相关法律法规。',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text: '七.  声明更新：本免责声明可能随时更新。用户继续使用本软件即表示接受更新后的声明。',
                      fontSize: 24.rpx(context),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    _buildText(
                      context,
                      text:
                          '请用户在使用本软件播放任何音频文件前，务必确认其拥有该文件的合法播放权利。尊重版权是每个用户的责任。',
                      fontSize: 24.rpx(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Copyright(),
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
