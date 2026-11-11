import 'dart:typed_data';

/// Non-web platforms: no WebP support here, caller falls back to JPG/PNG.
Future<Uint8List?> encodeWebp(
  Uint8List bytes, {
  int maxDim = 1920,
  double quality = 0.82,
}) async => null;
