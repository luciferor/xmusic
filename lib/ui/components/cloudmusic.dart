import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:glossy/glossy.dart';
import 'package:like_button/like_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmusic/app.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:xmusic/services/down_progress_service.dart';
import 'package:xmusic/services/favorite_service.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:xmusic/ui/components/add_to_playlist_sheet.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/playicon.dart';
import 'package:xmusic/ui/components/rpx.dart';

// 统一的文件工具类
class FileUtils {
  // 统一获取文件ID
  static String getFileId(Map<String, dynamic> file) {
    return file['file_id']?.toString() ??
        file['fileId']?.toString() ??
        file['id']?.toString() ??
        '';
  }

  // 统一生成缓存文件名
  static String getCacheFileName(String fileId, String fileName) {
    // 清理文件名中的特殊字符
    final cleanFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return '$fileId-$cleanFileName';
  }

  // 检查是否为无损格式
  static bool isLossless(String? ext) {
    final lossless = ['flac', 'wav', 'ape', 'alac'];
    return ext != null && lossless.contains(ext.toLowerCase());
  }
}

// 删除 DownloadState、DownloadManager 类及相关静态变量和方法

class CloudMusicList extends StatefulWidget {
  const CloudMusicList({super.key});

  @override
  State<CloudMusicList> createState() => _CloudMusicListState();
}

