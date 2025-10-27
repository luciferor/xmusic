import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioFileUtil {
  static Future<bool> isAudioFile(File file) async {
    if (!await file.exists()) return false;
    final fileSize = await file.length();
    if (fileSize < 1024) return false;

    // 读取前16字节
    final bytes = await file.openRead(0, 16).first;
    final header = String.fromCharCodes(bytes.take(4));
    final header8 = String.fromCharCodes(bytes.take(8));
    final header6 = String.fromCharCodes(bytes.take(6));

    // 常见音频文件头
    if (header == 'fLaC' || // FLAC
        header.startsWith('RIFF') || // WAV
        header.startsWith('ID3') || // MP3
        header.startsWith('OggS') || // OGG
        header.startsWith('\xFF\xFB') || // MP3
        header.startsWith('\xFF\xF3') ||
        header.startsWith('\xFF\xF2') ||
        header8.startsWith('OpusHead') || // OPUS
        header == 'FORM' || // AIFF
        header == '.snd' || // AU
        header6 == '#!AMR\n' || // AMR
        header == 'MThd' || // MIDI
        header8.contains('ftypM4A') || // M4A
        header8.contains('ftypisom') ||
        header8.contains('ftypmp42') ||
        header8.contains('ftypMSNV') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x30 &&
            bytes[1] == 0x26 &&
            bytes[2] == 0xB2 &&
            bytes[3] == 0x75) // WMA
        ) {
      return true;
    }

    // 文件名后缀兜底
    if (isAudioFileName(file.path) && fileSize > 1024) return true;

    return false;
  }

  static bool isAudioFileName(String filePath) {
    final audioExtensions = [
      '.mp3',
      '.flac',
      '.wav',
      '.aac',
      '.ogg',
      '.m4a',
      '.ape',
      '.alac',
      '.wma',
      '.amr',
      '.aiff',
      '.au',
      '.opus',
      '.mid',
      '.midi',
    ];
    final lower = filePath.toLowerCase();
    return audioExtensions.any((ext) => lower.endsWith(ext));
  }
}

Future<String> getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.identifierForVendor ?? '';
  }
  return '';
}

Future<String> getDeviceName() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  final deviceInfo = await deviceInfoPlugin.deviceInfo;
  final allInfo = deviceInfo.data;
  return allInfo['model'] ?? '';
}

String toCacheExt(String ext) {
  if (ext.isEmpty) return ext;
  return ext; // 直接返回原始后缀，不再伪装
}

Future<String> getCacheFilePath(String fileName, String fileId) async {
  final originalExt = fileName.split('.').last.toLowerCase();
  final cacheExt = toCacheExt(originalExt); // 使用原始后缀
  final baseName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  final cacheFileName = '$fileId-$baseName.$cacheExt';
  final cacheDir = await getAudioCacheDir();
  return '$cacheDir/$cacheFileName';
}

Future<String> getAudioCacheDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory(p.join(dir.path, 'audio_cache'));
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  return cacheDir.path;
}
