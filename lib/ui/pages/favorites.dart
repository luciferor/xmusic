import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:xmusic/services/favorite_service.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/cached_image.dart';

class Favorites extends StatefulWidget {
  const Favorites({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FavoritesState createState() => _FavoritesState();
}

class _FavoritesState extends State<Favorites> {
  final playerController = Get.find<PlayerUIController>();
  Set<String> _cachedFileIds = {};

  @override
  void initState() {
    super.initState();
    // 加载缓存文件ID
    _loadCachedFileIds();
    // 页面初始化时同步收藏列表到播放器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFavoritesToPlaylist();
    });
  }

  // 加载缓存文件ID
  Future<void> _loadCachedFileIds() async {
    try {
      final cachedFiles = await playerController.getCachedAudioFiles();

      // 修正：如果 fileId 为空，尝试用文件名前缀提取
      final Set<String> ids = {};
      for (final f in cachedFiles) {
        String? id = f['fileId'] as String?;
        if (id == null || id.isEmpty) {
          final fileName = f['fileName'] as String? ?? '';
          if (fileName.contains('-')) {
            id = fileName.split('-').first;
          }
        }
        if (id != null && id.isNotEmpty) {
          ids.add(id);
        }
      }

      setState(() {
        _cachedFileIds = ids;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ _loadCachedFileIds 错误: $e');
      }
      // 即使出错也要设置空集合，避免后续判断出错
      setState(() {
        _cachedFileIds = {};
      });
    }
  }

  // 刷新缓存文件ID
  void _refreshCachedFileIds() async {
    final newCachedFiles = await playerController.getCachedAudioFiles();
    final newCachedIds = <String>{};
    for (final f in newCachedFiles) {
      String? id = f['fileId'] as String?;
      if (id == null || id.isEmpty) {
        final fileName = f['fileName'] as String? ?? '';
        if (fileName.contains('-')) {
          id = fileName.split('-').first;
        }
      }
      if (id != null && id.isNotEmpty) {
        newCachedIds.add(id);
      }
    }

    // 只在缓存文件数量发生变化时才打印
    if (newCachedIds.length != _cachedFileIds.length) {
      if (kDebugMode) {
        print(
          '⭐️ _refreshCachedFileIds: 缓存文件ID已刷新，共 ${newCachedIds.length} 个 (之前: ${_cachedFileIds.length} 个) ⭐️',
        );
      }
    }

    setState(() {
      _cachedFileIds = newCachedIds;
    });
  }

  // 同步收藏列表到播放器
  void _syncFavoritesToPlaylist() {
    try {
      final favoriteService = Get.find<FavoriteService>();
      // 直接使用收藏的歌曲信息列表
      final favoriteTracks = favoriteService.favoriteTracks.toList();

      if (favoriteTracks.isNotEmpty) {
        // 提取所有收藏歌曲的ID
        final favoriteIds = favoriteTracks
            .map((track) => track['file_id'] ?? track['id'] ?? '')
            .toList();
        // playerController.syncPlaylistWithCurrentTrack(favoriteIds);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ _syncFavoritesToPlaylist 错误: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      child: Column(
        children: [
          // 顶部导航栏
          Container(
            padding: EdgeInsets.fromLTRB(
              40.rpx(context),
              0,
              10.rpx(context),
              0,
            ),
            width: MediaQuery.of(context).size.width,
            height: 80.rpx(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Re(),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.only(left: 0.rpx(context)),
                    alignment: Alignment.centerLeft,
                  ),
                ),

                GetX<FavoriteService>(
                  builder: (favoriteService) {
                    final favoriteCount = favoriteService.favoriteTracks.length;
                    return SizedBox(
                      height: 60.rpx(context),
                      child: GradientButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                        },
                        gradientColors: [
                          Color.fromARGB(0, 255, 255, 255),
                          Color.fromARGB(0, 255, 255, 255),
                          Color.fromARGB(0, 255, 255, 255),
                        ],
                        padding: EdgeInsetsGeometry.symmetric(
                          vertical: 0,
                          horizontal: 0,
                        ),
                        borderRadius: 40.rpx(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GradientText(
                              '$favoriteCount',
                              style: TextStyle(
                                fontSize: 28.rpx(context),
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
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 20.rpx(context)),

          // 收藏列表
          Expanded(
            child: GetX<FavoriteService>(
              builder: (favoriteService) {
                try {
                  // 直接使用收藏的歌曲信息
                  final favorites = favoriteService.favoriteTracks.toList();

                  if (favorites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/a2947a58d.png',
                            width: 500.rpx(context),
                            height: 500.rpx(context),
                          ),
                          SizedBox(height: 30.rpx(context)),
                          GradientText(
                            '还没有喜欢的音乐',
                            style: TextStyle(
                              fontSize: 38.rpx(context),
                              fontWeight: FontWeight.bold,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(10, 215, 224, 255),
                                Color.fromARGB(83, 215, 224, 255),
                                Color(0xFFD7E0FF),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    padding: EdgeInsets.only(bottom: 120.rpx(context)),
                    itemCount: favorites.length,
                    onReorder: (oldIndex, newIndex) async {
                      // 通过 FavoriteService 来管理重新排序
                      try {
                        if (kDebugMode) {
                          print(
                            '🔄 拖拽排序: oldIndex=$oldIndex, newIndex=$newIndex, length=${favorites.length}',
                          );
                        }

                        // 保存当前播放的歌曲信息和进度
                        final currentFileId =
                            playerController.currentPlayingFileId;
                        final wasPlaying = playerController.isPlaying.value;
                        final currentPosition =
                            playerController.progress.value; // 保存播放进度（秒）

                        // 处理 Flutter ReorderableListView 的特殊索引规则
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }

                        // 通过 FavoriteService 来管理重新排序
                        await favoriteService.reorderFavorites(
                          oldIndex,
                          newIndex,
                        );
                      } catch (e) {
                        if (kDebugMode) {
                          print('❌ onReorder 错误: $e');
                        }
                      }
                    },
                    buildDefaultDragHandles: false,
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                          return Material(
                            color: Colors.transparent,
                            child: child,
                          );
                        },
                    itemBuilder: (context, index) {
                      final track = favorites[index];
                      final fileId = track['file_id'] ?? track['id'] ?? '';

                      String displayName =
                          track['title'] ?? track['name'] ?? '';
                      if (displayName.isEmpty || displayName == track['name']) {
                        displayName = track['name'] ?? '';
                        if (displayName.contains('.')) {
                          displayName = displayName.substring(
                            0,
                            displayName.lastIndexOf('.'),
                          );
                        }
                      }

                      final artist = track['artist']?.isNotEmpty == true
                          ? track['artist']
                          : (track['album']?.isNotEmpty == true
                                ? track['album']
                                : '未知艺术家');

                      final coverUrl =
                          track['cover_url'] ??
                          track['cover'] ??
                          track['thumbnail'] ??
                          '';

                      return Container(
                        key: ValueKey('favorites_${fileId}_$index'),
                        child: Obx(() {
                          final playingFileId =
                              playerController.currentPlayingFileId ?? '';
                          final isCurrent = fileId == playingFileId;

                          return buildFavoriteListItem(
                            index: index,
                            isCurrent: isCurrent,
                            coverUrl: coverUrl,
                            title: displayName,
                            artist: artist,
                            onTap: () async {
                              // 添加点击反馈
                              HapticFeedback.lightImpact();
                              try {
                                if (kDebugMode) {
                                  print('🎵 点击收藏歌曲: $fileId');
                                  print('🎵 收藏列表长度: ${favorites.length}');
                                  print(
                                    '🎵 播放列表长度: ${playerController.playlist.length}',
                                  );
                                  print('🎵 歌曲信息: ${track.toString()}');
                                }

                                // 如果播放列表不是收藏列表，先重置播放列表
                                if (!playerController.isPlaylistConsistent(
                                  favorites,
                                )) {
                                  if (kDebugMode) {
                                    print('🔄 重置播放列表为收藏列表');
                                  }
                                  await playerController.resetPlaylist(
                                    favorites,
                                  );
                                }

                                // 直接使用 ListView 的索引，与云盘页面保持一致
                                if (kDebugMode) {
                                  print('🎵 使用索引: $index');
                                }

                                if (kDebugMode) {
                                  print('🎵 调用 onMusicItemTap，索引: $index');
                                  print('🎵 歌曲信息: ${track.toString()}');
                                }
                                await playerController.onMusicItemTap(index);
                              } catch (e) {
                                if (kDebugMode) {
                                  print('❌ onTap 错误: $e');
                                }
                              }
                            },
                            onRemoveFavorite: () {
                              HapticFeedback.lightImpact();
                              try {
                                favoriteService.toggleFavorite(track);
                              } catch (e) {
                                if (kDebugMode) {
                                  print('❌ onRemoveFavorite 错误: $e');
                                }
                              }
                            },
                            context: context,
                            fileId: fileId,
                            isPlaying: playerController.isPlaying.value,
                            isCached: _cachedFileIds.contains(fileId),
                            onCancelFavorties: () {
                              HapticFeedback.lightImpact();
                              try {
                                favoriteService.toggleFavorite(track);
                              } catch (e) {
                                if (kDebugMode) {
                                  print('❌ onRemoveFavorite 错误: $e');
                                }
                              }
                            },
                          );
                        }),
                      );
                    },
                  );
                } catch (e) {
                  if (kDebugMode) {
                    print('❌ GetX<FavoriteService> builder 错误: $e');
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 120.rpx(context),
                        ),
                        SizedBox(height: 30.rpx(context)),
                        GradientText(
                          '加载收藏列表时出错',
                          style: TextStyle(
                            fontSize: 32.rpx(context),
                            fontWeight: FontWeight.w500,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color(0x78D7E0FF),
                              Color(0xB4D7E0FF),
                              Color(0xFFD7E0FF),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 收藏列表项组件
Widget buildFavoriteListItem({
  required int index,
  required bool isCurrent,
  required String coverUrl,
  required String title,
  required String artist,
  required VoidCallback? onTap,
  required VoidCallback? onRemoveFavorite,
  required BuildContext context,
  required String fileId,
  required bool isPlaying,
  required bool isCached,
  required VoidCallback? onCancelFavorties,
}) {
  return Container(
    margin: EdgeInsets.only(left: 40.rpx(context), right: 40.rpx(context)),
    child: Container(
      padding: EdgeInsets.fromLTRB(
        20.rpx(context),
        20.rpx(context),
        0,
        20.rpx(context),
      ),
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
        onTap: onTap,
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

            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(30.rpx(context)),
              child: Hero(
                tag: 'tag-$fileId',
                flightShuttleBuilder:
                    (context, animation, direction, fromContext, toContext) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(30.rpx(context)),
                        child: toContext.widget,
                      );
                    },
                child: coverUrl.isNotEmpty
                    ? CachedImage(
                        imageUrl: coverUrl,
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
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
                          width: 90.rpx(context),
                          height: 90.rpx(context),
                          fit: BoxFit.cover,
                        ),
                        cacheKey: fileId,
                      )
                    : Image.asset(
                        'assets/images/Hi-Res.png',
                        width: 90.rpx(context),
                        height: 90.rpx(context),
                        fit: BoxFit.cover,
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
                              colors: isCached
                                  ? [
                                      Color.fromARGB(120, 127, 129, 253),
                                      Color.fromARGB(180, 127, 129, 253),
                                      Color.fromARGB(255, 127, 129, 253),
                                    ]
                                  : [
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

            // 播放状态或收藏按钮
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
                  child: PlayerIcon(isPlaying: isPlaying, fileId: fileId),
                ),
              ),

            Bounceable(
              onTap: onCancelFavorties,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // 确保点击区域完整命中
                child: Container(
                  width: 60.rpx(context),
                  height: 90.rpx(context),
                  alignment: Alignment.centerRight,
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: Colors.deepPurpleAccent,
                    size: 40.rpx(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
