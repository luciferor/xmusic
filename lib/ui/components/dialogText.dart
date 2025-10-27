// ignore: file_names
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:glossy/glossy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class XDialogText extends StatefulWidget {
  const XDialogText({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.showTitle = true,
    required this.onCancel,
    required this.onConfirm,
    this.hintText = '请输入',
  });
  final String title;

  /// 初始输入内容
  final String content;
  final bool showTitle;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;

  /// 确认时回传输入的文本
  final ValueChanged<String> onConfirm;
  final String hintText;

  @override
  // ignore: library_private_types_in_public_api
  _XDialogTextState createState() => _XDialogTextState();
}

class _XDialogTextState extends State<XDialogText>
    with TickerProviderStateMixin {
  late AnimationController enterController;
  late AnimationController exitController;

  bool _isExiting = false;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    enterController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    )..forward();

    exitController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _textController = TextEditingController(text: widget.content);
  }

  Future<void> _handleClose(VoidCallback callback) async {
    if (_isExiting) return;
    _isExiting = true;
    await exitController.forward(); // 播放退出动画
    if (mounted) Navigator.of(context).pop();
    callback();
  }

  @override
  void dispose() {
    enterController.dispose();
    exitController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await _handleClose(() {});
        return false;
      },
      child: KeyboardVisibilityBuilder(
        builder: (context, isKeyboardVisible) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: isKeyboardVisible ? 500.rpx(context) : 0,
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([enterController, exitController]),
                builder: (context, child) {
                  final entering = 1.0 - enterController.value;
                  final exiting = exitController.value;

                  // 合并动画状态（根据不同阶段选择动画）
                  final slide = Offset(
                    entering * 1.0 + exiting * 0.0,
                    -exiting * 0.3,
                  );
                  final rotationY = (entering * pi / 2);
                  final scale = exiting > 0
                      ? 1.0 - exiting * 0.5
                      : 0.8 + (enterController.value * 0.2);
                  final opacity = 1.0 - exiting;

                  return Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..translate(
                          slide.dx * MediaQuery.of(context).size.width,
                          slide.dy * MediaQuery.of(context).size.height,
                        )
                        ..rotateY(rotationY)
                        ..scale(scale),
                      child: child,
                    ),
                  );
                },
                child: _buildCommonContent(
                  widget.title,
                  widget.content,
                  widget.showTitle,
                  widget.cancelText,
                  widget.confirmText,
                  widget.onCancel,
                  widget.onConfirm,
                  isKeyboardVisible,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommonContent(
    String title,
    String content,
    bool showTitle,
    String cancelText,
    String confirmText,
    VoidCallback onCancel,
    ValueChanged<String> onConfirm,
    bool isKeyboardVisible,
  ) {
    return GlossyContainer(
      width: 600.rpx(context),
      height: 450.rpx(context),
      strengthX: 5,
      strengthY: 5,
      gradient: GlossyLinearGradient(
        colors: [Color(0x92000000), Color(0x92000000), Color(0x92000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        opacity: 0.4,
      ),
      border: BoxBorder.all(
        color: const Color(0x4DFFFFFF),
        width: 1.rpx(context),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(0, 168, 154, 154),
          blurRadius: 30.rpx(context),
        ),
      ],
      borderRadius: BorderRadius.circular(70.rpx(context)),
      child: Container(
        padding: EdgeInsets.all(40.rpx(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 40.rpx(context)),
            if (showTitle)
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 36.rpx(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: 40.rpx(context)),
            // 输入框
            Container(
              alignment: Alignment.center,
              height: 70.rpx(context),
              child: TextField(
                controller: _textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.rpx(context)),
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.rpx(context)),
                    borderSide: BorderSide(color: const Color(0x878189FF)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20.rpx(context),
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.rpx(context),
                ),
                onSubmitted: (val) => _handleClose(() => onConfirm(val.trim())),
              ),
            ),

            SizedBox(height: 40.rpx(context)),
            Container(
              height: 70.rpx(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientButton(
                    onPressed: () => _handleClose(widget.onCancel),
                    gradientColors: [
                      Color.fromARGB(20, 255, 255, 255),
                      Color.fromARGB(20, 255, 255, 255),
                      Color.fromARGB(20, 255, 255, 255),
                    ],
                    padding: EdgeInsetsGeometry.symmetric(
                      horizontal: 60.rpx(context),
                    ),
                    borderRadius: 25.rpx(context),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 28.rpx(context),
                      ),
                    ),
                  ),
                  SizedBox(width: 40.rpx(context)),
                  GradientButton(
                    onPressed: () => _handleClose(
                      () => onConfirm(_textController.text.trim()),
                    ),
                    gradientColors: [
                      Color.fromARGB(155, 28, 62, 255),
                      Color.fromARGB(155, 28, 62, 255),
                      Color.fromARGB(155, 28, 62, 255),
                    ],
                    padding: EdgeInsetsGeometry.symmetric(
                      horizontal: 60.rpx(context),
                    ),
                    borderRadius: 25.rpx(context),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 28.rpx(context),
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
  }
}

/// 带封面图选择的歌单创建对话框
class XDialogTextWithCover extends StatefulWidget {
  const XDialogTextWithCover({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.showTitle = true,
    required this.onCancel,
    required this.onConfirm,
    this.hintText = '请输入',
    this.currentImagePath, // 新增：当前封面图路径（用于编辑模式）
  });
  final String title;
  final String content;
  final bool showTitle;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;

  /// 确认时回传输入的文本和封面图路径
  final ValueChanged<Map<String, String>> onConfirm;
  final String hintText;
  final String? currentImagePath; // 当前封面图路径

  @override
  // ignore: library_private_types_in_public_api
  _XDialogTextWithCoverState createState() => _XDialogTextWithCoverState();
}

class _XDialogTextWithCoverState extends State<XDialogTextWithCover>
    with TickerProviderStateMixin {
  late AnimationController enterController;
  late AnimationController exitController;

  bool _isExiting = false;
  late final TextEditingController _textController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    enterController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    )..forward();

    exitController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _textController = TextEditingController(text: widget.content);

    // 初始化当前封面图（编辑模式）
    if (widget.currentImagePath != null) {
      _selectedImagePath = widget.currentImagePath;
    }
  }

  Future<void> _handleClose(VoidCallback callback) async {
    if (_isExiting) return;
    _isExiting = true;
    await exitController.forward();
    if (mounted) Navigator.of(context).pop();
    callback();
  }

  @override
  void dispose() {
    enterController.dispose();
    exitController.dispose();
    _textController.dispose();
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

      final appDir = await getApplicationDocumentsDirectory();
      final imageCacheDir = Directory('${appDir.path}/music_list_image_cache');

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

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'playlist_$timestamp$finalExt';
        targetPath = p.join(imageCacheDir.path, fileName);

        try {
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
        print('🖼️ 图片选择完成:');
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
    return WillPopScope(
      onWillPop: () async {
        await _handleClose(() {});
        return false;
      },
      child: KeyboardVisibilityBuilder(
        builder: (context, isKeyboardVisible) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: isKeyboardVisible ? 500.rpx(context) : 0,
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([enterController, exitController]),
                builder: (context, child) {
                  final entering = 1.0 - enterController.value;
                  final exiting = exitController.value;

                  final slide = Offset(
                    entering * 1.0 + exiting * 0.0,
                    -exiting * 0.3,
                  );
                  final rotationY = (entering * pi / 2);
                  final scale = exiting > 0
                      ? 1.0 - exiting * 0.5
                      : 0.8 + (enterController.value * 0.2);
                  final opacity = 1.0 - exiting;

                  return Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..translate(
                          slide.dx * MediaQuery.of(context).size.width,
                          slide.dy * MediaQuery.of(context).size.height,
                        )
                        ..rotateY(rotationY)
                        ..scale(scale),
                      child: child,
                    ),
                  );
                },
                child: _buildContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return GlossyContainer(
      width: 700.rpx(context),
      height: 500.rpx(context),
      strengthX: 5,
      strengthY: 5,
      gradient: GlossyLinearGradient(
        colors: [Color(0x92000000), Color(0x92000000), Color(0x92000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        opacity: 0.4,
      ),
      border: BoxBorder.all(
        color: const Color(0x4DFFFFFF),
        width: 1.rpx(context),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(0, 168, 154, 154),
          blurRadius: 30.rpx(context),
        ),
      ],
      borderRadius: BorderRadius.circular(70.rpx(context)),
      child: Container(
        padding: EdgeInsets.all(40.rpx(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 30.rpx(context)),
            if (widget.showTitle)
              Center(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 36.rpx(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            SizedBox(height: 80.rpx(context)),

            Row(
              children: [
                Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pickImage();
                  },
                  child: Container(
                    width: 70.rpx(context),
                    height: 70.rpx(context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.rpx(context)),
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
                            child: Image.file(
                              File(_selectedImagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(
                                      16.rpx(context),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        color: Colors.grey[400],
                                        size: 30.rpx(context),
                                      ),
                                      SizedBox(height: 8.rpx(context)),
                                      Text(
                                        '图片加载失败',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 20.rpx(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Colors.white54,
                            size: 40.rpx(context),
                          ),
                  ),
                ),
                SizedBox(width: 20.rpx(context)),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    height: 70.rpx(context),
                    child: TextField(
                      controller: _textController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.rpx(context)),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.rpx(context)),
                          borderSide: BorderSide(
                            color: const Color(0x878189FF),
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.rpx(context),
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28.rpx(context),
                      ),
                      onSubmitted: (val) => _handleConfirm(),
                    ),
                  ),
                ),
              ],
            ),

            // 输入框
            SizedBox(height: 80.rpx(context)),

            // 按钮
            Container(
              height: 70.rpx(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientButton(
                    onPressed: () => _handleClose(widget.onCancel),
                    gradientColors: [
                      Color.fromARGB(20, 255, 255, 255),
                      Color.fromARGB(20, 255, 255, 255),
                      Color.fromARGB(20, 255, 255, 255),
                    ],
                    padding: EdgeInsetsGeometry.symmetric(
                      horizontal: 60.rpx(context),
                    ),
                    borderRadius: 25.rpx(context),
                    child: Text(
                      widget.cancelText,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 28.rpx(context),
                      ),
                    ),
                  ),
                  SizedBox(width: 40.rpx(context)),
                  GradientButton(
                    onPressed: _handleConfirm,
                    gradientColors: [
                      Color.fromARGB(155, 28, 62, 255),
                      Color.fromARGB(155, 28, 62, 255),
                      Color.fromARGB(155, 28, 62, 255),
                    ],
                    padding: EdgeInsetsGeometry.symmetric(
                      horizontal: 60.rpx(context),
                    ),
                    borderRadius: 25.rpx(context),
                    child: Text(
                      widget.confirmText,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 28.rpx(context),
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
  }

  void _handleConfirm() {
    final name = _textController.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(
        msg: '请输入歌单名称',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // 如果是编辑模式且有当前封面图，但没有选择新图片，则使用当前图片
    String finalImagePath = _selectedImagePath ?? widget.currentImagePath ?? '';

    if (finalImagePath.isEmpty) {
      Fluttertoast.showToast(
        msg: '请选择封面图',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    _handleClose(() {
      widget.onConfirm({'name': name, 'imagePath': finalImagePath});
    });
  }
}