class _CloudMusicListState extends State<CloudMusicList>
    with RouteAware, AutomaticKeepAliveClientMixin {
  final playerController = Get.find<PlayerUIController>();
  final aliyunDriveService = AliyunDriveService();

  @override
  bool get wantKeepAlive => true;

  bool _isAuthorized = false;
  Map<String, dynamic>? _driveInfo;
  bool _isLoading = true;

  // 文件列表相关状态
  final RxList<Map<String, dynamic>> _fileList = <Map<String, dynamic>>[].obs;
  final RxBool _isLoadingFiles = false.obs;
  String _currentFolderId = 'root';
  String _currentFolderName = '备份盘';

  Map<String, dynamic>? _userInfo;

  // 本地缓存文件ID集合
  Set<String> _cachedFileIds = {};
  int cacheLength = 0;

  // 新增：防重复预加载机制
  final Set<String> _preloadedCoverUrls = <String>{};
  bool _isPreloadingCovers = false;

  // 在类成员变量区添加：
  List<Map<String, String>> _folderStack = [];

  // 页面显示状态跟踪
  bool _hasShown = false;

  List<Map<String, dynamic>> audioFilesBak = [];

  @override
  void initState() {
    try {
      super.initState();
      _checkAuthorizationStatus();
      _loadUserInfo();
      // 延迟加载缓存文件ID，确保playerController已初始化
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _loadCachedFileIds();
        } catch (e) {
          if (kDebugMode) {
            print('❌ _loadCachedFileIds 错误: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ CloudMusicList initState 错误: $e');
      }
    }
    if (playerController.playlist.isEmpty) {
      initPlaylistFav();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 订阅路由观察者
    routeObserver.subscribe(this, ModalRoute.of(context)!);

    // 检查是否是首次显示或重新显示
    if (!_hasShown) {
      _hasShown = true;
      _onFirstShow();
    } else {
      _onShow();
    }
  }

  @override
  void dispose() {
    // 取消订阅路由观察者
    routeObserver.unsubscribe(this);
    // 删除所有 _downloadStatus.clear()、_downloadProgress.clear() 调用
    super.dispose();
  }

  // 首次显示时调用
  void _onFirstShow() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 首次显示${_fileList.isEmpty}---${_fileList.length}');
    }
    // 首次显示时的逻辑，通常已经在 initState 中处理
    // if (_fileList.isEmpty) {
    //   //延迟3秒执行
    //   Future.delayed(Duration(seconds: 3), () {
    //     print('xxxxxxxxxxxxx>>>>>>>>>>>>>>>>>');
    //     _checkAuthorizationStatus();
    //   });
    // }
  }

  // 每次显示时调用（类似 onShow）
  void _onShow() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 页面显示');
    }
    // 如果已授权且有文件列表，同步播放列表
    // playerController.resetPlaylist(audioFilesBak);
    // 重新检查授权并刷新列表
  }

  // RouteAware 方法 - 当路由变为当前路由时调用
  @override
  void didPushNext() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 路由推入下一个页面');
    }
  }

  // RouteAware 方法 - 当路由变为当前路由时调用
  @override
  void didPopNext() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 从其他页面返回');
    }
    // 从其他页面返回时，调用 onShow
    _onShow();
  }

  // RouteAware 方法 - 当路由被移除时调用
  @override
  void didPop() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 路由被移除');
    }
  }

  // RouteAware 方法 - 当路由被推入时调用
  @override
  void didPush() {
    if (kDebugMode) {
      print('🎵 CloudMusicList 路由被推入');
    }
  }

  // 将我喜欢的歌曲读出来并同步到播放列表（无返回值）
  Future<void> initPlaylistFav() async {
    try {
      final favoriteService = Get.find<FavoriteService>();
      // 确保已加载
      await favoriteService.loadFavorites();
      final favorites = favoriteService.favoriteTracks.toList();
      if (favorites.isNotEmpty) {
        await playerController.resetPlaylist(favorites);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ initPlaylistFav 读取失败: $e');
      }
    }
  }

  Future<void> _checkAuthorizationStatus() async {
    try {
      final isAuthorized = await aliyunDriveService.isAuthorized();
      print('xxxxxxxxxxxxxxxxxxx${isAuthorized}');
      final driveInfo = aliyunDriveService.driveInfo;
      print('yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy${driveInfo}');
      setState(() {
        _isAuthorized = isAuthorized;
        _driveInfo = driveInfo;
        _isLoading = false;
      });

      if (isAuthorized) {
        // 获取文件列表
        await _loadFileList();
      } else {
        // 显示提示信息
        Fluttertoast.showToast(
          msg: '请先登录阿里云盘',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        );
        // 延迟跳转到登录页面
        Future.delayed(Duration(milliseconds: 1500), () {
          Get.offAllNamed('/login');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 出错时也跳转到登录页面
      Future.delayed(Duration(milliseconds: 500), () {
        Get.offAllNamed('/login');
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('aliyun_user_info');
    if (userInfoString != null) {
      setState(() {
        _userInfo = json.decode(userInfoString);
      });
    }
  }

  Future<void> _loadCachedFileIds() async {
    try {
      final cachedFiles = await playerController.getCachedAudioFiles();

      // 修正：如果 fileId 为空，尝试用文件名前缀提取
      int ccount = 0;
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
          ccount++;
        }
      }

      setState(() {
        _cachedFileIds = ids;
        cacheLength = ccount;
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

  // 获取文件列表
  Future<void> _loadFileList() async {
    if (!_isAuthorized) {
      return;
    }

    _isLoadingFiles.value = true;

    try {
      final fileListData = await aliyunDriveService.getFileList(
        parentFileId: _currentFolderId,
        limit: 100,
      );

      if (fileListData != null) {
        if (kDebugMode) {
          print('------------------------------fileListData = $fileListData');
        }
        final items = fileListData['items'] as List<dynamic>? ?? [];

        final files = items.map((item) {
          final file = Map<String, dynamic>.from(item);

          // 自动补全 cover/cover_url 字段（无论嵌套多深）
          String? coverUrl;
          String? artist;
          String? album;
          String? title;

          try {
            final videoPreviewMetadata =
                file['video_preview_metadata'] as Map<String, dynamic>?;
            if (videoPreviewMetadata != null) {
              final audioMusicMeta =
                  videoPreviewMetadata['audioMusicMeta']
                      as Map<String, dynamic>?;
              if (audioMusicMeta != null) {
                // 提取封面
                coverUrl = audioMusicMeta['coverUrl'] as String?;
                if (coverUrl != null && coverUrl.isNotEmpty) {
                  file['cover_url'] = coverUrl;
                  file['cover'] = coverUrl;
                }

                // 提取艺术家信息
                artist = audioMusicMeta['artist'] as String?;
                if (artist != null && artist.isNotEmpty) {
                  file['artist'] = artist;
                }

                // 提取专辑信息
                album = audioMusicMeta['album'] as String?;
                if (album != null && album.isNotEmpty) {
                  file['album'] = album;
                }

                // 提取标题信息
                title = audioMusicMeta['title'] as String?;
                if (title != null && title.isNotEmpty) {
                  file['title'] = title;
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ 提取audioMusicMeta失败: $e');
            }
          }

          // 兜底补全其它可能字段
          coverUrl =
              coverUrl ??
              file['cover_url'] ??
              file['cover'] ??
              file['thumbnail'] ??
              file['icon'] ??
              file['picUrl'] ??
              '';
          file['cover_url'] = coverUrl;
          file['cover'] = coverUrl;

          // 兜底补全艺术家和专辑信息
          if (artist == null || artist.isEmpty) {
            artist = file['artist'] ?? '';
          }
          if (album == null || album.isEmpty) {
            album = file['album'] ?? '';
          }
          if (title == null || title.isEmpty) {
            title = file['title'] ?? file['name'] ?? '';
          }

          // 确保字段存在
          file['artist'] = artist;
          file['album'] = album;
          file['title'] = title;

          return file;
        }).toList();

        _fileList.value = files;
        _isLoadingFiles.value = false;

        // 新增：同步controller.playlist为当前云盘音乐列表
        final audioFiles = files.where((f) => f['type'] != 'folder').toList();
        if (kDebugMode) {
          print(
            'xxxxxxxx------------------------------audioFiles = ${audioFiles.length}',
          );
        }
        if (audioFiles.isNotEmpty) {
          audioFilesBak = audioFiles;
          // playerController.resetPlaylist(audioFiles);
        }
        // 新增：文件列表加载完成后刷新缓存文件ID（只在数量变化时打印）
        _refreshCachedFileIds();

        // 新增：预加载封面图片
        _preloadCoverImages(files);
      } else {
        _fileList.value = [];
        _isLoadingFiles.value = false;
      }
    } catch (e) {
      _isLoadingFiles.value = false;

      // 新增：网络失败时用本地缓存音频文件填充
      final cachedFiles = await playerController.getCachedAudioFiles();
      if (cachedFiles.isNotEmpty) {
        final files = <Map<String, dynamic>>[];
        for (final f in cachedFiles) {
          final cover = await playerController.getBestCoverPath({
            'file_id': f['fileId'],
            'title': f['fileName'],
          });
          files.add({
            'file_id': f['fileId'],
            'title': f['fileName'],
            'artist': '暂无', // 本地无，留空
            'album': '暂无', // 本地无，留空
            'cover_url': cover, // 本地无，留空
            'cover': cover, // 本地无，留空
            'path': f['fullPath'],
            'size': f['size'],
          });
        }
        _fileList.value = files;
        playerController.resetPlaylist(files);
        Fluttertoast.showToast(
          msg: '无网络，已加载本地缓存音频',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        );
        return;
      }

      Fluttertoast.showToast(
        msg: '获取文件列表失败: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    }
  }

  // 进入文件夹
  void _enterFolder(String folderId, String folderName) {
    _folderStack.add({'id': _currentFolderId, 'name': _currentFolderName});
    setState(() {
      _currentFolderId = folderId;
      _currentFolderName = folderName;
    });
    _loadFileList();
  }

  // 返回上级目录
  void _goBack() {
    // 添加点击反馈
    HapticFeedback.lightImpact();
    if (_folderStack.isNotEmpty) {
      final last = _folderStack.removeLast();
      setState(() {
        _currentFolderId = last['id']!;
        _currentFolderName = last['name']!;
      });
      _loadFileList();
    }
  }

  bool isPlaylistSame(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (FileUtils.getFileId(a[i]) != FileUtils.getFileId(b[i])) return false;
    }
    return true;
  }

  // 新增：定期刷新缓存文件ID
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20.rpx(context)),
            Text(
              '正在检查登录状态...',
              style: TextStyle(color: Colors.white, fontSize: 28.rpx(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 文件夹导航栏
        if (_isAuthorized)
          Container(
            height: 80.rpx(context),
            margin: EdgeInsets.fromLTRB(
              40.rpx(context),
              20.rpx(context),
              40.rpx(context),
              0.rpx(context),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.rpx(context)),
            ),
            padding: EdgeInsets.all(0),
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
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_currentFolderId != 'root')
                      Container(
                        margin: EdgeInsets.fromLTRB(
                          20.rpx(context),
                          0.rpx(context),
                          10.rpx(context),
                          0.rpx(context),
                        ),
                        width: 40.rpx(context),
                        height: 40.rpx(context),
                        child: GestureDetector(
                          onTap: _goBack,
                          child: Icon(
                            CupertinoIcons.chevron_back,
                            color: Colors.white12,
                            size: 40.rpx(context),
                          ),
                        ),
                      ),
                    if (_currentFolderId == 'root')
                      Container(
                        margin: EdgeInsets.fromLTRB(
                          20.rpx(context),
                          0.rpx(context),
                          10.rpx(context),
                          0.rpx(context),
                        ),
                        width: 40.rpx(context),
                        height: 40.rpx(context),
                        child: Icon(
                          CupertinoIcons.cloud,
                          color: Colors.white12,
                          size: 40.rpx(context),
                        ),
                      ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _goBack,
                        child: GradientText(
                          _currentFolderName,
                          style: TextStyle(
                            fontSize: 30.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Color.fromARGB(30, 241, 245, 255),
                              Color.fromARGB(199, 142, 171, 243),
                              Color.fromARGB(255, 169, 192, 248),
                            ], // 绿色到蓝色
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _checkAuthorizationStatus,
                      child: Obx(
                        () => GradientText(
                          _fileList.length.toString(),
                          style: TextStyle(
                            color: Colors.white54,
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
                            ], // 绿色到蓝色
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        SizedBox(height: 20.rpx(context)),

        // 文件列表
        if (_isAuthorized)
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0.rpx(context)),
              child: Obx(() {
                try {
                  final playlist = playerController.playlist;
                  final currentIdx = playerController.currentIndex.value;
                  String? playingFileId;
                  // 更可靠的播放文件ID获取逻辑
                  if (currentIdx >= 0 && currentIdx < playlist.length) {
                    playingFileId = FileUtils.getFileId(playlist[currentIdx]);
                  } else {
                    // 如果索引无效，尝试从播放器状态获取当前播放的歌曲
                    playingFileId = null;
                    // }
                    // 如果播放器正在播放，尝试从播放列表中找到匹配的歌曲
                    if (playerController.isPlaying.value &&
                        playlist.isNotEmpty) {
                      // 遍历播放列表，找到当前正在播放的歌曲
                      for (int i = 0; i < playlist.length; i++) {
                        final track = playlist[i];
                        final trackFileId = FileUtils.getFileId(track);
                        // 这里可以添加更多的匹配逻辑，比如检查歌曲名称等
                        if (trackFileId.isNotEmpty) {
                          playingFileId = trackFileId;
                          break;
                        }
                      }
                    }
                  }
                  if (_isLoadingFiles.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          SizedBox(height: 20.rpx(context)),
                          Text(
                            '正在加载文件...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28.rpx(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (_fileList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.3,
                            child: Image.asset(
                              'assets/images/empty.png',
                              width: 400.rpx(context),
                              height: 400.rpx(context),
                            ),
                          ),
                          SizedBox(height: 30.rpx(context)),
                          GradientText(
                            '文件夹为空',
                            style: TextStyle(fontSize: 42.rpx(context)),
                            gradient: LinearGradient(
                              colors: [
                                Color(0xC7FFFFFF),
                                Color(0x63FFFFFF),
                                Color(0x09FFFFFF),
                              ], // 绿色到蓝色
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Obx(() {
                    // 监听下载进度变化
                    final progressService = DownProgressService();
                    progressService.downloadProgress; // 触发响应式更新
                    return ListView.builder(
                      padding: EdgeInsets.only(bottom: 120.rpx(context)),
                      itemCount: _fileList.length,
                      physics: BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final file = _fileList[index];
                        final fileId = FileUtils.getFileId(file);
                        final isFolder = file['type'] == 'folder';
                        // 更可靠的播放状态检测
                        bool isCurrent = false;
                        if (!isFolder && fileId.isNotEmpty) {
                          // 只要 fileId == playingFileId 就是当前播放项
                          if (fileId == playingFileId) {
                            isCurrent = true;
                          }
                        }

                        final ext =
                            (file['extension'] ??
                                    (file['name']?.toString().split('.').last ??
                                        ''))
                                .toLowerCase();
                        final isCached = _cachedFileIds.contains(fileId);
                        final isLosslessFile = FileUtils.isLossless(ext);
                        String displayName =
                            file['title'] ?? file['name'] ?? '';
                        if (displayName.isEmpty ||
                            displayName == file['name']) {
                          displayName = file['name'] ?? '';
                          if (displayName.contains('.')) {
                            displayName = displayName.substring(
                              0,
                              displayName.lastIndexOf('.'),
                            );
                          }
                        }
                        final fileSize = file['size'] as int? ?? 0;
                        String sizeStr = fileSize > 0
                            ? ('${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB')
                            : '';

                        // 获取下载进度
                        double downloadProgress = 0.0;
                        final realTimeProgress = progressService.getProgress(
                          fileId,
                        );
                        if (realTimeProgress > 0.0) {
                          downloadProgress = realTimeProgress;
                        }

                        // 进度到100%时自动刷新缓存ID
                        if (downloadProgress >= 1.0 &&
                            !_cachedFileIds.contains(fileId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _refreshCachedFileIds();
                          });
                        }

                        if (kDebugMode && downloadProgress > 0.0) {
                          // print(
                          //   '📥 文件 $fileId 下载进度: ${(downloadProgress * 100).toInt()}%',
                          // );
                        }

                        if (isFolder) {
                          // 文件夹用简洁样式
                          return ListTile(
                            contentPadding: EdgeInsets.fromLTRB(
                              40.rpx(context),
                              0,
                              40.rpx(context),
                              0,
                            ),
                            leading: SvgPicture.asset(
                              displayName == '我的音乐' ||
                                      displayName == 'Music' ||
                                      displayName == '音乐' ||
                                      displayName == 'music' ||
                                      displayName == '歌单' ||
                                      displayName == '粤语' ||
                                      displayName == '国语' ||
                                      displayName == '摇滚' ||
                                      displayName == '超重低音' ||
                                      displayName == '我的收藏歌单'
                                  ? 'assets/images/folder-music.svg'
                                  : 'assets/images/folder-cloud.svg',
                              width: 100.rpx(context),
                              height: 100.rpx(context),
                            ),
                            title: GradientText(
                              displayName,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x78D7E0FF),
                                  Color(0xB4D7E0FF),
                                  Color(0xFFD7E0FF),
                                ], // 绿色到蓝色
                              ),
                              style: TextStyle(fontSize: 28.rpx(context)),
                            ),
                            subtitle: Text(
                              displayName == '我的音乐' ||
                                      displayName == 'Music' ||
                                      displayName == '音乐' ||
                                      displayName == 'music' ||
                                      displayName == '歌单' ||
                                      displayName == '粤语' ||
                                      displayName == '国语' ||
                                      displayName == '摇滚' ||
                                      displayName == '超重低音' ||
                                      displayName == '我的收藏歌单'
                                  ? '音频'
                                  : '数据',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 24.rpx(context),
                              ),
                            ),
                            trailing: Icon(
                              CupertinoIcons.chevron_forward,
                              color: Colors.white60,
                              size: 40.rpx(context),
                            ),
                            onTap: () {
                              // 添加点击反馈
                              HapticFeedback.lightImpact();
                              _enterFolder(
                                file['file_id'] as String,
                                displayName,
                              );
                            },
                          );
                        } else {
                          String? tag;
                          if (isLosslessFile) {
                            tag = '无损';
                          } else if (ext == 'mp3') {
                            tag = 'MP3';
                          } else if (ext == 'aac') {
                            tag = 'AAC';
                          } else if (ext == 'ogg') {
                            tag = 'OGG';
                          } else if (ext == 'm4a') {
                            tag = 'M4A';
                          } else if (file['category'] == 'audio') {
                            tag = 'SQ';
                          }
                          return Obx(() {
                            final progress = DownProgressService().getProgress(
                              fileId,
                            );
                            return buildCloudMusicListItem(
                              index: index,
                              isCurrent: isCurrent,
                              coverUrl:
                                  file['cover_url'] ?? file['thumbnail'] ?? '',
                              title: displayName,
                              artist: file['artist']?.isNotEmpty == true
                                  ? file['artist']
                                  : (file['album']?.isNotEmpty == true
                                        ? file['album']
                                        : '未知艺术家'),
                              tag: tag,
                              isCached: isCached,
                              fileSizeStr: sizeStr,
                              onTap: () async {
                                int i = 0;
                                // 添加点击反馈
                                HapticFeedback.lightImpact();
                                if (!playerController.isPlaylistConsistent(
                                  _fileList,
                                )) {
                                  //这里需要过滤掉文件夹 file['type'] == 'folder';
                                  final audioFiles = _fileList
                                      .where((file) => file['type'] != 'folder')
                                      .toList();
                                  playerController.resetPlaylist(audioFiles);
                                  //这里我需要重新拿到不包含文件夹的列表的当前索引
                                  i = audioFiles.indexWhere(
                                    (audioFile) =>
                                        FileUtils.getFileId(audioFile) ==
                                        fileId,
                                  );
                                  if (i == -1) i = 0;
                                } else {
                                  i = index;
                                }
                                // await playerController.onMusicItemTap(index);
                                await playerController.onMusicItemTap(i);
                              },
                              onMV: () {},
                              context: context,
                              fileId: fileId, // 新增：传递fileId用于显示错误信息
                              downloadProgress: progress, // 新增：传递下载进度
                              isPlaying:
                                  playerController.isPlaying.value, //当前的播放状态
                              file: file, // 新增：传递完整的文件信息
                              onLongPress: () async {
                                await showAddToPlaylistSheet(
                                  context,
                                  track: file,
                                );
                              },
                            );
                          });
                        }
                      },
                    );
                  });
                } catch (e, stack) {
                  if (kDebugMode) {
                    print('❌ Obx cloudmusic catch error: $e\n$stack');
                  }
                  return Center(
                    child: Text(
                      'CloudMusic Obx error: $e',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
              }),
            ),
          )
        else
          // 未授权时显示提示
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    size: 80.rpx(context),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  Text(
                    '请先登录阿里云盘',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontSize: 32.rpx(context),
                    ),
                  ),
                  SizedBox(height: 20.rpx(context)),
                  ElevatedButton(
                    onPressed: () {
                      Get.offAllNamed('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.rpx(context)),
                      ),
                    ),
                    child: Text('去登录'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 新增：预加载封面图片（使用fileId作为cacheKey）
  void _preloadCoverImages(List<Map<String, dynamic>> files) {
    try {
      // 防止重复预加载
      if (_isPreloadingCovers) {
        if (kDebugMode) {
          print('⭐️ 封面预加载正在进行中，跳过重复请求 ⭐️');
        }
        return;
      }

      final coverUrls = <String>[];
      final cacheKeys = <String>[];

      for (final file in files) {
        final coverUrl = file['cover_url'] ?? file['cover'] ?? '';
        final fileId = FileUtils.getFileId(file);

        if (coverUrl.isNotEmpty &&
            coverUrl.startsWith('http') &&
            fileId.isNotEmpty &&
            !_preloadedCoverUrls.contains(coverUrl)) {
          coverUrls.add(coverUrl);
          cacheKeys.add(fileId);
        }
      }

      if (coverUrls.isNotEmpty) {
        if (kDebugMode) {
          print('⭐️ 开始预加载 ${coverUrls.length} 张新封面图片（使用fileId作为cacheKey）⭐️');
        }
        _isPreloadingCovers = true;

        // 在后台预加载，使用fileId作为cacheKey
        unawaited(_preloadCoversInBackground(coverUrls, cacheKeys));
      } else {
        if (kDebugMode) {
          print('⭐️ 所有封面图片已预加载，无需重复处理 ⭐️');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 预加载封面图片失败: $e');
      }
      _isPreloadingCovers = false;
    }
  }

  // 新增：后台预加载封面图片（使用fileId作为cacheKey）
  Future<void> _preloadCoversInBackground(
    List<String> coverUrls,
    List<String> cacheKeys,
  ) async {
    try {
      // 使用ImageCacheService预加载，传入cacheKey
      final imageCacheService = ImageCacheService();
      for (int i = 0; i < coverUrls.length; i++) {
        final url = coverUrls[i];
        final cacheKey = cacheKeys[i];
        try {
          await imageCacheService.preloadImage(url, cacheKey: cacheKey);
          // 预加载封面成功
        } catch (e) {
          if (kDebugMode) {
            print('❌ 预加载封面失败: fileId=$cacheKey, error=$e');
          }
        }
      }

      // 标记为已预加载
      _preloadedCoverUrls.addAll(coverUrls);
      if (kDebugMode) {
        print('⭐️ 成功预加载 ${coverUrls.length} 张封面图片（使用fileId作为cacheKey）⭐️');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 后台预加载封面图片失败: $e');
      }
    } finally {
      _isPreloadingCovers = false;
    }
  }
}

// 修改 buildCloudMusicListItem 组件参数和实现，支持 tag 和 fileSizeStr
Widget buildCloudMusicListItem({
  required int index,
  required bool isCurrent,
  required String coverUrl,
  required String title,
  required String artist,
  String? tag, // 只显示一个标签
  required bool isCached,
  required String fileSizeStr,
  required VoidCallback? onTap,
  required VoidCallback? onMV,
  required VoidCallback? onLongPress,
  required BuildContext context,
  String? fileId, // 新增：文件ID用于显示错误信息
  double downloadProgress = 0.0, // 新增：下载进度\
  bool isPlaying = false,
  Map<String, dynamic>? file, // 新增：完整的文件信息
}) {
  return Container(
    margin: EdgeInsets.only(left: 40.rpx(context), right: 40.rpx(context)),
    child: Stack(
      children: [
        // 进度边框CustomPaint，和Container外框100%重合
        if (downloadProgress > 0.0)
          Positioned.fill(
            child: CustomPaint(
              painter: ProgressBorderPainter(
                progress: downloadProgress,
                borderWidth: 3.rpx(context),
                borderRadius: 40.rpx(context),
              ),
            ),
          ),
        // 内容Container
        Container(
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
            onLongPress: onLongPress,
            child: Row(
              children: [
                // 序号或动效
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
                            ], // 绿色到蓝色
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
                                  ], // 绿色到蓝色
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
                                        ], // 绿色到蓝色
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
                          if (fileSizeStr.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text(
                                fileSizeStr,
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
                      child: PlayerIcon(isPlaying: isPlaying, fileId: fileId),
                    ),
                  ),
                if (!isCurrent)
                  Obx(() {
                    final favoriteService = Get.put(FavoriteService());
                    final isFavorite = favoriteService.isFavorite(fileId ?? '');
                    return SizedBox(
                      width: 60.rpx(context),
                      height: 60.rpx(context),
                      child: LikeButton(
                        onTap: (bool isLiked) async {
                          // 添加触感反馈
                          HapticFeedback.lightImpact();
                          if (file != null && fileId != null) {
                            await favoriteService.toggleFavorite(file);
                            return !isLiked; // 切换状态
                          }
                          return false;
                        },
                        padding: EdgeInsets.all(0),
                        likeCountPadding: EdgeInsets.all(0),
                        size: 60.rpx(context),
                        isLiked: isFavorite,
                        circleColor: CircleColor(
                          start: Color.fromARGB(255, 162, 0, 255),
                          end: Color.fromARGB(255, 78, 0, 204),
                        ),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Color.fromARGB(255, 109, 0, 143),
                          dotSecondaryColor: Color.fromARGB(255, 68, 0, 156),
                        ),
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            isFavorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            color: isFavorite
                                ? Colors.deepPurpleAccent
                                : Colors.grey,
                            size: 40.rpx(context),
                          );
                        },
                      ),
                      // IconButton(
                      //   icon: Icon(
                      //     isFavorite
                      //         ? CupertinoIcons.heart_fill
                      //         : CupertinoIcons.heart,
                      //     color: isFavorite ? Colors.deepPurpleAccent : Colors.white54,
                      //     size: 40.rpx(context),
                      //   ),
                      //   onPressed: () {
                      //     // 添加触感反馈
                      //     HapticFeedback.lightImpact();
                      //     if (file!.isNotEmpty) {
                      //       favoriteService.toggleFavorite(file);
                      //     }
                      //   },
                      // ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// 自定义画笔，绘制带进度的渐变边框
class ProgressBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;
  final double borderRadius;

  ProgressBorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = borderWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(borderRadius - inset),
    );
    final path = Path()..addRRect(rect);

    final metric = path.computeMetrics().first;
    final drawLength = metric.length * progress;

    final gradient = LinearGradient(
      colors: [Color(0xFFA1FF7C), Color(0x951EFBE9), Color(0x314F92FF)],
      stops: [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final extract = metric.extractPath(0, drawLength);
    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(covariant ProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}

Future<bool> isAudioCached(String fileId, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
  final path = p.join(
    cacheDir.path,
    FileUtils.getCacheFileName(fileId, fileName),
  );
  return File(path).exists();
}
