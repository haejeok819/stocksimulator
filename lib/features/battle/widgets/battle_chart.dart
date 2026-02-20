import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

int battleVisibleStartIndex({required int totalCount, required int currentIndex}) {
  if (totalCount <= 2) return 0;
  final int safe = currentIndex.clamp(0, totalCount - 1);
  final double t = safe / (totalCount - 1);
  final double eased = sqrt(t);
  final int minWindow = max(12, (totalCount * 0.08).round()).clamp(2, totalCount);
  final int window = (minWindow + ((totalCount - minWindow) * eased)).round().clamp(minWindow, totalCount);
  if (safe >= totalCount - 1) return 0;
  return max(0, safe - window + 1);
}

class BattleChart extends StatefulWidget {
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
  State<BattleChart> createState() => _BattleChartState();
}

class _BattleChartState extends State<BattleChart> {
  double? _smoothedMinY;
  double? _smoothedMaxY;

  static const double _kLineStroke = 3.4;
  static const double _kPointRadius = 4.4;
  static const double _kPointGlow = 9.0;

  @override
  void didUpdateWidget(covariant BattleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesA.length != widget.seriesA.length || oldWidget.seriesB.length != widget.seriesB.length) {
      _smoothedMinY = null;
      _smoothedMaxY = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seriesA.isEmpty || widget.seriesB.isEmpty || widget.dates.isEmpty) {
      return const SizedBox.shrink();
    }

    final int length = min(widget.seriesA.length, widget.seriesB.length);
    final int safeIndex = widget.playbackIndex.clamp(0, length - 1);
    final int visibleStart = battleVisibleStartIndex(totalCount: length, currentIndex: safeIndex);

    double minY = widget.seriesA[visibleStart];
    double maxY = widget.seriesA[visibleStart];
    for (int i = visibleStart; i <= safeIndex; i++) {
      final double a = widget.seriesA[i];
      final double b = widget.seriesB[i];
      if (a < minY) minY = a;
      if (b < minY) minY = b;
      if (a > maxY) maxY = a;
      if (b > maxY) maxY = b;
    }

    final double rawRange = maxY - minY;
    final double padded = rawRange < 0.2 ? 8.0 : max(rawRange * 0.18, 1.2);
    double targetMin = minY - padded;
    double targetMax = maxY + padded;

    final double minVisualRange = 10.0;
    if ((targetMax - targetMin) < minVisualRange) {
      final double mid = (targetMax + targetMin) / 2;
      targetMin = mid - minVisualRange / 2;
      targetMax = mid + minVisualRange / 2;
    }

    _smoothedMinY = _smoothedMinY == null ? targetMin : ui.lerpDouble(_smoothedMinY, targetMin, 0.16)!;
    _smoothedMaxY = _smoothedMaxY == null ? targetMax : ui.lerpDouble(_smoothedMaxY, targetMax, 0.16)!;

    return CustomPaint(
      size: Size.infinite,
      painter: _BattleChartPainter(
        seriesA: widget.seriesA,
        seriesB: widget.seriesB,
        dates: widget.dates,
        visibleStartIndex: visibleStart,
        currentIndex: safeIndex,
        minY: _smoothedMinY!,
        maxY: _smoothedMaxY!,
        basePriceA: widget.basePriceA,
        basePriceB: widget.basePriceB,
        marketCodeA: widget.marketCodeA,
        marketCodeB: widget.marketCodeB,
        lineStrokeWidth: _kLineStroke,
        pointRadius: _kPointRadius,
        pointGlowRadius: _kPointGlow,
      ),
    );
  }
}

