import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/dialog.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'dart:io';

class Sliblist extends StatefulWidget {
  final String? playlistId;
  final String? playlistName;

  const Sliblist({super.key, this.playlistId, this.playlistName});

  @override
  // ignore: library_private_types_in_public_api
  _SliblistState createState() => _SliblistState();
}

class _SliblistState extends State<Sliblist> {
  final PlaylistService _playlistService = Get.find<PlaylistService>();
  final PlayerUIController _playerController = Get.find<PlayerUIController>();

  List<Map<String, dynamic>> _tracks = [];
  String _playlistName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistData();
  }

  Future<void> _loadPlaylistData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取歌单名称
      _playlistName = widget.playlistName ?? '歌单';

      // 如果有歌单ID，加载歌单数据
      if (widget.playlistId != null) {
        _tracks = _playlistService.getTracks(widget.playlistId!);

        if (kDebugMode) {
          print('📝 重新加载歌单数据: ${_tracks.length} 首歌曲');
        }

        // 获取歌单名称
        final playlists = _playlistService.playlists;
        final playlist = playlists.firstWhere(
          (p) => p['id'] == widget.playlistId,
          orElse: () => {'name': '歌单'},
        );
        _playlistName = playlist['name'] ?? '歌单';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载歌单数据失败: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onMusicItemTap(int index) async {
    if (index < 0 || index >= _tracks.length) return;

    try {
      // 如果播放列表不是当前歌单，先重置播放列表
      if (!_playerController.isPlaylistConsistent(_tracks)) {
        await _playerController.resetPlaylist(_tracks);
      }

      // 再次验证索引有效性（防止在异步操作过程中列表发生变化）
      if (index < 0 || index >= _tracks.length) {
        if (kDebugMode) {
          print(
            '⚠️ 索引在异步操作后变为无效: index=$index, tracks.length=${_tracks.length}',
          );
        }
        return;
      }

      // 播放选中的歌曲
      await _playerController.onMusicItemTap(index);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 播放歌曲失败: $e');
      }
    }
  }

  /// 从歌单中删除歌曲
  Future<void> _deleteTrackFromPlaylist(
    int index,
    Map<String, dynamic> track,
  ) async {
    if (index < 0 || index >= _tracks.length) return;

    try {
      final fileId = track['file_id'] ?? track['id'] ?? '';
      if (fileId.isEmpty) {
        if (kDebugMode) {
          print('❌ 无法获取歌曲文件ID');
        }
        return;
      }

      // 检查是否为当前播放的歌曲
      final isCurrentPlaying = _playerController.currentPlayingFileId == fileId;

      // 从歌单服务中删除歌曲
      if (widget.playlistId != null) {
        final success = await _playlistService.removeTrackFromPlaylist(
          widget.playlistId!,
          fileId,
        );

        if (success) {
          if (kDebugMode) {
            print('✅ 已从歌单中删除歌曲: ${track['title'] ?? track['name']}');
          }

          // 重新加载歌单数据以确保同步
          await _loadPlaylistData();

          Fluttertoast.showToast(
            msg: '已删除《${track['title'] ?? track['name']}》',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.white,
            textColor: Colors.black,
          );
        } else {
          if (kDebugMode) {
            print('❌ 删除歌曲失败');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 删除歌曲时发生错误: $e');
      }
    }
  }

  Widget _buildPlaylistItem(
    BuildContext context,
    int index,
    Map<String, dynamic> track,
  ) {
    // 获取当前播放的文件ID
    final currentFileId = _playerController.currentPlayingFileId;
    final trackFileId = track['file_id'] ?? track['id'] ?? '';

    // 判断是否为当前播放的歌曲（通过文件ID匹配）
    final isCurrent =
        currentFileId != null &&
        currentFileId.isNotEmpty &&
        currentFileId == trackFileId;

    final title = track['title'] ?? track['name'] ?? '未知';
    final artist = track['artist'] ?? '未知艺术家';

    return Container(
      margin: EdgeInsets.only(left: 40.rpx(context), right: 0.rpx(context)),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(12.rpx(context)),
          onTap: () async {
            HapticFeedback.lightImpact();
            await _onMusicItemTap(index);
          },
          child: Row(
            children: [
              // 序号
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 50.rpx(context),
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
              SizedBox(width: 20.rpx(context)),
              // 封面图片
              ClipRRect(
                borderRadius: BorderRadius.circular(30.rpx(context)),
                child: FutureBuilder<String>(
                  future: _playerController.getBestCoverPath(track),
                  builder: (context, snapshot) {
                    final coverPath = snapshot.data;
                    Widget imageWidget;
                    if (coverPath != null && coverPath.isNotEmpty) {
                      imageWidget = Image.file(
                        File(coverPath),
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
                      );
                    } else {
                      imageWidget = Image.asset(
                        'assets/images/Hi-Res.png',
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
                      );
                    }
                    return NeonFilter(
                      colors: [Colors.pink, Colors.cyan, Colors.blue],
                      blendMode: BlendMode.color,
                      child: imageWidget,
                    );
                  },
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
                    // 歌手
                    Text(
                      artist,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 24.rpx(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    child: Obx(
                      () => PlayerIcon(
                        isPlaying: _playerController.isPlaying.value,
                        fileId: track['file_id'] ?? track['id'] ?? '',
                      ),
                    ),
                  ),
                ),

              GestureDetector(
                onTap: () async {
                  // 触觉反馈
                  HapticFeedback.lightImpact();
                  // 关闭底部弹窗
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
                    barrierLabel: "Custom3DDialog",
                    barrierColor: Colors.black38,
                    transitionDuration: Duration(milliseconds: 600),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return XDialog(
                        title: '删除歌曲',
                        content: '确定要从歌单中删除《$title》吗？',
                        confirmText: '确认',
                        cancelText: '取消',
                        onCancel: () {},
                        onConfirm: () async {
                          await _deleteTrackFromPlaylist(index, track);
                          // ignore: use_build_context_synchronously
                          // Navigator.pop(context);
                        },
                      );
                    },
                    transitionBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  );
                },
                child: Container(
                  width: 90.rpx(context),
                  height: 90.rpx(context),
                  color: const Color(0x01000000),
                  alignment: Alignment.centerRight,
                  child: Icon(
                    CupertinoIcons.trash,
                    color: const Color(0x63FF5252),
                    size: 30.rpx(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Container(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
              width: MediaQuery.of(context).size.width,
              height: 80.rpx(context),
              child: Row(
                children: [
                  Re(),
                  Expanded(child: Container(color: Colors.transparent)),
                  GradientText(
                    '${_tracks.length}',
                    style: TextStyle(
                      fontSize: 24.rpx(context),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Nufei',
                      letterSpacing: 4.rpx(context),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color(0x31737CFF),
                        Color(0x95737CFF),
                        Color(0xFF737CFF),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Container(
            //   padding: EdgeInsets.symmetric(horizontal: 40.rpx(context),vertical: 40.rpx(context)),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     crossAxisAlignment: CrossAxisAlignment.center,
            //     children: [
            //       Expanded(
            //         child: Container(
            //           padding: EdgeInsets.only(right: 40.rpx(context)),
            //           alignment: Alignment.centerRight,
            //           child: Column(
            //             children: [
            //               GradientText(
            //                 widget.playlistName!,
            //                 style: TextStyle(
            //                   fontSize: 36.rpx(context),
            //                   fontWeight: FontWeight.bold,
            //                 ),
            //                 gradient: LinearGradient(
            //                   colors: [
            //                     Color(0x1EFFFFFF),
            //                     Color(0x9BFFFFFF),
            //                     Color(0xFFFFFFFF),
            //                   ], // 绿色到蓝色
            //                 ),
            //               ),
            //               SizedBox(height: 20.rpx(context),),

            //             ],
            //           ),
            //         ),
            //       ),
            //       Container(
            //         width: 200.rpx(context),
            //         height: 200.rpx(context),
            //         clipBehavior: Clip.hardEdge,
            //         decoration: BoxDecoration(
            //           borderRadius: BorderRadius.circular(40.rpx(context)),
            //         ),
            //         child: Image.asset(
            //           width: double.infinity,
            //           height: double.infinity,
            //           'assets/images/c1bada93f68fccc2.jpg',
            //           fit: BoxFit.cover,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            SizedBox(height: 20.rpx(context)),
            // 歌曲列表
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _tracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.music_note,
                            color: Colors.white38,
                            size: 80.rpx(context),
                          ),
                          SizedBox(height: 20.rpx(context)),
                          Text(
                            '暂无歌曲',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 28.rpx(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.only(bottom: 120.rpx(context)),
                      itemCount: _tracks.length,
                      onReorder: (oldIndex, newIndex) async {
                        // 处理歌单列表的重新排序
                        try {
                          // 保存当前播放的歌曲信息和进度
                          final currentFileId =
                              _playerController.currentPlayingFileId;
                          final wasPlaying = _playerController.isPlaying.value;
                          final currentPosition =
                              _playerController.progress.value; // 保存播放进度（秒）

                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final element = _tracks.removeAt(oldIndex);
                            _tracks.insert(newIndex, element);
                          });

                          // 更新歌单服务中的顺序
                          if (widget.playlistId != null) {
                            await _playlistService.updatePlaylistOrder(
                              widget.playlistId!,
                              _tracks,
                            );
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            print('❌ onReorder 错误: $e');
                          }
                        }
                      },
                      buildDefaultDragHandles: false,
                      proxyDecorator:
                          (
                            Widget child,
                            int index,
                            Animation<double> animation,
                          ) {
                            return Material(
                              color: Colors.transparent,
                              child: child,
                            );
                          },
                      itemBuilder: (context, index) {
                        // 添加索引安全检查
                        if (index < 0 || index >= _tracks.length) {
                          if (kDebugMode) {
                            print(
                              '⚠️ itemBuilder: 索引超出范围: index=$index, tracks.length=${_tracks.length}',
                            );
                          }
                          return Container(); // 返回空容器作为占位符
                        }

                        final track = _tracks[index];
                        return Container(
                          key: ValueKey(
                            "playlist_${track['file_id'] ?? track['id'] ?? index}",
                          ),
                          child: Obx(
                            () => _buildPlaylistItem(context, index, track),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
