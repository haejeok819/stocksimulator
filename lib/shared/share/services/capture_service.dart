import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CaptureService {
  static Future<Uint8List> capturePng(
    GlobalKey key, {
    double pixelRatio = 3,
  }) async {
    // 1 frame wait to ensure the boundary has painted
    await Future.delayed(const Duration(milliseconds: 16));

    final BuildContext? context = key.currentContext;
    if (context == null) {
      throw Exception('CaptureService: boundaryKey.currentContext is null');
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null) {
      throw Exception('CaptureService: renderObject is null');
    }

    if (renderObject is! RenderRepaintBoundary) {
      throw Exception(
        'CaptureService: renderObject is not RenderRepaintBoundary (${renderObject.runtimeType})',
      );
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    final ui.ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('CaptureService: toByteData returned null');
    }

    return byteData.buffer.asUint8List();
  }
}
