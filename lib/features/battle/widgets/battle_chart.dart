import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BattleChart extends StatelessWidget {
  const BattleChart({
    super.key,
    required this.seriesA,
    required this.seriesB,
    required this.dates,
    required this.playbackIndex,
    required this.basePriceA,
    required this.basePriceB,
    required this.marketCodeA,
    required this.marketCodeB,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final List<int> dates;
  final int playbackIndex;
  final double basePriceA;
  final double basePriceB;
  final String marketCodeA;
  final String marketCodeB;

  @override
  Widget build(BuildContext context) {
    if (seriesA.isEmpty || seriesB.isEmpty || dates.isEmpty) {
      return const SizedBox.shrink();
    }

    final int safeIndex = playbackIndex.clamp(0, seriesA.length - 1);

    double minY = min(seriesA.reduce(min), seriesB.reduce(min));
    double maxY = max(seriesA.reduce(max), seriesB.reduce(max));
    final double rawRange = maxY - minY;
    final double pad = rawRange < 0.1 ? 1.0 : max(rawRange * 0.08, 0.5);
    minY -= pad;
    maxY += pad;

    return CustomPaint(
      size: Size.infinite,
      painter: _BattleChartPainter(
        seriesA: seriesA,
        seriesB: seriesB,
        dates: dates,
        currentIndex: safeIndex,
        minY: minY,
        maxY: maxY,
        basePriceA: basePriceA,
        basePriceB: basePriceB,
        marketCodeA: marketCodeA,
        marketCodeB: marketCodeB,
      ),
    );
  }
}

class _BattleChartPainter extends CustomPainter {
  _BattleChartPainter({
    required this.seriesA,
    required this.seriesB,
    required this.dates,
    required this.currentIndex,
    required this.minY,
    required this.maxY,
    required this.basePriceA,
    required this.basePriceB,
    required this.marketCodeA,
    required this.marketCodeB,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final List<int> dates;
  final int currentIndex;
  final double minY;
  final double maxY;
  final double basePriceA;
  final double basePriceB;
  final String marketCodeA;
  final String marketCodeB;

  @override
  void paint(Canvas canvas, Size size) {
    final int length = min(seriesA.length, seriesB.length);
    if (length < 2) return;

    const double yAxisWidth = 64;
    const double xAxisHeight = 24;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height - xAxisHeight);

    final Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.18)..strokeWidth = 1;
    const int yTickCount = 5;
    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      final double y = chartRect.top + ratio * chartRect.height;
      final double value = maxY - ratio * (maxY - minY);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _formatAxisLabel(value),
          style: const TextStyle(color: Color(0xFFA1A1A8), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 8);
      tp.paint(canvas, Offset(chartRect.right + 8, y - tp.height / 2));
    }

    final double range = max(maxY - minY, 0.0001);
    final double stepX = chartRect.width / (length - 1);

    Offset pointFor(int i, double v) {
      final double x = chartRect.left + (stepX * i);
      final double y = chartRect.bottom - ((v - minY) / range) * chartRect.height;
      return Offset(x, y);
    }

    final Paint aPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFE54B4B);

    final Paint bPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF266DD3);

    final Path aPath = Path();
    final Path bPath = Path();

    for (int i = 0; i <= currentIndex; i++) {
      final Offset pa = pointFor(i, seriesA[i]);
      final Offset pb = pointFor(i, seriesB[i]);
      if (i == 0) {
        aPath.moveTo(pa.dx, pa.dy);
        bPath.moveTo(pb.dx, pb.dy);
      } else {
        aPath.lineTo(pa.dx, pa.dy);
        bPath.lineTo(pb.dx, pb.dy);
      }
    }

    canvas.drawPath(aPath, aPaint);
    canvas.drawPath(bPath, bPaint);

    final Offset endA = pointFor(currentIndex, seriesA[currentIndex]);
    final Offset endB = pointFor(currentIndex, seriesB[currentIndex]);
    canvas.drawCircle(endA, 4, Paint()..color = const Color(0xFFE54B4B));
    canvas.drawCircle(endB, 4, Paint()..color = const Color(0xFF266DD3));

    _drawXLabels(canvas, chartRect, stepX, length);
  }

  void _drawXLabels(Canvas canvas, Rect chartRect, double stepX, int length) {
    final int labelCount = 7;
    final Set<int> indices = <int>{0, length - 1};
    for (int i = 1; i < labelCount - 1; i++) {
      final int index = ((length - 1) * (i / (labelCount - 1))).round();
      indices.add(index.clamp(0, length - 1));
    }

    for (final int index in indices.toList()..sort()) {
      final double x = chartRect.left + index * stepX;
      final String label = _formatYmd(dates[index]);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFFA1A1A8), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double drawX = (x - tp.width / 2).clamp(chartRect.left, chartRect.right - tp.width);
      tp.paint(canvas, Offset(drawX, chartRect.bottom + 6));
    }
  }

  String _formatAxisLabel(double percent) {
    final double priceA = basePriceA * (1 + percent / 100);
    final double priceB = basePriceB * (1 + percent / 100);
    return '${_formatPrice(priceA, marketCodeA)} / ${_formatPrice(priceB, marketCodeB)}';
  }

  String _formatPrice(double price, String marketCode) {
    if (marketCode == 'US') {
      return '\$${AppNumberFormat.formatPrice(price, decimals: 2)}';
    }
    return '${AppNumberFormat.formatInt(price)}원';
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  bool shouldRepaint(covariant _BattleChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA ||
        oldDelegate.seriesB != seriesB ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.dates != dates ||
        oldDelegate.basePriceA != basePriceA ||
        oldDelegate.basePriceB != basePriceB ||
        oldDelegate.marketCodeA != marketCodeA ||
        oldDelegate.marketCodeB != marketCodeB;
  }
}
