import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:glossy/glossy.dart';
import 'dart:io';
import 'package:xmusic/ui/components/dialogText.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/dialog.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/neonfilter.dart';
import 'package:xmusic/ui/components/player/widget.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/pages/sliblist.dart';
import 'package:flutter/foundation.dart';
import 'package:xmusic/services/listening_stats_service.dart';

class Songlib extends StatefulWidget {
  const Songlib({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SonglibState createState() => _SonglibState();
}

class _SonglibState extends State<Songlib> {
  final PlaylistService _playlistService = Get.put(PlaylistService());
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Base(
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
                SizedBox(
                  width: 80.rpx(context),
                  height: 80.rpx(context),
                  child: IconButton(
                    iconSize: 60.rpx(context),
                    color: const Color.fromARGB(186, 86, 89, 252),
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) => XDialogTextWithCover(
                          title: '新建自定义歌单',
                          content: '',
                          hintText: '输入自定义歌单名称',
                          onCancel: () {},
                          onConfirm: (data) async {
                            if (data['name']!.isNotEmpty &&
                                data['imagePath']!.isNotEmpty) {
                              final id = await _playlistService.createPlaylist(
                                data['name']!,
                                imagePath: data['imagePath'],
                              );

                              // 调试信息：验证歌单创建结果
                              if (kDebugMode) {
                                print('🎵 歌单创建完成:');
                                print('  - 返回的歌单ID: $id');
                                final playlists = _playlistService.playlists;
                                print('  - 当前歌单总数: ${playlists.length}');
                                if (playlists.isNotEmpty) {
                                  final lastPlaylist = playlists.last;
                                  print('  - 最新歌单信息:');
                                  print('    ID: ${lastPlaylist['id']}');
                                  print('    名称: ${lastPlaylist['name']}');
                                  print(
                                    '    封面图路径: ${lastPlaylist['image_path']}',
                                  );
                                  print(
                                    '    歌曲数量: ${(lastPlaylist['tracks'] as List).length}',
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    },
                    icon: Icon(CupertinoIcons.add_circled),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40.rpx(context)),
          Expanded(
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(
                40.rpx(context),
                0,
                40.rpx(context),
                0,
              ),
              child: Obx(() {
                final lists = _playlistService.playlists;
                if (lists.isEmpty) {
                  return Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.3,
                          child: Image.asset(
                            'assets/images/empty.png',
                            width: 400.rpx(context),
                          ),
                        ),
                        SizedBox(height: 50.rpx(context)),
                        GradientText(
                          '还未创建歌单',
                          style: TextStyle(
                            fontSize: 36.rpx(context),
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
                        SizedBox(height: 40.rpx(context)),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            horizontal: 200.rpx(context),
                          ),
                          child: GradientButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => XDialogTextWithCover(
                                  title: '新建自定义歌单',
                                  content: '',
                                  hintText: '输入自定义歌单名称',
                                  onCancel: () {},
                                  onConfirm: (data) async {
                                    if (data['name']!.isNotEmpty &&
                                        data['imagePath']!.isNotEmpty) {
                                      final id = await _playlistService
                                          .createPlaylist(
                                            data['name']!,
                                            imagePath: data['imagePath'],
                                          );

                                      // 调试信息：验证歌单创建结果
                                      if (kDebugMode) {
                                        print('🎵 歌单创建完成 (空状态):');
                                        print('  - 返回的歌单ID: $id');
                                        final playlists =
                                            _playlistService.playlists;
                                        print(
                                          '  - 当前歌单总数: ${playlists.length}',
                                        );
                                        if (playlists.isNotEmpty) {
                                          final lastPlaylist = playlists.last;
                                          print('  - 最新歌单信息:');
                                          print(
                                            '    ID: ${lastPlaylist['id']}',
                                          );
                                          print(
                                            '    名称: ${lastPlaylist['name']}',
                                          );
                                          print(
                                            '    封面图路径: ${lastPlaylist['image_path']}',
                                          );
                                          print(
                                            '    歌曲数量: ${(lastPlaylist['tracks'] as List).length}',
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                            gradientColors: [
                              Color.fromARGB(100, 89, 60, 255),
                              Color.fromARGB(100, 29, 71, 255),
                              Color.fromARGB(100, 0, 17, 255),
                            ],
                            padding: EdgeInsetsGeometry.symmetric(
                              vertical: 18.rpx(context),
                              horizontal: 20.rpx(context),
                            ),
                            borderRadius: 25.rpx(context),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.plus_app,
                                  color: Colors.white24,
                                  size: 35.rpx(context),
                                ),
                                SizedBox(width: 10.rpx(context)),
                                GradientText(
                                  '立即创建',
                                  style: TextStyle(
                                    fontSize: 28.rpx(context),
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
                  );
                }
                return ReorderableGridView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: lists.length,
                  padding: EdgeInsets.only(bottom: 140.rpx(context)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 40.rpx(context),
                    mainAxisSpacing: 40.rpx(context),
                    childAspectRatio: 1.5,
                  ),
                  onReorder: (oldIndex, newIndex) async {
                    await _playlistService.reorderPlaylists(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final p = lists[index];
                    final tracks =
                        (p['tracks'] as List?)?.cast<Map<String, dynamic>>() ??
                        const [];
                    return Container(
                      key: ValueKey('a_${p['id']}_$index'),
                      child: _listItem(context, tracks, p, index),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem(
    BuildContext context,
    List<Map<String, dynamic>> tracks,
    Map<String, dynamic> p,
    int index,
  ) {
    // 获取歌单封面图路径
    final playlistImagePath = p['image_path'] as String?;

    // 调试信息：打印封面图路径
    if (kDebugMode) {
      print('🎵 歌单封面信息 (_listItem):');
      print('  - 歌单ID: ${p['id']}');
      print('  - 歌单名称: ${p['name']}');
      print('  - 封面图路径: $playlistImagePath');
      print('  - 封面图路径类型: ${playlistImagePath.runtimeType}');
      print('  - 歌曲数量: ${tracks.length}');
      if (playlistImagePath != null) {
        final file = File(playlistImagePath);
        print('  - 文件是否存在: ${file.existsSync()}');
        print('  - 文件路径: ${file.absolute.path}');
      }
    }

    if (tracks.isEmpty) {
      // 没有歌曲时，优先显示歌单封面图，如果没有则显示默认图片
      return _itemsbgs(
        context,
        Stack(
          fit: StackFit.expand,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: playlistImagePath != null
                  ? FutureBuilder<bool>(
                      future: File(playlistImagePath).exists(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue[300]!,
                                ),
                              ),
                            ),
                          );
                        }

                        final fileExists = snapshot.data ?? false;
                        if (!fileExists) {
                          if (kDebugMode) {
                            print('❌ 空歌单封面图文件不存在: $playlistImagePath');
                          }
                          return Opacity(
                            opacity: 0.3,
                            child: Image.asset(
                              'assets/images/Hi-Res.png',
                              fit: BoxFit.cover,
                            ),
                          );
                        }

                        return Opacity(
                          opacity: 0.1,
                          child: NeonFilter(
                            colors: [Colors.pink, Colors.cyan, Colors.blue],
                            blendMode: BlendMode.color,
                            child: Image.file(
                              File(playlistImagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                if (kDebugMode) {
                                  print('❌ 空歌单封面图加载失败: $error');
                                }
                                return Opacity(
                                  opacity: 0.3,
                                  child: Image.asset(
                                    'assets/images/Hi-Res.png',
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    )
                  : Opacity(
                      opacity: 0.3,
                      child: NeonFilter(
                        colors: [Colors.pink, Colors.cyan, Colors.blue],
                        blendMode: BlendMode.color,
                        child: Image.asset(
                          'assets/images/Hi-Res.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsetsGeometry.all(20.rpx(context)),
                child: GradientText(
                  '${p['name']}',
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(100, 255, 255, 255),
                      Color.fromARGB(200, 255, 255, 255),
                      Color.fromARGB(255, 255, 255, 255),
                    ], // 绿色到蓝色
                  ),
                  style: TextStyle(
                    fontSize: 28.rpx(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.rpx(context),
              right: 10.rpx(context),
              child: Text(
                '${tracks.length} ',
                style: TextStyle(
                  color: const Color.fromARGB(30, 207, 255, 197),
                  fontSize: 36.rpx(context),
                  fontFamily: 'Mango',
                ),
              ),
            ),
          ],
        ),
        EdgeInsets.all(0.rpx(context)),
        double.infinity,
        double.infinity,
        40.rpx(context),
        p,
        () {
          if (tracks.isNotEmpty) {
            HapticFeedback.lightImpact();
            Get.toNamed('/songlist');
          }
        },
      );
    }

    final track = tracks[0];
    final fileId = track['file_id'] ?? track['id'] ?? '';

    String displayName = track['title'] ?? track['name'] ?? '';
    if (displayName.isEmpty || displayName == track['name']) {
      displayName = track['name'] ?? '';
      if (displayName.contains('.')) {
        displayName = displayName.substring(0, displayName.lastIndexOf('.'));
      }
    }

    // 优先使用歌单封面图，如果没有则使用第一首歌的封面图
    final coverUrl = playlistImagePath != null
        ? null
        : (track['cover_url'] ?? track['cover'] ?? track['thumbnail'] ?? '');

    return Bounceable(
      onLongPress: () => showBottomSheet(context, p),
      onTap: () {
        if (tracks.isNotEmpty) {
          HapticFeedback.lightImpact();
          Get.to(
            () => PageWithPlayer(
              child: Sliblist(playlistId: p['id'], playlistName: p['name']),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.all(2.rpx(context)),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(40.rpx(context)),
        ),
        child: Stack(
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38.rpx(context)),
              ),
              child: playlistImagePath != null
                  ? FutureBuilder<bool>(
                      future: File(playlistImagePath).exists(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(
                                38.rpx(context),
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue[300]!,
                                ),
                              ),
                            ),
                          );
                        }

                        final fileExists = snapshot.data ?? false;
                        if (!fileExists) {
                          // 文件不存在，显示默认图片
                          if (kDebugMode) {
                            print('❌ 封面图文件不存在: $playlistImagePath');
                          }
                          return Image.asset(
                            'assets/images/Hi-Res.png',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          );
                        }

                        // 文件存在，显示封面图
                        return NeonFilter(
                          colors: [Colors.pink, Colors.cyan, Colors.blue],
                          blendMode: BlendMode.color,
                          child: Image.file(
                            File(playlistImagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              if (kDebugMode) {
                                print('❌ 封面图加载失败: $error');
                              }
                              // 如果封面图加载失败，尝试使用默认图片
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(
                                    38.rpx(context),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.grey[600],
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '封面加载失败',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  : coverUrl.isNotEmpty
                  ? CachedImage(
                      imageUrl: coverUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.music_note,
                          color: Colors.grey[600],
                          size: 30,
                        ),
                      ),
                      errorWidget: Image.asset(
                        'assets/images/Hi-Res.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      cacheKey: fileId,
                    )
                  : Image.asset(
                      'assets/images/Hi-Res.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),

            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsetsGeometry.all(20.rpx(context)),
                child: GradientText(
                  '${p['name']}',
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(100, 255, 255, 255),
                      Color.fromARGB(200, 255, 255, 255),
                      Color.fromARGB(255, 255, 255, 255),
                    ], // 绿色到蓝色
                  ),
                  style: TextStyle(
                    fontSize: 28.rpx(context),
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        // 轻微下投影
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.rpx(context),
              right: 10.rpx(context),
              child: Text(
                '${tracks.length} ',
                style: TextStyle(
                  color: const Color.fromARGB(200, 231, 255, 226),
                  fontSize: 36.rpx(context),
                  fontFamily: 'Mango',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsbgs(
    BuildContext context,
    Widget childl,
    EdgeInsets padding,
    double width,
    double height,
    double radius,
    Map<String, dynamic> p,
    VoidCallback callback,
  ) {
    return Bounceable(
      onLongPress: () => showBottomSheet(context, p),
      onTap: () {
        // 添加点击反馈
        HapticFeedback.lightImpact();
        callback();
      },
      child: GlossyContainer(
        width: width,
        height: height,
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
          opacity: 0.2,
        ),
        border: BoxBorder.all(
          color: const Color.fromARGB(100, 255, 255, 255),
          width: 1.rpx(context),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(0, 168, 154, 154),
            blurRadius: 30.rpx(context),
          ),
        ],
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: childl,
        ),
      ),
    );
  }

  void showBottomSheet(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlossyContainer(
          width: double.infinity,
          height: 350.rpx(context),
          padding: EdgeInsets.symmetric(
            horizontal: 150.rpx(context),
            vertical: 50.rpx(context),
          ),
          strengthX: 7,
          strengthY: 5,
          gradient: GlossyLinearGradient(
            colors: [
              Color.fromARGB(146, 59, 59, 59),
              Color.fromARGB(146, 39, 39, 39),
              Color.fromARGB(7, 34, 34, 34),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            opacity: 0.0,
          ),
          border: BoxBorder.all(
            color: const Color.fromARGB(0, 255, 255, 255),
            width: 0.rpx(context),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(0, 168, 154, 154),
              blurRadius: 30.rpx(context),
            ),
          ],
          // borderRadius: BorderRadius.only(
          //   topLeft: Radius.circular(60.rpx(context)),
          //   topRight: Radius.circular(60.rpx(context)),
          // ),
          borderRadius: BorderRadius.circular(50.rpx(context)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30.rpx(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Bounceable(
                      onTap: () async {
                        Navigator.pop(context); // 关闭底部弹窗
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (_) => XDialogTextWithCover(
                            title: '修改歌单',
                            content: p['name'] ?? '',
                            hintText: '输入新名称',
                            currentImagePath: p['image_path'], // 传入当前封面图路径
                            onCancel: () {},
                            onConfirm: (data) async {
                              if (data['name']!.isNotEmpty &&
                                  data['imagePath']!.isNotEmpty) {
                                // 更新歌单名称和封面图
                                await _playlistService.renamePlaylist(
                                  p['id'],
                                  data['name']!,
                                );
                                // 更新封面图
                                await _playlistService.updatePlaylistCover(
                                  p['id'],
                                  data['imagePath']!,
                                );
                              }
                            },
                          ),
                        );
                      },
                      child: Container(
                        height: 70.rpx(context),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 56, 75, 248),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20.rpx(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70.rpx(context),
                              height: 70.rpx(context),
                              child: Icon(
                                CupertinoIcons.pencil_outline,
                                size: 30.rpx(context),
                                color: Colors.white60,
                              ),
                            ),
                            Text('编辑', style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    Bounceable(
                      onTap: () async {
                        // 关闭底部弹窗
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
                          barrierLabel: "Custom3DDialog",
                          barrierColor: Colors.black38,
                          transitionDuration: Duration(milliseconds: 600),
                          pageBuilder:
                              (context, animation, secondaryAnimation) {
                                return XDialog(
                                  title: '删除歌单',
                                  content: '确认删除「${p['name']}」吗？该操作不可撤销。',
                                  confirmText: '确认',
                                  cancelText: '取消',
                                  onCancel: () {},
                                  onConfirm: () async {
                                    await _playlistService.deletePlaylist(
                                      p['id'],
                                    );
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(context);
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
                        height: 70.rpx(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color.fromARGB(255, 255, 26, 26),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20.rpx(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('删除', style: TextStyle(color: Colors.white60)),
                            SizedBox(
                              width: 70.rpx(context),
                              height: 70.rpx(context),
                              child: Icon(
                                CupertinoIcons.trash,
                                color: Colors.white60,
                                size: 30.rpx(context),
                              ),
                            ),
                            SizedBox(width: 10.rpx(context)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.rpx(context)),
                    Bounceable(
                      onTap: () async {
                        // 关闭底部弹窗
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 70.rpx(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(137, 196, 196, 196),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20.rpx(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70.rpx(context),
                              height: 70.rpx(context),
                              child: Icon(
                                CupertinoIcons.clear_circled,
                                color: Colors.white60,
                                size: 30.rpx(context),
                              ),
                            ),
                            Text('取消', style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
