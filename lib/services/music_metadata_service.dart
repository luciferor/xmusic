import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xmusic/services/lyrics_cache_service.dart';

class MusicMetadataService {
  static final MusicMetadataService _instance =
      MusicMetadataService._internal();
  factory MusicMetadataService() => _instance;
  MusicMetadataService._internal();

  // 缓存
  final Map<String, String> _lyricsCache = {};

  /// 获取歌词（优先从缓存获取，支持 fileId）
  Future<String?> getLyrics(
    String title,
    String artist, {
    String? fileId,
  }) async {
    if ((fileId == null || fileId.isEmpty) && title.isEmpty) return null;

    final lyricsCacheService = LyricsCacheService();

    try {
      // 1. 优先从缓存获取（fileId 优先）
      final cachedLyrics = await lyricsCacheService.getLyrics(
        fileId: fileId,
        title: title,
        artist: artist,
      );
      if (cachedLyrics != null && cachedLyrics.isNotEmpty) {
        return cachedLyrics;
      }

      // 2. 缓存中没有，从网络获取
      String? finalLyrics;

      // 尝试从QQ音乐获取歌词（优先，因为更稳定）
      final qqLyrics = await getLyricsFromQQ(title, artist);
      if (qqLyrics != null && qqLyrics.isNotEmpty) {
        finalLyrics = qqLyrics;
      } else {
        // 尝试从网易云音乐获取歌词
        final neteaseLyrics = await getLyricsFromNetease(title, artist);
        if (neteaseLyrics != null && neteaseLyrics.isNotEmpty) {
          finalLyrics = neteaseLyrics;
        }
      }

      // 3. 如果获取到歌词，缓存到本地（fileId 优先）
      if (finalLyrics != null && finalLyrics.isNotEmpty) {
        await lyricsCacheService.cacheLyrics(
          fileId: fileId,
          title: title,
          artist: artist,
          lyrics: finalLyrics,
        );
        return finalLyrics;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 从网易云音乐获取歌词（公共方法，用于测试）
  Future<String?> getLyricsFromNetease(String title, String artist) async {
    try {
      // 先搜索歌曲获取ID
      final searchUrl = 'https://music.163.com/api/search/get/web?csrf_token=';

      final searchResponse = await http.post(
        Uri.parse(searchUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://music.163.com/',
        },
        body: {
          's': '$title $artist',
          'type': '1',
          'offset': '0',
          'total': 'true',
          'limit': '1',
        },
      );

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);

        final songs = searchData['result']?['songs'] as List?;

        if (songs != null && songs.isNotEmpty) {
          final songId = songs[0]['id'];

          // 获取歌词
          final lyricsUrl =
              'https://music.163.com/api/song/lyric?id=$songId&lv=1&kv=1&tv=-1';

          final lyricsResponse = await http.get(
            Uri.parse(lyricsUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': 'https://music.163.com/',
            },
          );

          if (lyricsResponse.statusCode == 200) {
            final lyricsData = json.decode(lyricsResponse.body);

            final lrc = lyricsData['lrc']?['lyric'] as String?;
            if (lrc != null && lrc.isNotEmpty) {
              return lrc;
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// 从QQ音乐获取歌词（公共方法，用于测试）
  Future<String?> getLyricsFromQQ(String title, String artist) async {
    try {
      // 先搜索歌曲获取songmid
      final searchUrl = 'https://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp';

      final searchResponse = await http.get(
        Uri.parse(searchUrl).replace(
          queryParameters: {
            '_': DateTime.now().millisecondsSinceEpoch.toString(),
            'g_tk': '5381',
            'uin': '0',
            'format': 'json',
            'inCharset': 'utf-8',
            'outCharset': 'utf-8',
            'notice': '0',
            'platform': 'yqq.json',
            'needNewCode': '0',
            'w': '$title $artist',
            'zhidaqu': '1',
            'catZhida': '1',
            't': '0',
            'flag': '1',
            'ie': 'utf-8',
            'sem': '1',
            'aggr': '0',
            'perpage': '20',
            'n': '1',
            'p': '1',
            'remoteplace': 'txt.mqq.all',
          },
        ),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://y.qq.com/',
        },
      );

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);

        final songs = searchData['data']?['song']?['list'] as List?;

        if (songs != null && songs.isNotEmpty) {
          final songmid = songs[0]['songmid'];

          // 获取歌词
          final lyricsUrl =
              'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg';

          final lyricsResponse = await http.get(
            Uri.parse(lyricsUrl).replace(
              queryParameters: {
                '_': DateTime.now().millisecondsSinceEpoch.toString(),
                'g_tk': '5381',
                'uin': '0',
                'format': 'json',
                'inCharset': 'utf-8',
                'outCharset': 'utf-8',
                'notice': '0',
                'platform': 'yqq.json',
                'needNewCode': '0',
                'songmid': songmid,
              },
            ),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': 'https://y.qq.com/',
            },
          );

          if (lyricsResponse.statusCode == 200) {
            final lyricsData = json.decode(lyricsResponse.body);

            final lyric = lyricsData['lyric'] as String?;
            if (lyric != null) {
              // QQ音乐的歌词是base64编码的
              try {
                final decodedLyric = utf8.decode(base64.decode(lyric));
                return decodedLyric;
              } catch (e) {
                return null;
              }
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _lyricsCache.clear();
  }

  /// 清除特定歌曲的缓存
  void clearSongCache(String title, String artist) {
    final cacheKey = '$title-$artist';
    _lyricsCache.remove(cacheKey);
  }
}

/// 歌词解析工具类
class LyricsParser {
  /// 解析LRC格式歌词
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final timeInSeconds = minutes * 60 + seconds + milliseconds / 1000;
          lines.add(LyricLine(timeInSeconds, text));
        }
      }
    }

    // 按时间排序
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  /// 根据当前播放时间获取当前歌词
  static String getCurrentLyric(List<LyricLine> lyrics, double currentTime) {
    if (lyrics.isEmpty) return '';

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentTime >= lyrics[i].time) {
        return lyrics[i].text;
      }
    }

    return lyrics.first.text;
  }

  /// 获取当前歌词的索引
  static int getCurrentLyricIndex(List<LyricLine> lyrics, double currentTime) {
    if (lyrics.isEmpty) return -1;

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentTime >= lyrics[i].time) {
        return i;
      }
    }

    return 0;
  }
}

/// 歌词行数据类
class LyricLine {
  final double time; // 时间（秒）
  final String text; // 歌词文本

  LyricLine(this.time, this.text);

  @override
  String toString() => 'LyricLine(time: $time, text: $text)';
}

/// 使用示例：
/// 
/// ```dart
/// // 获取歌词和封面
/// final metadataService = MusicMetadataService();
/// 
/// // 获取歌词
/// final lyrics = await metadataService.getLyrics('富士山下', '陈奕迅');
/// if (lyrics != null) {
///   final parsedLyrics = LyricsParser.parseLrc(lyrics);
///   print('歌词行数: ${parsedLyrics.length}');
/// }
/// 
/// // 获取封面
/// final cover = await metadataService.getCover('富士山下', '陈奕迅');
/// if (cover != null) {
///   print('封面URL: $cover');
/// }
/// ``` 