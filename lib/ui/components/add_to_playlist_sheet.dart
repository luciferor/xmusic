import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:glossy/glossy.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// 底部弹窗：添加到歌单
class AddToPlaylistSheet extends StatefulWidget {
  final Map<String, dynamic> track;
  const AddToPlaylistSheet({super.key, required this.track});

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final PlaylistService playlistService = Get.put(PlaylistService());
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _creating = false;
  String? _selectedImagePath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 选择图片并保存到沙盒（支持重复检测）
  Future<void> _pickImage() async {
    try {
      // 显示选择提示
      if (mounted) {
        Fluttertoast.showToast(
          msg: '正在打开相册...',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
        );
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: '未选择图片',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
        return;
      }

      // 验证图片文件
      final imageFile = File(image.path);
      if (!await imageFile.exists()) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: '图片文件不存在',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // 获取沙盒目录
      final appDir = await getApplicationDocumentsDirectory();
      final imageCacheDir = Directory('${appDir.path}/music_list_image_cache');

      // 创建目录（如果不存在）
      if (!await imageCacheDir.exists()) {
        await imageCacheDir.create(recursive: true);
      }

      final newImageBytes = await image.readAsBytes();

      // 检查图片大小
      if (newImageBytes.length > 10 * 1024 * 1024) {
        // 10MB限制
        if (mounted) {
          Fluttertoast.showToast(
            msg: '图片文件过大，请选择小于10MB的图片',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      String? existingPath;

      // 检查是否已存在相同图片
      if (await imageCacheDir.exists()) {
        final files = await imageCacheDir.list().toList();
        for (final file in files) {
          if (file is File) {
            try {
              final existingBytes = await file.readAsBytes();
              if (existingBytes.length == newImageBytes.length) {
                bool isIdentical = true;
                // 只比较前1000字节和后1000字节，提高性能
                final compareLength = existingBytes.length > 2000
                    ? 1000
                    : existingBytes.length;
                for (int i = 0; i < compareLength; i++) {
                  if (existingBytes[i] != newImageBytes[i]) {
                    isIdentical = false;
                    break;
                  }
                }
                // 如果前面相同，检查后面
                if (isIdentical && existingBytes.length > 2000) {
                  for (
                    int i = existingBytes.length - compareLength;
                    i < existingBytes.length;
                    i++
                  ) {
                    if (existingBytes[i] != newImageBytes[i]) {
                      isIdentical = false;
                      break;
                    }
                  }
                }
                if (isIdentical) {
                  existingPath = file.path;
                  break;
                }
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      String targetPath;
      if (existingPath != null) {
        // 使用现有图片路径
        targetPath = existingPath;
        if (mounted) {
          Fluttertoast.showToast(
            msg: '使用已有图片',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.blue,
            textColor: Colors.white,
          );
        }
      } else {
        // 保持原始文件扩展名，支持更多格式
        final originalExt = p.extension(image.path).toLowerCase();
        final supportedExts = ['.jpg', '.jpeg', '.png', '.webp'];
        final finalExt = supportedExts.contains(originalExt)
            ? originalExt
            : '.jpg';

        // 生成新的唯一文件名
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'playlist_$timestamp$finalExt';
        targetPath = p.join(imageCacheDir.path, fileName);

        try {
          // 复制文件到沙盒
          final targetFile = File(targetPath);
          await targetFile.writeAsBytes(newImageBytes);

          if (mounted) {
            Fluttertoast.showToast(
              msg: '已选择图片',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.white,
              textColor: Colors.black,
            );
          }
        } catch (e) {
          if (mounted) {
            Fluttertoast.showToast(
              msg: '保存图片失败: $e',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
          return;
        }
      }

      setState(() {
        _selectedImagePath = targetPath;
      });

      // 调试信息
      if (kDebugMode) {
        print('🖼️ 图片选择完成 (add_to_playlist_sheet):');
        print('  - 目标路径: $targetPath');
        print('  - 文件是否存在: ${File(targetPath).existsSync()}');
        print('  - 绝对路径: ${File(targetPath).absolute.path}');
        print('  - 文件大小: ${File(targetPath).lengthSync()} bytes');
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '选择图片失败: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(
      builder: (context, isKeyboardVisible) {
        return GlossyContainer(
          width: double.infinity,
          height: double.infinity,
          strengthX: 5,
          strengthY: 7,
          gradient: GlossyLinearGradient(
            colors: [
              Color.fromARGB(120, 0, 0, 0),
              Color.fromARGB(103, 0, 0, 0),
              Color.fromARGB(95, 0, 0, 0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            opacity: 0.05,
          ),
          border: BoxBorder.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(1, 1, 4, 34),
              blurRadius: 30.rpx(context),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(60.rpx(context)),
            topRight: Radius.circular(60.rpx(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部拖拽条（仅装饰，无手势）
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 100.rpx(context),
                padding: EdgeInsets.fromLTRB(
                  20.rpx(context),
                  0,
                  40.rpx(context),
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 80.rpx(context),
                      height: 80.rpx(context),
                      alignment: Alignment.center,
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(true);
                        },
                        icon: Icon(
                          CupertinoIcons.clear_circled,
                          color: Colors.white24,
                          size: 50.rpx(context),
                        ),
                      ),
                    ),
                    Container(
                      width: 200.rpx(context),
                      height: 80.rpx(context),
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(top: 20.rpx(context)),
                      padding: EdgeInsets.symmetric(vertical: 9.rpx(context)),
                      child: GradientButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          setState(() => _creating = !_creating);
                        },
                        gradientColors: [
                          Color.fromARGB(100, 89, 60, 255),
                          Color.fromARGB(100, 29, 71, 255),
                          Color.fromARGB(100, 0, 17, 255),
                        ],
                        padding: EdgeInsetsGeometry.symmetric(
                          vertical: 7.rpx(context),
                          horizontal: 10.rpx(context),
                        ),
                        borderRadius: 25.rpx(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _creating
                                  ? CupertinoIcons.minus_circle
                                  : CupertinoIcons.add_circled,
                              color: Colors.white24,
                              size: 30.rpx(context),
                            ),
                            SizedBox(width: 5.rpx(context)),
                            GradientText(
                              _creating ? '取消创建' : '创建歌单',
                              style: TextStyle(
                                fontSize: 24.rpx(context),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.rpx(context),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x30FFFFFF),
                                  Color(0x63FFFFFF),
                                  Color(0xFFFFFFFF),
                                ], // 绿色到蓝色
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_creating)
                Container(
                  height: 60.rpx(context),
                  padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
                  margin: EdgeInsets.only(top: 20.rpx(context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      //选择图片
                      Bounceable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _pickImage();
                        },
                        child: Container(
                          width: 60.rpx(context),
                          height: 60.rpx(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              20.rpx(context),
                            ),
                            border: Border.all(
                              color: _selectedImagePath != null
                                  ? Colors.blue
                                  : Colors.white24,
                              width: 2,
                            ),
                          ),
                          child: _selectedImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    18.rpx(context),
                                  ),
                                  child: NeonFilter(
                                    colors: [
                                      Colors.pink,
                                      Colors.cyan,
                                      Colors.blue,
                                    ],
                                    blendMode: BlendMode.color,
                                    child: Image.file(
                                      File(_selectedImagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.image,
                                              color: Colors.white54,
                                              size: 40.rpx(context),
                                            );
                                          },
                                    ),
                                  ),
                                )
                              : Icon(
                                  CupertinoIcons.photo,
                                  size: 30.rpx(context),
                                  color: Colors.white60,
                                ),
                        ),
                      ),
                      SizedBox(width: 20.rpx(context)),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          maxLength: 10,
                          cursorColor: Colors.blue,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 28.rpx(context),
                          ),
                          decoration: InputDecoration(
                            hintText: '输入新歌单名',
                            hintStyle: TextStyle(
                              fontSize: 28.rpx(context),
                              color: Colors.white38,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                25.rpx(context),
                              ),
                            ),
                            isDense: true,
                            counterText: '',
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                25.rpx(context),
                              ),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(167, 86, 97, 255),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.rpx(context),
                              vertical: 15.rpx(context),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 15.rpx(context)),
                      GradientButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final name = _nameController.text.trim();
                          if (name.isEmpty || _selectedImagePath == null) {
                            Fluttertoast.showToast(
                              msg: '你添加什么呢？',
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.white,
                              textColor: Colors.black,
                            );
                            return;
                          }
                          final id = await playlistService.createPlaylist(
                            name,
                            imagePath: _selectedImagePath,
                          );
                          if (mounted) {
                            Fluttertoast.showToast(
                              msg: '已创建歌单「$name」',
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.white,
                              textColor: Colors.black,
                            );
                          }
                          await playlistService.addTrackToPlaylist(
                            id,
                            widget.track,
                          );
                          if (mounted) Navigator.of(context).pop(true);
                        },
                        gradientColors: [
                          Color.fromARGB(100, 89, 60, 255),
                          Color.fromARGB(100, 29, 71, 255),
                          Color.fromARGB(100, 0, 17, 255),
                        ],
                        padding: EdgeInsetsGeometry.symmetric(
                          vertical: 10.rpx(context),
                          horizontal: 20.rpx(context),
                        ),
                        borderRadius: 25.rpx(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_alt,
                              color: Colors.white60,
                              size: 35.rpx(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              Expanded(
                child: Obx(() {
                  final lists = playlistService.playlists;
                  if (lists.isEmpty) {
                    return SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.3,
                            child: Image.asset(
                              'assets/images/empty.png',
                              width: 200.rpx(context),
                              height: 200.rpx(context),
                            ),
                          ),
                          SizedBox(height: 40.rpx(context)),
                          GradientText(
                            '还没有歌单，创建一个吧~',
                            style: TextStyle(
                              fontSize: 30.rpx(context),
                              fontWeight: FontWeight.bold,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Color(0x50EBEEFF),
                                Color(0x95EBEEFF),
                                Color(0xFFEBEEFF),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Flexible(
                    child: GridView.builder(
                      padding: EdgeInsets.all(40.rpx(context)),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 20.rpx(context),
                        mainAxisSpacing: 20.rpx(context),
                      ),
                      itemCount: lists.length,
                      itemBuilder: (context, index) {
                        final p = lists[index];
                        final imagePath = p['image_path'] as String?;

                        return Bounceable(
                          onTap: () async {
                            final ok = await playlistService.addTrackToPlaylist(
                              p['id'],
                              widget.track,
                            );
                            if (mounted) {
                              Fluttertoast.showToast(
                                msg: ok ? '已添加到「${p['name']}」' : '已经在此歌单了',
                                toastLength: Toast.LENGTH_LONG,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pop(true);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                // 封面图
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        clipBehavior: Clip.antiAlias,
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            43.rpx(context),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0x7A6933FF),
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                          border: Border.all(
                                            width: 4.rpx(context),
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            40.rpx(context),
                                          ),
                                          child: NeonFilter(
                                            colors: [
                                              Colors.pink,
                                              Colors.cyan,
                                              Colors.blue,
                                            ],
                                            blendMode: BlendMode.color,
                                            child: imagePath != null
                                                ? Image.file(
                                                    File(imagePath),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Container(
                                                            color: Colors
                                                                .grey[800],
                                                            child: Icon(
                                                              CupertinoIcons
                                                                  .music_note,
                                                              color: Colors
                                                                  .white54,
                                                              size: 40.rpx(
                                                                context,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                  )
                                                : Image.asset(
                                                    'assets/images/Hi-Res.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 20.rpx(context),
                                        right: 30.rpx(context),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${(p['tracks'] as List?)?.length ?? 0}',
                                              style: TextStyle(
                                                fontSize: 20.rpx(context),
                                                color: Colors.lightGreenAccent,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Nufei",
                                                shadows: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0x7A6933FF,
                                                    ),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: 20.rpx(context),
                                        bottom: 15.rpx(context),
                                        child: GradientText(
                                          '${p['name']}',
                                          isOver: true,
                                          style: TextStyle(
                                            fontSize: 24.rpx(context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xE2EBEEFF),
                                              Color(0x8FEBEEFF),
                                              Color(0x09EBEEFF),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

/// 通用方法：在任意地方弹出“添加到歌单”面板
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required Map<String, dynamic> track,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, __) => Material(
          color: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddToPlaylistSheet(track: track),
          ),
        ),
      );
    },
  );
}
