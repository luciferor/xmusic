import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:material_color_utilities/material_color_utilities.dart';

class ImageColorService {
  // Singleton instance
  static final ImageColorService _instance = ImageColorService._internal();
  factory ImageColorService() => _instance;
  ImageColorService._internal();

  // In-memory cache for extracted colors
  final Map<ImageProvider, Color> _colorCache = {};

  Future<Color?> getDominantColor(
    ImageProvider imageProvider, {
    Color? defaultColor,
  }) async {
    // 1. Check cache first
    if (_colorCache.containsKey(imageProvider)) {
      return _colorCache[imageProvider];
    }

    try {
      // 2. Convert ImageProvider to Uint8List
      final bytes = await _getBytesFromImageProvider(imageProvider);
      if (bytes == null) return defaultColor;

      // 3. Use 'image' package to decode
      final image = img.decodeImage(bytes);
      if (image == null) return defaultColor;

      // 4. Get pixels for material_color_utilities
      final pixels = image
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asUint32List();

      // 5. Quantize and score colors
      // We use compute to run this heavy task in a separate isolate
      final quantizerResult = await compute(quantizePixels, pixels);

      final rankedColors = Score.score(quantizerResult.colorToCount);

      final dominantColor = Color(rankedColors.first);

      // 6. Cache the result
      _colorCache[imageProvider] = dominantColor;

      return dominantColor;
    } catch (e) {
      // On error, return default color
      debugPrint('Error getting dominant color: $e');
      return defaultColor;
    }
  }

  Future<Uint8List?> _getBytesFromImageProvider(
    ImageProvider imageProvider,
  ) async {
    final completer = Completer<Uint8List?>();
    final imageStream = imageProvider.resolve(const ImageConfiguration());

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) async {
        imageStream.removeListener(listener);
        try {
          final byteData = await info.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          completer.complete(byteData?.buffer.asUint8List());
        } catch (e) {
          completer.complete(null);
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        imageStream.removeListener(listener);
        completer.complete(null);
      },
    );

    imageStream.addListener(listener);
    return completer.future;
  }
}

// Top-level function to be used with compute
Future<QuantizerResult> quantizePixels(Uint32List pixels) async {
  final quantizer = QuantizerCelebi();
  return await quantizer.quantize(pixels, 128);
}
