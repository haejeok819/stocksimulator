import 'dart:math';

import 'package:flutter/material.dart';

class BattleChart extends StatelessWidget {
  const BattleChart({
    super.key,
    required this.seriesA,
    required this.seriesB,
    required this.playbackIndex,
    this.windowSize = 30,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final int playbackIndex;
  final int windowSize;

  @override
  Widget build(BuildContext context) {
    if (seriesA.isEmpty || seriesB.isEmpty) {
      return const SizedBox.shrink();
    }

    final int safeIndex = playbackIndex.clamp(0, seriesA.length - 1);
    final int center = windowSize ~/ 2;

    final List<double?> visibleA = List<double?>.filled(windowSize, null, growable: false);
    final List<double?> visibleB = List<double?>.filled(windowSize, null, growable: false);

    for (int i = 0; i < windowSize; i++) {
      final int sourceIndex = safeIndex - center + i;
      if (sourceIndex < 0 || sourceIndex >= seriesA.length) {
        continue;
      }
      visibleA[i] = seriesA[sourceIndex];
      visibleB[i] = seriesB[sourceIndex];
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _BattleChartPainter(seriesA: visibleA, seriesB: visibleB),
    );
  }
}

class _BattleChartPainter extends CustomPainter {
  _BattleChartPainter({required this.seriesA, required this.seriesB});

  final List<double?> seriesA;
  final List<double?> seriesB;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> values = <double>[
      ...seriesA.whereType<double>(),
      ...seriesB.whereType<double>(),
    ];
    if (values.isEmpty) return;

    final double minValue = values.reduce(min);
    final double maxValue = values.reduce(max);
    final double range = (maxValue - minValue).abs() < 1 ? 1 : (maxValue - minValue);

    Offset toPoint(int i, double value) {
      final double x = seriesA.length <= 1 ? 0 : i * (size.width / (seriesA.length - 1));
      final double y = size.height - ((value - minValue) / range) * size.height;
      return Offset(x, y);
    }

    Path buildPath(List<double?> values) {
      final Path path = Path();
      bool drawing = false;

      for (int i = 0; i < values.length; i++) {
        final double? value = values[i];
        if (value == null) {
          drawing = false;
          continue;
        }

        final Offset point = toPoint(i, value);
        if (!drawing) {
          path.moveTo(point.dx, point.dy);
          drawing = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path;
    }

    canvas.drawPath(
      buildPath(seriesA),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF266DD3),
    );

    canvas.drawPath(
      buildPath(seriesB),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFE54B4B),
    );
  }

  @override
  bool shouldRepaint(covariant _BattleChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA || oldDelegate.seriesB != seriesB;
  }
}
