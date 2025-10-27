import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:xmusic/services/playlist_service.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/widget.dart';
import 'package:xmusic/ui/components/rpx.dart';
import 'package:xmusic/ui/pages/sliblist.dart';

class Songsclass extends StatefulWidget {
  const Songsclass({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SongsclassState createState() => _SongsclassState();
}

class _SongsclassState extends State<Songsclass> {
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
    if (_playlistService.playlists.isEmpty) return Container();
    return Column(
      children: [
        SizedBox(height: 20.rpx(context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                '我的歌单',
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 255, 255, 255),
                    Color.fromARGB(100, 255, 255, 255),
                    Color.fromARGB(50, 255, 255, 255),
                  ], // 绿色到蓝色
                ),
                style: TextStyle(
                  fontSize: 32.rpx(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          height: 180.rpx(context),
          margin: EdgeInsets.only(
            top: 10.rpx(context),
            bottom: 10.rpx(context),
          ),
          child: Obx(() {
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: _playlistService.playlists.length,
              itemBuilder: (context, index) => _itemBuilder(context, index),
            );
          }),
        ),
      ],
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final tacks = _playlistService.playlists[index];
    final fileId =
        tacks['tracks'][0]['fileId'] ??
        tacks['tracks'][0]['file_id'] ??
        tacks['tracks'][0]['fileId'] ??
        '';
    final coverUrl =
        tacks['tracks'][0]['cover_url'] ??
        tacks['tracks'][0]['cover'] ??
        tacks['tracks'][0]['thumbnail'] ??
        '';
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        Get.to(
          () => PageWithPlayer(
            child: Sliblist(
              playlistId: tacks['id'],
              playlistName: tacks['name'],
            ),
          ),
        );
      },
      child: Container(
        width: 270.rpx(context),
        height: 270.rpx(context),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.only(
          right: index == _playlistService.playlists.length - 1
              ? 60.rpx(context)
              : 20.rpx(context),
          left: index == 0 ? 40.rpx(context) : 0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(45.rpx(context)),
          border: Border.all(width: 5.rpx(context), color: Colors.white24),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(40.rpx(context)),
              child: CachedImage(
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
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsetsGeometry.all(20.rpx(context)),
                child: GradientText(
                  '${tacks['name']}',
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
          ],
        ),
      ),
    );
  }
}
