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
    final int safeIndex = seriesA.isEmpty ? 0 : playbackIndex.clamp(0, seriesA.length - 1);
    final int start = max(0, safeIndex - (windowSize - 1));
    final List<double> visibleA = seriesA.sublist(start, safeIndex + 1);
    final List<double> visibleB = seriesB.sublist(start, safeIndex + 1);

    return CustomPaint(
      size: Size.infinite,
      painter: _BattleChartPainter(seriesA: visibleA, seriesB: visibleB),
    );
  }
}

class _BattleChartPainter extends CustomPainter {
  _BattleChartPainter({required this.seriesA, required this.seriesB});

  final List<double> seriesA;
  final List<double> seriesB;

  @override
  void paint(Canvas canvas, Size size) {
    if (seriesA.isEmpty || seriesB.isEmpty) return;

    final double minValue = [...seriesA, ...seriesB].reduce(min);
    final double maxValue = [...seriesA, ...seriesB].reduce(max);
    final double range = (maxValue - minValue).abs() < 1 ? 1 : (maxValue - minValue);

    Offset toPoint(int i, double value, int length) {
      final double x = length <= 1 ? 0 : i * (size.width / (length - 1));
      final double y = size.height - ((value - minValue) / range) * size.height;
      return Offset(x, y);
    }

    Path buildPath(List<double> values) {
      final Path path = Path();
      for (int i = 0; i < values.length; i++) {
        final Offset point = toPoint(i, values[i], values.length);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
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
        ..color = const Color(0xFF5677E7),
    );

    canvas.drawPath(
      buildPath(seriesB),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFF59E0B),
    );
  }

  @override
  bool shouldRepaint(covariant _BattleChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA || oldDelegate.seriesB != seriesB;
  }
}
