import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:get/get.dart';
import 'package:xmusic/services/favorite_service.dart';
import 'package:xmusic/ui/components/cached_image.dart';
import 'package:xmusic/ui/components/gradienttext.dart';
import 'package:xmusic/ui/components/player/controller.dart';
import 'package:xmusic/ui/components/rpx.dart';

class Fav extends StatefulWidget {
  const Fav({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FavState createState() => _FavState();
}

class _FavState extends State<Fav> {
  final playerController = Get.find<PlayerUIController>();
  @override
  Widget build(BuildContext context) {
    return GetX<FavoriteService>(
      builder: (favoriteService) {
        final favorites = favoriteService.favoriteTracks.toList();
        if (favorites.isEmpty) return Container();
        return Column(
          children: [
            SizedBox(height: 20.rpx(context)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 40.rpx(context)),
              margin: EdgeInsets.only(top: 10.rpx(context)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    '我喜欢',
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0x63FFFFFF),
                        Color(0x31FFFFFF),
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
              height: 120.rpx(context),
              margin: EdgeInsets.symmetric(vertical: 10.rpx(context)),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  return _buildFavItem(
                    context,
                    index,
                    favorites[index],
                    favorites,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavItem(
    BuildContext context,
    int index,
    Map<String, dynamic> item,
    List<Map<String, dynamic>> favorites,
  ) {
    final fileId = item['fileId'] ?? item['file_id'] ?? item['id'] ?? '';
    final coverUrl =
        item['cover_url'] ?? item['cover'] ?? item['thumbnail'] ?? '';
    return Bounceable(
      onTap: () async {
        HapticFeedback.lightImpact();
        try {
          // 如果播放列表不是收藏列表，先重置播放列表
          if (!playerController.isPlaylistConsistent(favorites)) {
            await playerController.resetPlaylist(favorites);
          }
          await playerController.onMusicItemTap(index);
        } catch (e) {}
      },
      child: Container(
        width: 120.rpx(context),
        height: 120.rpx(context),
        margin: EdgeInsets.fromLTRB(
          index == 0 ? 40.rpx(context) : 0,
          0,
          20.rpx(context),
          0,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34.rpx(context)),
          border: Border.all(width: 4.rpx(context), color: Colors.white24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadiusGeometry.circular(30.rpx(context)),
          child: CachedImage(
            imageUrl: coverUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[800],
              child: Icon(Icons.music_note, color: Colors.grey[600], size: 30),
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
      ),
    );
  }
}
