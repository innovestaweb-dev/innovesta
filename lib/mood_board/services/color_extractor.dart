import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

class ExtractedColor {
  final int red;
  final int green;
  final int blue;
  final String hex;
  final int percentage;
  final int pixelCount;

  const ExtractedColor({
    required this.red,
    required this.green,
    required this.blue,
    required this.hex,
    required this.percentage,
    required this.pixelCount,
  });

  String get rgb => 'RGB($red, $green, $blue)';
}

class ColorExtractor {
  static const int defaultColorCount = 6;

  /// The image is analyzed at a reduced size (about this many pixels wide).
  /// Colors do not need the full resolution, and a small size is much faster.
  static const int maxImageSize = 100;

  static Future<List<ExtractedColor>> extractColors(
    Uint8List imageBytes, {
    int colorCount = defaultColorCount,
    int iterations = 12,
  }) async {
    // Fast path: the browser / Flutter engine decodes AND downsizes the image
    // natively, so the full-resolution photo is never decoded in Dart.
    // Fallback: the `image` package (slow for big photos) for formats the
    // engine cannot decode.
    List<List<double>> pixels;

    try {
      pixels = await _decodePixelsNative(imageBytes);
    } catch (_) {
      pixels = _decodePixelsWithImagePackage(imageBytes);
    }

    if (pixels.isEmpty) {
      throw Exception('The image contains no visible pixels.');
    }

    final k = math.min(colorCount, pixels.length);

    final centers = _initializeCenters(pixels, k);

    final assignments = List<int>.filled(pixels.length, -1);

    for (int iteration = 0; iteration < iterations; iteration++) {
      final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);

      final counts = List<int>.filled(k, 0);

      bool changed = false;

      for (int i = 0; i < pixels.length; i++) {
        final cluster = _nearestCenter(pixels[i], centers);

        if (assignments[i] != cluster) {
          assignments[i] = cluster;
          changed = true;
        }

        for (int channel = 0; channel < 3; channel++) {
          sums[cluster][channel] += pixels[i][channel];
        }

        counts[cluster]++;
      }

      for (int cluster = 0; cluster < k; cluster++) {
        if (counts[cluster] == 0) continue;

        for (int channel = 0; channel < 3; channel++) {
          centers[cluster][channel] = sums[cluster][channel] / counts[cluster];
        }
      }

      // Converged: no pixel changed its cluster, further passes add nothing.
      if (!changed) break;
    }

    final finalCounts = List<int>.filled(k, 0);

    for (int i = 0; i < pixels.length; i++) {
      assignments[i] = _nearestCenter(pixels[i], centers);
      finalCounts[assignments[i]]++;
    }

    final results = <ExtractedColor>[];

    for (int i = 0; i < k; i++) {
      if (finalCounts[i] == 0) continue;

      final r = centers[i][0].round().clamp(0, 255);
      final g = centers[i][1].round().clamp(0, 255);
      final b = centers[i][2].round().clamp(0, 255);

      final hex =
          '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';

      final normalizedHex = hex.toUpperCase();
      final percentage = (finalCounts[i] * 100 / pixels.length).round();

      results.add(
        ExtractedColor(
          red: r,
          green: g,
          blue: b,
          hex: normalizedHex,
          percentage: percentage,
          pixelCount: finalCounts[i],
        ),
      );
    }

    results.sort((a, b) => b.pixelCount.compareTo(a.pixelCount));

    return results;
  }

  // ---------------------------------------------------------------------------
  // Decoding
  // ---------------------------------------------------------------------------

  /// Decodes the image with the Flutter engine, already scaled down.
  static Future<List<List<double>>> _decodePixelsNative(
    Uint8List imageBytes,
  ) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: maxImageSize,
      allowUpscaling: false,
    );

    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;

      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

        if (data == null) {
          throw Exception('Unable to read image pixels.');
        }

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        final pixels = <List<double>>[];

        for (int i = 0; i + 3 < bytes.length; i += 4) {
          // Skip mostly transparent pixels.
          if (bytes[i + 3] < 128) continue;

          pixels.add([
            bytes[i].toDouble(),
            bytes[i + 1].toDouble(),
            bytes[i + 2].toDouble(),
          ]);
        }

        return pixels;
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Slower fallback using the `image` package.
  static List<List<double>> _decodePixelsWithImagePackage(
    Uint8List imageBytes,
  ) {
    final decoded = img.decodeImage(imageBytes);

    if (decoded == null) {
      throw Exception('Unable to decode image.');
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? maxImageSize : null,
      height: decoded.height >= decoded.width ? maxImageSize : null,
    );

    final pixels = <List<double>>[];

    for (final pixel in resized) {
      if (pixel.a < 128) continue;

      pixels.add([pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()]);
    }

    return pixels;
  }

  // ---------------------------------------------------------------------------
  // K-means helpers
  // ---------------------------------------------------------------------------

  static List<List<double>> _initializeCenters(
    List<List<double>> pixels,
    int k,
  ) {
    final centers = <List<double>>[];

    for (int i = 0; i < k; i++) {
      final index = ((i + 0.5) * pixels.length / k).floor().clamp(
        0,
        pixels.length - 1,
      );

      centers.add(List<double>.from(pixels[index]));
    }

    return centers;
  }

  static int _nearestCenter(List<double> pixel, List<List<double>> centers) {
    int nearest = 0;
    double minimumDistance = double.infinity;

    for (int i = 0; i < centers.length; i++) {
      double distance = 0;

      for (int channel = 0; channel < 3; channel++) {
        final difference = pixel[channel] - centers[i][channel];
        distance += difference * difference;
      }

      if (distance < minimumDistance) {
        minimumDistance = distance;
        nearest = i;
      }
    }

    return nearest;
  }
}
