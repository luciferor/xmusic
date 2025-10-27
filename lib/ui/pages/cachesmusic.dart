import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:xmusic/services/favorite_service.dart';

class Cachesmusic extends StatefulWidget {
  const Cachesmusic({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CachesmusicState createState() => _CachesmusicState();
}

class _CachesmusicState extends State<Cachesmusic> {
  final playerController = Get.find<PlayerUIController>();
  List<Map<String, dynamic>> cachedTracks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedTracks();
  }

  Future<void> _loadCachedTracks() async {
    try {
      setState(() {
        isLoading = true;
      });

      final cachedFiles = await playerController.getCachedAudioFiles();
      final tracks = <Map<String, dynamic>>[];

      for (final file in cachedFiles) {
        final fileName = file['fileName'] as String? ?? '';
        final fileId = file['fileId'] as String? ?? '';

        if (fileId.isNotEmpty) {
          // 从播放列表中查找对应的歌曲信息
          final playlistTrack = playerController.playlist.firstWhereOrNull(
            (track) => (track['file_id'] ?? track['id'] ?? '') == fileId,
          );

          if (playlistTrack != null) {
            // 添加文件大小信息
            playlistTrack['file_size'] = file['size'];
            tracks.add(playlistTrack);
          } else {
            // 如果没有找到对应的播放列表信息，创建一个基础信息
            final displayName = fileName.contains('-')
                ? fileName
                      .split('-')
                      .last
                      .replaceAll('.mp3', '')
                      .replaceAll('.m4a', '')
                : fileName.replaceAll('.mp3', '').replaceAll('.m4a', '');

            // 尝试从其他播放列表或历史记录中查找封面信息
            String? coverUrl = '';
            String? artist = '未知艺术家';

            // 从所有可能的播放列表中查找
            final favoriteService = Get.find<FavoriteService>();
            final allPlaylists = [
              playerController.playlist,
              favoriteService.favoriteTracks.toList(),
              // 可以添加其他播放列表
            ];

            // 首先尝试精确匹配 fileId
            for (final playlist in allPlaylists) {
              final foundTrack = playlist.firstWhereOrNull(
                (track) => (track['file_id'] ?? track['id'] ?? '') == fileId,
              );

              if (foundTrack != null) {
                coverUrl =
                    foundTrack['cover_url'] ??
                    foundTrack['cover'] ??
                    foundTrack['thumbnail'] ??
                    '';
                artist = foundTrack['artist'] ?? foundTrack['album'] ?? '未知艺术家';
                break;
              }
            }

            // 如果精确匹配失败，尝试模糊匹配标题
            if (coverUrl?.isEmpty ?? true) {
              for (final playlist in allPlaylists) {
                final foundTrack = playlist.firstWhereOrNull((track) {
                  final trackTitle = (track['title'] ?? track['name'] ?? '')
                      .toLowerCase();
                  final trackArtist = (track['artist'] ?? '').toLowerCase();
                  final searchName = displayName.toLowerCase();

                  return trackTitle.contains(searchName) ||
                      searchName.contains(trackTitle) ||
                      trackArtist.contains(searchName) ||
                      searchName.contains(trackArtist);
                });

                if (foundTrack != null) {
                  coverUrl =
                      foundTrack['cover_url'] ??
                      foundTrack['cover'] ??
                      foundTrack['thumbnail'] ??
                      '';
                  artist =
                      foundTrack['artist'] ?? foundTrack['album'] ?? '未知艺术家';
                  break;
                }
              }
            }

            tracks.add({
              'file_id': fileId,
              'id': fileId,
              'title': displayName,
              'name': displayName,
              'artist': artist,
              'cover_url': coverUrl,
              'cover': coverUrl,
              'thumbnail': coverUrl,
              'file_size': file['size'],
            });
          }
        }
      }

      setState(() {
        cachedTracks = tracks;
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载缓存歌曲失败: $e');
      }
      setState(() {
        isLoading = false;
      });
    }
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
                Expanded(child: Center()),
                SizedBox(
                  height: 60.rpx(context),
                  child: GradientText(
                    '${cachedTracks.length}',
                    style: TextStyle(
                      fontSize: 28.rpx(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.rpx(context),
                      fontFamily: 'Nufei',
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color(0x31737CFF),
                        Color(0x95737CFF),
                        Color(0xFF737CFF),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40.rpx(context)),

          // 已经缓存的歌曲列表
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.white))
                : cachedTracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.3,
                          child: Image.asset(
                            'assets/images/crash.png',
                            width: 300.rpx(context),
                          ),
                        ),
                        SizedBox(height: 30.rpx(context)),
                        GradientText(
                          '还没有缓存的音乐',
                          style: TextStyle(
                            fontSize: 32.rpx(context),
                            fontWeight: FontWeight.bold,
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
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.only(bottom: 120.rpx(context)),
                    itemCount: cachedTracks.length,
                    onReorder: (oldIndex, newIndex) async {
                      // 处理缓存列表的重新排序
                      try {
                        // 保存当前播放的歌曲信息和进度
                        final currentFileId =
                            playerController.currentPlayingFileId;
                        final wasPlaying = playerController.isPlaying.value;
                        final currentPosition =
                            playerController.progress.value; // 保存播放进度（秒）

                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final element = cachedTracks.removeAt(oldIndex);
                          cachedTracks.insert(newIndex, element);
                        });

                        // 如果播放列表不是缓存列表，先重置播放列表
                        if (!playerController.isPlaylistConsistent(
                          cachedTracks,
                        )) {
                          if (kDebugMode) {
                            print('🔄 重置播放列表为排序后的缓存列表');
                          }
                          await playerController.resetPlaylist(cachedTracks);

                          // 找到原来播放的歌曲在新列表中的位置
                          if (currentFileId != null &&
                              currentFileId.isNotEmpty) {
                            final newIndex = cachedTracks.indexWhere(
                              (track) =>
                                  (track['file_id'] ?? track['id'] ?? '') ==
                                  currentFileId,
                            );

                            if (newIndex >= 0) {
                              playerController.currentIndex.value = newIndex;
                              if (kDebugMode) {
                                print(
                                  '🔄 恢复播放位置: $currentFileId -> 索引 $newIndex',
                                );
                              }

                              // 恢复播放进度
                              if (currentPosition > 0) {
                                try {
                                  // 等待音频准备就绪
                                  await playerController.waitForAudioReady();

                                  // 音频准备就绪后，执行 seek 操作
                                  await playerController.seekTo(
                                    currentPosition,
                                  );
                                  if (kDebugMode) {
                                    print(
                                      '🔄 恢复播放进度: ${currentPosition.toStringAsFixed(1)}秒',
                                    );
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    print('❌ 恢复播放进度失败: $e');
                                  }
                                  // 即使恢复进度失败，也不影响播放
                                }
                              }

                              // 如果之前在播放，继续播放
                              if (wasPlaying) {
                                await playerController.togglePlay();
                              }
                            }
                          }
                        }
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
                      final track = cachedTracks[index];
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
                        key: ValueKey("containercached_${fileId}_$index"),
                        child: Obx(() {
                          final playingFileId =
                              playerController.currentPlayingFileId ?? '';
                          final isCurrent = fileId == playingFileId;
                          final isPlaying = playerController.isPlaying.value;

                          return SwipeActionCell(
                            key: ValueKey("cached_${fileId}_$index"),
                            backgroundColor: Colors.transparent,
                            trailingActions: <SwipeAction>[
                              SwipeAction(
                                onTap: (CompletionHandler handler) async {
                                  try {
                                    // 删除缓存文件
                                    final cachedFiles = await playerController
                                        .getCachedAudioFiles();
                                    final targetFile = cachedFiles
                                        .firstWhereOrNull(
                                          (file) =>
                                              (file['fileId'] ?? '') == fileId,
                                        );

                                    if (targetFile != null) {
                                      final success = await playerController
                                          .deleteCachedFile(
                                            targetFile['fullPath'] ?? '',
                                          );

                                      if (success) {
                                        // 从列表中移除
                                        setState(() {
                                          cachedTracks.removeAt(index);
                                        });
                                        handler(true);
                                      }
                                    }
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print('❌ 删除缓存文件失败: $e');
                                    }
                                    handler(false);
                                  }
                                },
                                widthSpace: 140.rpx(context),
                                color: Colors.transparent,
                                icon: Icon(
                                  CupertinoIcons.trash_circle,
                                  color: const Color(0x88F44336),
                                  size: 60.rpx(context),
                                ),
                              ),
                            ],
                            child: _buildCachedListItem(
                              index: index,
                              isCurrent: isCurrent,
                              coverUrl: coverUrl,
                              title: displayName,
                              artist: artist,
                              onTap: () async {
                                HapticFeedback.lightImpact();
                              },
                              context: context,
                              fileId: fileId,
                              isPlaying: playerController.isPlaying.value,
                              fileSize: cachedTracks[index]['file_size'] ?? 0,
                            ),
                          );
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 缓存列表项组件
Widget _buildCachedListItem({
  required int index,
  required bool isCurrent,
  required String coverUrl,
  required String title,
  required String artist,
  required VoidCallback? onTap,
  required BuildContext context,
  required String fileId,
  required bool isPlaying,
  required int fileSize,
}) {
  return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12.rpx(context)),
        onTap: onTap,
        child: Row(
          children: [
            // 序号
            SizedBox(
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

                  Row(
                    children: [
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
                      SizedBox(width: 5.rpx(context)),

                      // 文件大小
                      Text(
                        _formatFileSize(fileSize),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 20.rpx(context),
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
                  child: PlayerIcon(isPlaying: isPlaying, fileId: fileId),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// 格式化文件大小
String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '${bytes} B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
