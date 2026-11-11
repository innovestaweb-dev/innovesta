import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Resizes to at most [maxDim] px and encodes as WebP using the browser canvas.
/// Returns null if anything fails (caller should fall back).
Future<Uint8List?> encodeWebp(
  Uint8List bytes, {
  int maxDim = 1920,
  double quality = 0.82,
}) async {
  try {
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
    final bitmap = await web.window.createImageBitmap(blob).toDart;

    final longSide = bitmap.width > bitmap.height
        ? bitmap.width
        : bitmap.height;
    final scale = longSide > maxDim ? maxDim / longSide : 1.0;
    final w = (bitmap.width * scale).round();
    final h = (bitmap.height * scale).round();

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(bitmap, 0, 0, w.toDouble(), h.toDouble());
    bitmap.close();

    final completer = Completer<Uint8List?>();
    canvas.toBlob(
      ((web.Blob? out) {
        if (out == null) {
          completer.complete(null);
          return;
        }
        out
            .arrayBuffer()
            .toDart
            .then((buffer) {
              completer.complete(buffer.toDart.asUint8List());
            })
            .catchError((_) {
              completer.complete(null);
            });
      }).toJS,
      'image/webp',
      quality.toJS,
    );
    return await completer.future;
  } catch (_) {
    return null;
  }
}
