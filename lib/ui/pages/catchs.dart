import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:xmusic/ui/components/base.dart';
import 'package:xmusic/ui/components/circle_checkbox.dart';
import 'package:xmusic/ui/components/copyright.dart';
import 'package:xmusic/ui/components/dialog.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/re.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/services/aliyun_drive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:get/get.dart';
import 'package:xmusic/services/image_cache_service.dart';
import 'package:xmusic/services/lyrics_cache_service.dart';
import 'package:xmusic/services/cache_download_manager.dart';
import 'package:xmusic/services/down_progress_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

class Catchs extends StatefulWidget {
  const Catchs({super.key});

  @override
  State<Catchs> createState() => _MineState();
}

class _MineState extends State<Catchs> {
  final aliyunDriveService = AliyunDriveService();
  Map<String, dynamic> _storedData = {};
  bool _isLoading = true;

  // 缓存管理相关状态
  List<Map<String, dynamic>> _cachedFiles = [];
  String _cacheSize = '0 B';
  bool _isLoadingCache = false;

  // 图片缓存相关状态
  String _imageCacheSize = '0 B';
  int _imageCacheCount = 0;
  bool _isLoadingImageCache = false;

  // 图片缓存统计状态
  Map<String, int> _imageCacheStats = {
    'memoryHits': 0,
    'localHits': 0,
    'networkDownloads': 0,
    'memoryCacheSize': 0,
  };

  // 歌词缓存相关状态
  String _lyricsCacheSize = '0 B';
  int _lyricsCacheCount = 0;
  bool _isLoadingLyricsCache = false;

