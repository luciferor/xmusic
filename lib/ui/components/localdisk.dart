import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:glossy/glossy.dart';
import 'package:xmusic/services/local_audio_service.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/dialog.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Localdisk extends StatefulWidget {
  const Localdisk({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocaldiskState createState() => _LocaldiskState();
}

class _LocaldiskState extends State<Localdisk>
    with AutomaticKeepAliveClientMixin {
  final LocalAudioService _localAudioService = LocalAudioService.instance;
  final PlayerUIController _playerController = Get.find<PlayerUIController>();

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _localAudioFiles = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String _totalSize = '0 B';

  @override
  void initState() {
    super.initState();
    _loadLocalAudioFiles();
  }

  /// 显示提示信息
  void _showMessage(String message) {
    try {
      Fluttertoast.showToast(msg: message);
    } catch (e) {
      // 如果fluttertoast失败，使用SmartDialog
      SmartDialog.showToast(message);
    }
  }

  /// 加载本地音频文件
  Future<void> _loadLocalAudioFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _localAudioService.getLocalAudioFiles();
      final totalSize = await _localAudioService.getLocalAudioDirSize();

      setState(() {
        _localAudioFiles = files;
        _totalSize = totalSize;
      });
    } catch (e) {
      if (mounted) {
        _showMessage('加载本地音频失败: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 导入音频文件
  Future<void> _importAudioFiles() async {
    print('aaaaaaaaaaaaaaaaaaaaaaa');
    setState(() {
      _isImporting = true;
    });

    try {
      final importedFiles = await _localAudioService.importAudioFiles();

      if (importedFiles.isNotEmpty) {
        // 重新加载文件列表
        await _loadLocalAudioFiles();

        if (mounted) {
          _showMessage('成功导入 ${importedFiles.length} 个音频文件');
        }
      } else {
        if (mounted) {
          _showMessage('未选择任何音频文件');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('导入音频文件失败: $e');
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  /// 播放本地音频
  Future<void> _playLocalAudio(int index) async {
    try {
      // 设置播放列表为本地音频列表
      await _playerController.resetPlaylist(_localAudioFiles);

      // 播放指定索引的音频
      await _playerController.tryPlayLocalTrack(index);
    } catch (e) {
      if (mounted) {
        _showMessage('播放失败: $e');
      }
    }
  }

  /// 删除本地音频文件
  Future<void> _deleteLocalAudio(int index) async {
    final track = _localAudioFiles[index];
    final fileName = track['name'] as String;

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
      barrierLabel: "Custom3DDialog",
      barrierColor: Colors.black38,
      transitionDuration: Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return XDialog(
          title: '删除本地歌曲',
          content: '确定要删除 "$fileName" 吗？此操作不可撤销。',
          confirmText: '确认',
          cancelText: '取消',
          onCancel: () {},
          onConfirm: () async {
            try {
              final success = await _localAudioService.deleteLocalAudioFile(
                track['path'],
              );
              if (success) {
                // 重新加载文件列表
                await _loadLocalAudioFiles();

                if (mounted) {
                  _showMessage('文件已删除');
                }
              } else {
                if (mounted) {
                  _showMessage('删除文件失败');
                }
              }
            } catch (e) {
              if (mounted) {
                _showMessage('删除文件失败: $e');
              }
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// 清理孤立的封面图缓存
  Future<void> _cleanupCoverCache() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _localAudioService.cleanupOrphanedCoverCache();

      if (mounted) {
        _showMessage('封面图缓存清理完成');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('清理封面图缓存失败: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 更新缓存列表数据
  Future<void> _updateCacheListOrder(int oldIndex, int newIndex) async {
    try {
      // 获取当前播放索引
      final currentIndex = _playerController.currentIndex.value;

      // 更新播放列表中的索引
      if (currentIndex >= 0 && currentIndex < _localAudioFiles.length) {
        if (currentIndex == oldIndex) {
          // 如果当前播放的是被拖动的项目，更新播放索引
          _playerController.currentIndex.value = newIndex;
        } else if (currentIndex > oldIndex && currentIndex <= newIndex) {
          // 如果当前播放的项目在拖动范围内，需要调整索引
          _playerController.currentIndex.value = currentIndex - 1;
        } else if (currentIndex < oldIndex && currentIndex >= newIndex) {
          // 如果当前播放的项目在拖动范围内，需要调整索引
          _playerController.currentIndex.value = currentIndex + 1;
        }
      }

      // 更新播放列表
      _playerController.playlist.value = List.from(_localAudioFiles);

      // 直接保存到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'local_audio_tracks',
        json.encode(_localAudioFiles),
      );

      if (mounted) {
        _showMessage('播放列表顺序已更新');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('更新播放列表顺序失败: $e');
      }
    }
  }

  /// 构建音频列表项
  Widget _buildAudioListItem(int index, Map<String, dynamic> track) {
    final fileId = track['file_id'] ?? track['id'] ?? '';
    final title = track['title'] ?? track['name'] ?? '未知';
    final artist = track['artist'] ?? '本地音频';
    final fileSize = track['size'] as int? ?? 0;
    final ext = track['name']?.toString().split('.').last.toLowerCase() ?? '';

    // 检查是否为当前播放的音频
    final isCurrent =
        _playerController.currentIndex.value == index &&
        _playerController.playlist.isNotEmpty &&
        _playerController.playlist.length == _localAudioFiles.length;

    // 格式化文件大小
    String formattedSize = '';
    if (fileSize < 1024) {
      formattedSize = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    // 确定标签
    String? tag;
    if (ext == 'flac' || ext == 'wav' || ext == 'ape' || ext == 'alac') {
      tag = '无损';
    } else if (ext == 'mp3') {
      tag = 'MP3';
    } else if (ext == 'aac') {
      tag = 'AAC';
    } else if (ext == 'ogg') {
      tag = 'OGG';
    } else if (ext == 'm4a') {
      tag = 'M4A';
    }

    return Dismissible(
      key: ValueKey('local_${fileId}_$index'),
      direction: DismissDirection.endToStart, // 只允许从右向左滑动（左滑）
      confirmDismiss: (direction) async {
        // 显示确认对话框
        return await showGeneralDialog(
          context: context,
          barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
          barrierLabel: "Custom3DDialog",
          barrierColor: Colors.black38,
          transitionDuration: Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return XDialog(
              title: '删除本地歌曲',
              content: '确定要删除 "$title" 吗？此操作不可撤销。',
              confirmText: '确认',
              cancelText: '取消',
              onCancel: () {},
              onConfirm: () async {
                try {
                  final success = await _localAudioService.deleteLocalAudioFile(
                    track['path'],
                  );
                  if (success) {
                    // 重新加载文件列表
                    await _loadLocalAudioFiles();

                    if (mounted) {
                      _showMessage('文件已删除');
                    }
                  } else {
                    if (mounted) {
                      _showMessage('删除文件失败');
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _showMessage('删除文件失败: $e');
                  }
                }
              },
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
      onDismissed: (direction) {
        // 删除确认后执行删除操作
        _deleteLocalAudio(index);
      },
      // 左滑时显示的背景
      background: Container(
        margin: EdgeInsets.only(left: 40.rpx(context), right: 40.rpx(context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, const Color.fromARGB(226, 255, 0, 0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(40.rpx(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              margin: EdgeInsets.only(right: 40.rpx(context)),
              child: Icon(
                CupertinoIcons.trash_circle_fill,
                color: const Color(0x7DF44336),
                size: 60.rpx(context),
              ),
            ),
            SizedBox(width: 40.rpx(context)),
          ],
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(left: 40.rpx(context), right: 40.rpx(context)),
        child: Container(
          padding: EdgeInsets.all(20.rpx(context)),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.white10 : Colors.transparent,
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 255, 255, 255),
                Colors.transparent,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(40.rpx(context)),
          ),
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _playLocalAudio(index);
            },
            child: Row(
              children: [
                // 序号
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    width: 50.rpx(context),
                    child: Center(
                      child: isCurrent
                          ? GradientText(
                              (index + 1).toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 30.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2379FF),
                                  Color(0xFF1EFBE9),
                                  Color(0xFFA2FF7C),
                                ],
                              ),
                            )
                          : Text(
                              (index + 1).toString().padLeft(2, '0'),
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 28.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),

                SizedBox(width: 20.rpx(context)),

                // 封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(30.rpx(context)),
                  child: Container(
                    width: 90.rpx(context),
                    height: 90.rpx(context),
                    color: Colors.grey[800],
                    child: Stack(
                      children: [
                        // 封面图（使用fileId去缓存取）
                        Positioned.fill(
                          child: CachedImage(
                            imageUrl: 'local://$fileId', // 使用占位符URL触发加载
                            width: 90.rpx(context),
                            height: 90.rpx(context),
                            fit: BoxFit.cover,
                            cacheKey: fileId,
                            placeholder: Container(
                              width: 90.rpx(context),
                              height: 90.rpx(context),
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.music_note,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                            ),
                            errorWidget: Image.asset(
                              'assets/images/Hi-Res.png',
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 30.rpx(context)),

                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 歌名
                      Container(
                        child: isCurrent
                            ? GradientText(
                                title,
                                style: TextStyle(
                                  fontSize: 30.rpx(context),
                                  fontWeight: FontWeight.bold,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2379FF),
                                    Color(0xFF1EFBE9),
                                    Color(0xFFA2FF7C),
                                  ],
                                ),
                              )
                            : GradientText(
                                title,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0x78D7E0FF),
                                    Color(0xB4D7E0FF),
                                    Color(0xFFD7E0FF),
                                  ],
                                ),
                                style: TextStyle(fontSize: 28.rpx(context)),
                              ),
                      ),
                      SizedBox(height: 5.rpx(context)),
                      // 歌手+标签+文件大小
                      Row(
                        children: [
                          if (tag != null && tag == '无损')
                            SvgPicture.asset(
                              'assets/images/sq.svg',
                              width: 50.rpx(context),
                              height: 50.rpx(context),
                              color: Colors.greenAccent,
                            ),
                          if (tag != null && tag != '无损')
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.rpx(context),
                                vertical: 3.rpx(context),
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 2.rpx(context),
                                  color: Colors.amberAccent,
                                ),
                                borderRadius: BorderRadius.circular(
                                  12.rpx(context),
                                ),
                              ),
                              child: Text(
                                tag.toString(),
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 15.rpx(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          SizedBox(width: 10.rpx(context)),
                          Flexible(
                            child: Text(
                              artist,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 24.rpx(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (formattedSize.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text(
                                formattedSize,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 24.rpx(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 播放状态
                if (isCurrent)
                  Container(
                    margin: EdgeInsets.only(left: 8.rpx(context), right: 0),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.rpx(context),
                      vertical: 10.rpx(context),
                    ),
                    child: SizedBox(
                      width: 60.rpx(context),
                      height: 60.rpx(context),
                      child: PlayerIcon(
                        isPlaying: _playerController.isPlaying.value,
                        fileId: fileId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SizedBox(height: 20.rpx(context)),
          Container(
            height: 80.rpx(context),
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
            child: GlossyContainer(
              width: double.infinity,
              height: double.infinity,
              strengthX: 7,
              strengthY: 7,
              gradient: GlossyLinearGradient(
                colors: [
                  Color.fromARGB(0, 241, 255, 255),
                  Color.fromARGB(0, 214, 255, 252),
                  Color.fromARGB(0, 231, 255, 251),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                opacity: 0.1,
              ),
              border: BoxBorder.all(
                color: const Color.fromARGB(50, 255, 255, 255),
                width: 1.rpx(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(0, 168, 154, 154),
                  blurRadius: 30.rpx(context),
                ),
              ],
              borderRadius: BorderRadius.circular(30.rpx(context)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.rpx(context)),
                height: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.folder,
                      color: Colors.white12,
                      size: 40.rpx(context),
                    ),
                    SizedBox(width: 20.rpx(context)),
                    Expanded(
                      child: GradientText(
                        '本地音乐',
                        style: TextStyle(
                          fontSize: 30.rpx(context),
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(30, 241, 245, 255),
                            Color.fromARGB(199, 142, 171, 243),
                            Color.fromARGB(255, 169, 192, 248),
                          ],
                        ),
                      ),
                    ),

                    // 导入按钮
                    Bounceable(
                      onTap: _isImporting ? null : _importAudioFiles,
                      child: Container(
                        child: Row(
                          children: [
                            if (_isImporting)
                              SizedBox(
                                width: 26.rpx(context),
                                height: 26.rpx(context),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white24,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                CupertinoIcons.plus_app,
                                color: const Color(0x50FFFFFF),
                                size: 30.rpx(context),
                              ),
                            SizedBox(width: 4.rpx(context)),
                            GradientText(
                              _isImporting ? '正在导入' : '导入',
                              style: TextStyle(
                                fontSize: 24.rpx(context),
                                fontWeight: FontWeight.bold,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x50FFFFFF),
                                  Color(0x50FFFFFF),
                                  Color(0x50FFFFFF),
                                ],
                              ),
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

          SizedBox(height: 20.rpx(context)),
          // 音频列表
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2379FF),
                      ),
                    ),
                  )
                : _localAudioFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.5,
                          child: Image.asset(
                            'assets/images/empty.png',
                            width: 300.rpx(context),
                            height: 300.rpx(context),
                          ),
                        ),
                        SizedBox(height: 40.rpx(context)),
                        GradientText(
                          '暂无歌曲数据',
                          style: TextStyle(
                            fontSize: 42.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color(0xC7FFFFFF),
                              Color(0x63FFFFFF),
                              Color(0x09FFFFFF),
                            ],
                          ),
                        ),
                        SizedBox(height: 40.rpx(context)),
                        Container(
                          width: 300.rpx(context),
                          height: 70.rpx(context),
                          child: GradientButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _importAudioFiles();
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isImporting)
                                  SizedBox(
                                    width: 26.rpx(context),
                                    height: 26.rpx(context),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white38,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    CupertinoIcons.plus_app,
                                    color: Colors.white38,
                                  ),
                                SizedBox(width: 10.rpx(context)),
                                Text(
                                  _isImporting ? '正在导入' : '导入歌曲',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 28.rpx(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.only(bottom: 140.rpx(context)),
                    itemCount: _localAudioFiles.length,
                    buildDefaultDragHandles: false,
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 0,
                                child: child,
                              );
                            },
                            child: child,
                          );
                        },
                    itemBuilder: (context, index) {
                      return Container(
                        key: ValueKey(
                          'local_${_localAudioFiles[index]['file_id'] ?? _localAudioFiles[index]['id'] ?? index}',
                        ),
                        child: _buildAudioListItem(
                          index,
                          _localAudioFiles[index],
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _localAudioFiles.removeAt(oldIndex);
                      _localAudioFiles.insert(newIndex, item);

                      // 更新缓存列表数据
                      _updateCacheListOrder(oldIndex, newIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
