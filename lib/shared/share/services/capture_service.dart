import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CaptureService {
  const CaptureService();

  Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 3}) async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final BuildContext? context = key.currentContext;
    if (context == null) {
      throw StateError('Capture boundary is not ready.');
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Capture boundary is missing.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to convert capture to PNG.');
    }

    return byteData.buffer.asUint8List();
  }
}