class _BattleChartPainter extends CustomPainter {
  _BattleChartPainter({
    required this.seriesA,
    required this.seriesB,
    required this.dates,
    required this.visibleStartIndex,
    required this.currentIndex,
    required this.minY,
    required this.maxY,
    required this.basePriceA,
    required this.basePriceB,
    required this.marketCodeA,
    required this.marketCodeB,
    required this.lineStrokeWidth,
    required this.pointRadius,
    required this.pointGlowRadius,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final List<int> dates;
  final int visibleStartIndex;
  final int currentIndex;
  final double minY;
  final double maxY;
  final double basePriceA;
  final double basePriceB;
  final String marketCodeA;
  final String marketCodeB;
  final double lineStrokeWidth;
  final double pointRadius;
  final double pointGlowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final int length = min(seriesA.length, seriesB.length);
    if (length < 2 || currentIndex <= visibleStartIndex) return;

    const double yAxisWidth = 64;
    const double xAxisHeight = 24;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height - xAxisHeight);
    final double verticalSafety = max(pointGlowRadius, lineStrokeWidth * 0.5) + 1;
    final Rect safeRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + verticalSafety,
      chartRect.right,
      chartRect.bottom - verticalSafety,
    );

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    const int yTickCount = 4;
    final double currentMid = (seriesA[currentIndex] + seriesB[currentIndex]) / 2;
    final List<double> tickValues = <double>[];
    int nearestTick = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      final double value = maxY - ratio * (maxY - minY);
      tickValues.add(value);
      final double d = (value - currentMid).abs();
      if (d < nearestDist) {
        nearestDist = d;
        nearestTick = i;
      }
    }

    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      final double y = safeRect.top + ratio * safeRect.height;
      final double value = tickValues[i];
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final bool isCurrentBand = i == nearestTick;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _formatAxisLabel(value),
          style: TextStyle(
            color: isCurrentBand ? const Color(0xFFD1D4E0) : const Color(0x99A1A1A8),
            fontSize: 11,
            fontWeight: isCurrentBand ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 8);
      tp.paint(canvas, Offset(chartRect.right + 8, y - tp.height / 2));
    }

    final int visibleCount = currentIndex - visibleStartIndex + 1;
    final double range = max(maxY - minY, 0.0001);
    final double stepX = chartRect.width / max(1, visibleCount - 1);

    Offset pointFor(int i, double v) {
      final double rawX = chartRect.left + (stepX * (i - visibleStartIndex));
      final double rawY = safeRect.bottom - ((v - minY) / range) * safeRect.height;
      return Offset(
        rawX.clamp(chartRect.left, chartRect.right),
        rawY.clamp(safeRect.top, safeRect.bottom),
      );
    }

    final bool aLeading = seriesA[currentIndex] >= seriesB[currentIndex];
    final Paint aPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = aLeading ? lineStrokeWidth : lineStrokeWidth - 0.6
      ..color = const Color(0xFFE54B4B).withOpacity(aLeading ? 1 : 0.84);

    final Paint bPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = aLeading ? lineStrokeWidth - 0.6 : lineStrokeWidth
      ..color = const Color(0xFF266DD3).withOpacity(aLeading ? 0.84 : 1);

    final Path aPath = Path();
    final Path bPath = Path();

    for (int i = visibleStartIndex; i <= currentIndex; i++) {
      final Offset pa = pointFor(i, seriesA[i]);
      final Offset pb = pointFor(i, seriesB[i]);
      if (i == visibleStartIndex) {
        aPath.moveTo(pa.dx, pa.dy);
        bPath.moveTo(pb.dx, pb.dy);
      } else {
        aPath.lineTo(pa.dx, pa.dy);
        bPath.lineTo(pb.dx, pb.dy);
      }
    }

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(chartRect, const Radius.circular(10)));

    canvas.drawPath(aPath, aPaint);
    canvas.drawPath(bPath, bPaint);

    final Offset endA = pointFor(currentIndex, seriesA[currentIndex]);
    final Offset endB = pointFor(currentIndex, seriesB[currentIndex]);
    canvas.drawCircle(endA, pointGlowRadius, Paint()..color = const Color(0xFFE54B4B).withOpacity(0.22));
    canvas.drawCircle(endB, pointGlowRadius, Paint()..color = const Color(0xFF266DD3).withOpacity(0.22));
    canvas.drawCircle(endA, pointRadius, Paint()..color = const Color(0xFFE54B4B));
    canvas.drawCircle(endB, pointRadius, Paint()..color = const Color(0xFF266DD3));

    canvas.restore();

    _drawXLabels(canvas, chartRect, stepX, visibleStartIndex, currentIndex);
  }

  void _drawXLabels(Canvas canvas, Rect chartRect, double stepX, int startIndex, int endIndex) {
    final int visibleCount = endIndex - startIndex + 1;
    final List<int> indices = <int>[startIndex];
    if (visibleCount >= 36) {
      indices.add(startIndex + ((visibleCount - 1) * 0.55).round());
    }
    indices.add(endIndex);

    double lastRight = -1e9;
    for (final int index in indices.toSet().toList()..sort()) {
      final double x = chartRect.left + (index - startIndex) * stepX;
      final String label = index == endIndex ? _formatYmd(dates[index]) : _formatYmdShort(dates[index]);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0x99A1A1A8), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double drawX = (x - tp.width / 2).clamp(chartRect.left, chartRect.right - tp.width);
      if (drawX < lastRight + 14) {
        continue;
      }
      tp.paint(canvas, Offset(drawX, chartRect.bottom + 6));
      lastRight = drawX + tp.width;
    }
  }

  String _formatAxisLabel(double percent) {
    final double priceA = basePriceA * (1 + percent / 100);
    final double priceB = basePriceB * (1 + percent / 100);
    return '${_formatPrice(priceA, marketCodeA)} / ${_formatPrice(priceB, marketCodeB)}';
  }

  String _formatPrice(double price, String marketCode) {
    return '${AppNumberFormat.formatInt(price)}원';
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatYmdShort(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}';
  }

  @override
  bool shouldRepaint(covariant _BattleChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA ||
        oldDelegate.seriesB != seriesB ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.visibleStartIndex != visibleStartIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.dates != dates ||
        oldDelegate.basePriceA != basePriceA ||
        oldDelegate.basePriceB != basePriceB ||
        oldDelegate.marketCodeA != marketCodeA ||
        oldDelegate.marketCodeB != marketCodeB ||
        oldDelegate.lineStrokeWidth != lineStrokeWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.pointGlowRadius != pointGlowRadius;
  }
}