  // 下载进度服务
  late final DownProgressService _downProgressService;
  // 在 State 类中添加字段
  StreamSubscription? _progressSub;
  StreamSubscription? _completeSub;
  DateTime? _lastProgressUpdate;
  @override
  void initState() {
    super.initState();
    _downProgressService = Get.put(DownProgressService());
    _loadStoredData();
    _loadCacheInfo();
    _loadImageCacheInfo();
    _loadLyricsCacheInfo();

    // 监听下载完成，自动刷新任务列表
    _completeSub = CacheDownloadManager().onTaskComplete.listen((
      completedTask,
    ) async {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: 1000));
      _downProgressService.getCacheTotalSize();
      _loadStoredData();
      _loadCacheInfo();
      await Future.delayed(Duration(milliseconds: 2000));
      _downProgressService.refreshCacheTasks();
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _storedData = {
          'access_token':
              '${aliyunDriveService.accessToken?.substring(0, 20) ?? ''}...',
          'user_id': prefs.getString('aliyun_user_id'),
          'user_name': prefs.getString('aliyun_user_name'),
          'user_avatar': prefs.getString('aliyun_user_avatar'),
          'user_total_size': prefs.getString('aliyun_user_total_size'),
          'user_used_size': prefs.getString('aliyun_user_used_size'),
          'drive_id': aliyunDriveService.driveId,
          'drive_info': aliyunDriveService.driveInfo,
          'space_info': aliyunDriveService.spaceInfo,
          'is_authorized': false, // 先设为 false，后面异步更新
          'raw_access_token':
              '${prefs.getString('aliyun_access_token')?.substring(0, 20) ?? ''}...',
          'raw_refresh_token':
              '${prefs.getString('aliyun_refresh_token')?.substring(0, 20) ?? ''}...',
          'raw_expires_at': prefs.getString('aliyun_expires_at'),
          'raw_drive_info': prefs.getString('aliyun_drive_info'),
          'raw_space_info': prefs.getString('aliyun_space_info'),
        };
        _isLoading = false;
      });
      // 异步检查授权状态
      final isAuthorized = await aliyunDriveService.isAuthorized();
      setState(() {
        _storedData['is_authorized'] = isAuthorized;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCacheInfo() async {
    final playerController = Get.find<PlayerUIController>();
    setState(() {
      _isLoadingCache = true;
    });

    try {
      final cachedFiles = await playerController.getCachedAudioFiles();
      // 过滤掉 .url 文件（直链元数据文件）
      final filteredCachedFiles = cachedFiles
          .where(
            (file) => !(file['fileName']?.toString().endsWith('.url') ?? false),
          )
          .toList();
      final cacheSize = await playerController.getCacheSize();

      // 修复：为每个 file 增加 sizeFormatted 和 modifiedAtFormatted 字段
      final cachedFilesWithMeta = await Future.wait(
        filteredCachedFiles.map((file) async {
          final fileStat = await File(file['fullPath']).stat();
          return {
            ...file,
            'sizeFormatted': _formatFileSize(file['size'] ?? 0),
            'modifiedAtFormatted': fileStat.modified.toString().substring(
              0,
              19,
            ),
          };
        }),
      );

      setState(() {
        _cachedFiles = cachedFilesWithMeta;
        _cacheSize = cacheSize;
        _isLoadingCache = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCache = false;
      });
    }
  }

  Future<void> _loadImageCacheInfo() async {
    final imageCacheService = ImageCacheService();
    setState(() {
      _isLoadingImageCache = true;
    });

    try {
      final cacheSize = await imageCacheService.getCacheSize();
      final cacheCount = await imageCacheService.getCacheFileCount();
      final cacheStats = imageCacheService.getCacheStats();

      setState(() {
        _imageCacheSize = cacheSize;
        _imageCacheCount = cacheCount;
        _imageCacheStats = cacheStats;
        _isLoadingImageCache = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingImageCache = false;
      });
    }
  }

  Future<void> _loadLyricsCacheInfo() async {
    final lyricsCacheService = LyricsCacheService();
    setState(() {
      _isLoadingLyricsCache = true;
    });

    try {
      final cacheSize = await lyricsCacheService.getCacheSize();
      final cacheCount = await lyricsCacheService.getCacheFileCount();

      setState(() {
        _lyricsCacheSize = cacheSize;
        _lyricsCacheCount = cacheCount;
        _isLoadingLyricsCache = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLyricsCache = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 清空所有音频缓存
  Future<void> _clearAllCache() async {
    final playerController = Get.find<PlayerUIController>();
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
      barrierLabel: "Custom3DDialog",
      barrierColor: Colors.black38,
      transitionDuration: Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return XDialog(
          title: '确认清空',
          content: '确定要清空所有音频缓存文件吗？此操作不可恢复。',
          confirmText: '确认',
          cancelText: '取消',
          onCancel: () {},
          onConfirm: () async {
            // 确认逻辑
            try {
              final success = await playerController.clearAllCachedFiles();
              if (success) {
                if (!Platform.isWindows) {
                  Fluttertoast.showToast(
                    msg: '音频缓存已清空',
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                  );
                }
                _downProgressService.getCacheTotalSize();
                _downProgressService.refreshCacheTasks();
                _loadStoredData();
                _loadCacheInfo();
                _downProgressService.audioTotalSize.value = '0Kb';
              } else {
                if (!Platform.isWindows) {
                  Fluttertoast.showToast(
                    msg: '清空音频缓存失败',
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                  );
                }
              }
            } catch (e) {
              if (!Platform.isWindows) {
                Fluttertoast.showToast(
                  msg: '清空音频缓存时发生错误: $e',
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                );
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

  // 清空图片缓存
  Future<void> _clearImageCache() async {
    final imageCacheService = ImageCacheService();
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
      barrierLabel: "Custom3DDialog",
      barrierColor: Colors.black38,
      transitionDuration: Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return XDialog(
          title: '确认清空',
          content: '确定要清空所有图片缓存吗？此操作不可恢复。',
          confirmText: '确认',
          cancelText: '取消',
          onCancel: () {},
          onConfirm: () async {
            // 确认逻辑
            await imageCacheService.clearAllCache();
            Fluttertoast.showToast(
              msg: '图片缓存已清空',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: const Color(0xD6FFFFFF),
              textColor: const Color(0xFF001F04),
            );
            await _loadImageCacheInfo();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // 清空歌词缓存
  Future<void> _clearLyricsCache() async {
    final lyricsCacheService = LyricsCacheService();
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // 禁止系统自动关闭，手动处理动画
      barrierLabel: "Custom3DDialog",
      barrierColor: Colors.black38,
      transitionDuration: Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return XDialog(
          title: '确认清空',
          content: '确定要清空所有歌词缓存吗？此操作不可恢复。',
          confirmText: '确认',
          cancelText: '取消',
          onCancel: () {},
          onConfirm: () async {
            await lyricsCacheService.clearAllCache();
            Fluttertoast.showToast(
              msg: '歌词缓存已清空',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.white,
              textColor: Colors.black,
            );
            await _loadLyricsCacheInfo();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // 工具方法：判断本地缓存是否存在（与 controller 逻辑完全一致）
  Future<bool> isAudioCached(String fileId, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
    final localFile = File(p.join(cacheDir.path, '$fileId-$fileName'));
    return await localFile.exists();
  }

  @override
  Widget build(BuildContext context) {
    Get.find<PlayerUIController>();
    return Base(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
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
                if (_downProgressService.cacheTasks.isNotEmpty)
                  Obx(() {
                    return Row(
                      children: [
                        GradientText(
                          '缓存任务 (${_downProgressService.cacheTasks.length})',
                          style: TextStyle(
                            fontSize: 28.rpx(context),
                            fontWeight: FontWeight.bold,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white10,
                              Colors.white24,
                              Colors.white70,
                            ],
                          ),
                        ),
                        SizedBox(width: 10.rpx(context)),
                        Text(
                          '${_downProgressService.totalDownloadedSize.value} / ${_downProgressService.totalExpectedSize.value}',
                          style: TextStyle(
                            fontSize: 24.rpx(context),
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(
                          width: 60.rpx(context),
                          height: 60.rpx(context),
                          child: GestureDetector(
                            child: Icon(
                              CupertinoIcons.sort_down,
                              color: Colors.white70,
                              size: 40.rpx(context),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(40.rpx(context)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // 修复布局报错
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.fromLTRB(
                            0,
                            50.rpx(context),
                            0,
                            100.rpx(context),
                          ),
                          child: Column(
                            children: [
                              // GradientText(
                              //   '已占用空间',
                              //   style: TextStyle(fontSize: 36.rpx(context),fontWeight: FontWeight.bold),
                              //   gradient: LinearGradient(
                              //     colors: [
                              //       Color.fromARGB(30, 255, 255, 255),
                              //       Color.fromARGB(100, 255, 255, 255),
                              //       Color.fromARGB(255, 255, 255, 255),
                              //     ], // 绿色到蓝色
                              //   ),
                              // ),
                              // SizedBox(height: 20.rpx(context),),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() {
                                    return _buildAniText(
                                      context,
                                      double.parse(
                                        _downProgressService
                                            .cacheTotalSize
                                            .value
                                            .split(' ')
                                            .first,
                                      ),
                                      _downProgressService.cacheTotalSize.value
                                          .split(' ')
                                          .last,
                                    );
                                  }),
                                ],
                              ),
                              SizedBox(height: 40.rpx(context)),
                              SizedBox(
                                width: 320.rpx(context),
                                child: GradientButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _clearAllCache();
                                  },
                                  gradientColors: [
                                    Color.fromARGB(0, 70, 19, 255),
                                    Color.fromARGB(98, 70, 19, 255),
                                    Color.fromARGB(147, 70, 19, 255),
                                  ],
                                  padding: EdgeInsetsGeometry.symmetric(
                                    vertical: 20.rpx(context),
                                  ),
                                  borderRadius: 30.rpx(context),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.paintbrush,
                                        color: const Color(0xFFFFFFFF),
                                        size: 30.rpx(context),
                                      ),
                                      SizedBox(width: 10.rpx(context)),
                                      GradientText(
                                        '清空音频缓存',
                                        style: TextStyle(
                                          fontSize: 32.rpx(context),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2.rpx(context),
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFFFFFF),
                                            Color(0x5FFFFFFF),
                                            Color(0x2FFFFFFF),
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

                        SizedBox(height: 20.rpx(context)),

                        Obx(() {
                          return _buildCacheItem(
                            context,
                            Icon(
                              CupertinoIcons.music_albums,
                              size: 35.rpx(context),
                              color: const Color(0x75FFFFFF),
                            ),
                            '音频缓存',
                            _cachedFiles.length,
                            _downProgressService.audioTotalSize.value,
                            '音频',
                            true,
                            () {
                              HapticFeedback.lightImpact();
                              Get.toNamed('/cachemusic');
                            },
                          );
                        }),

                        Obx(() {
                          if (_downProgressService.cacheTasks.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 15.rpx(context)),
                                ...(_downProgressService.cacheTasks.map(
                                  (task) => _buildCacheTaskItem(task),
                                )),
                              ],
                            );
                          }
                          return SizedBox.shrink();
                        }),
                        SizedBox(height: 20.rpx(context)),
                        _buildCacheItem(
                          context,
                          Icon(
                            CupertinoIcons.photo,
                            size: 35.rpx(context),
                            color: Colors.white30,
                          ),
                          '图片缓存',
                          _imageCacheCount,
                          _imageCacheSize,
                          '图片',
                          false,
                          () {
                            HapticFeedback.lightImpact();
                            _clearImageCache();
                          },
                        ),
                        SizedBox(height: 20.rpx(context)),
                        _buildCacheItem(
                          context,
                          Icon(
                            CupertinoIcons.text_aligncenter,
                            size: 35.rpx(context),
                            color: Colors.white30,
                          ),
                          '歌词缓存',
                          _lyricsCacheCount,
                          _lyricsCacheSize,
                          '歌词',
                          false,
                          () {
                            HapticFeedback.lightImpact();
                            _clearLyricsCache();
                          },
                        ),
                        SizedBox(height: 40.rpx(context)),
                      ],
                    ),
                  ),
          ),
          Copyright(),
        ],
      ),
    );
  }

  Widget _buildAniText(BuildContext context, double invalue, String limit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GradientText(
          invalue.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 120.rpx(context),
            fontFamily: 'Nufei',
            letterSpacing: 10.rpx(context),
            fontWeight: FontWeight.bold,
          ),
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0x93FFFFFF),
              Color(0x2FFFFFFF),
            ], // 绿色到蓝色
          ),
        ),
        SizedBox(width: 20.rpx(context)),
        Padding(
          padding: EdgeInsetsGeometry.only(top: 40.rpx(context)),
          child: GradientText(
            limit,
            style: TextStyle(
              fontSize: 49.rpx(context),
              letterSpacing: 5.rpx(context),
              fontWeight: FontWeight.bold,
              fontFamily: 'WDXLLubrifontTC',
            ),
            gradient: LinearGradient(
              colors: [
                Color(0x63FFFFFF),
                Color(0x63FFFFFF),
                Color(0x63FFFFFF),
              ], // 绿色到蓝色
            ),
          ),
        ),
      ],
    );
  }

  //缓存数据项
  Widget _buildCacheItem(
    BuildContext context,
    Icon icon,
    String name,
    int size,
    String num,
    String type,
    bool isMore,
    VoidCallback? callback,
  ) {
    return Container(
      decoration: BoxDecoration(
        // color: const Color.fromARGB(38, 255, 255, 255),
        borderRadius: BorderRadius.circular(30.rpx(context)),
        border: BoxBorder.all(color: Colors.transparent, width: 2.rpx(context)),
      ),
      child: Container(
        width: double.infinity,
        height: 90.rpx(context),
        padding: EdgeInsets.symmetric(horizontal: 15.rpx(context)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.rpx(context)),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              const Color.fromARGB(50, 255, 255, 255),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: isMore ? callback : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60.rpx(context),
                height: 60.rpx(context),
                padding: EdgeInsets.all(10.rpx(context)),
                decoration: BoxDecoration(
                  color: const Color(0x090546F7),
                  borderRadius: BorderRadius.circular(20.rpx(context)),
                  border: BoxBorder.all(
                    color: const Color(0x01FFFFFF),
                    width: 2.rpx(context),
                  ),
                ),
                child: icon,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsGeometry.only(left: 10.rpx(context)),
                  child: GradientText(
                    name,
                    style: TextStyle(
                      fontSize: 32.rpx(context),
                      fontWeight: FontWeight.w500,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color(0x75FFFFFF),
                        Color(0xFFFFFFFF),
                        const Color(0xFFFFFFFF),
                      ],
                    ), // 绿色到蓝色
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GradientText(
                    '$type:$size',
                    style: TextStyle(
                      fontSize: 24.rpx(context),
                      fontWeight: FontWeight.w400,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(48, 255, 255, 255),
                        Color.fromARGB(150, 255, 255, 255),
                        Color.fromARGB(100, 255, 255, 255),
                      ],
                    ),
                  ),
                  Text(
                    '共$num',
                    style: TextStyle(
                      fontSize: 20.rpx(context),
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
              if (isMore)
                Container(
                  alignment: Alignment.centerRight,
                  width: 60.rpx(context),
                  height: 90.rpx(context),
                  child: Icon(
                    CupertinoIcons.forward,
                    color: Colors.white38,
                    size: 30.rpx(context),
                  ),
                ),

              if (!isMore)
                GestureDetector(
                  onTap: callback,
                  child: Container(
                    alignment: Alignment.centerRight,
                    width: 90.rpx(context),
                    height: 90.rpx(context),
                    child: Icon(
                      CupertinoIcons.trash_circle,
                      color: const Color.fromARGB(172, 255, 19, 3),
                      size: 50.rpx(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建缓存任务项
  Widget _buildCacheTaskItem(Map<String, dynamic> task) {
    final fileName = task['fileName'] ?? '未知文件';
    final progress = (task['progress'] ?? 0.0).toDouble();
    final percentage = task['percentage'] ?? '0.0';
    final isActive = task['isActive'] ?? false;
    final downloadedSize = task['downloadedSize'] ?? 0;
    final expectedSize = task['expectedSize'] ?? 0;
    final downloadSpeed = task['downloadSpeed'] ?? 0;

    // 安全检查 progress 值
    final safeProgress = progress.isNaN || progress.isInfinite
        ? 0.0
        : progress.clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.fromLTRB(
        90.rpx(context),
        10.rpx(context),
        0,
        10.rpx(context),
      ),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(30.rpx(context)),
        border: Border.all(
          color: isActive
              ? const Color.fromARGB(0, 126, 160, 255)
              : const Color(0x799E9E9E),
          width: 1.rpx(context),
        ),
      ),
      child: Stack(
        children: [
          // 进度条背景
          if (safeProgress > 0.0)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: safeProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.rpx(context)),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color.fromARGB(0, 95, 98, 255),
                        const Color(0x615F62FF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 内容容器
          Container(
            padding: EdgeInsets.all(15.rpx(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isActive
                          ? CupertinoIcons.cloud_download_fill
                          : CupertinoIcons.cloud_download,
                      color: isActive
                          ? const Color.fromARGB(99, 188, 205, 252)
                          : const Color(0x799E9E9E),
                      size: 20.rpx(context),
                    ),
                    SizedBox(width: 8.rpx(context)),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 20.rpx(context),
                          color: Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 18.rpx(context),
                        color: isActive ? Colors.white70 : Colors.grey,
                        // fontFamily: 'Nufei',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.rpx(context)),
                Row(
                  children: [
                    Text(
                      '${_formatFileSize(downloadedSize)} / ${_formatFileSize(expectedSize)}',
                      style: TextStyle(
                        fontSize: 16.rpx(context),
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    if (isActive && downloadSpeed > 0)
                      Text(
                        '${_formatFileSize(downloadSpeed)}/s',
                        style: TextStyle(
                          fontSize: 16.rpx(context),
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(width: 8.rpx(context)),
                    if (isActive)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.rpx(context),
                          vertical: 4.rpx(context),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8.rpx(context)),
                        ),
                        child: Text(
                          '下载中',
                          style: TextStyle(
                            fontSize: 12.rpx(context),
                            color: Colors.white60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
