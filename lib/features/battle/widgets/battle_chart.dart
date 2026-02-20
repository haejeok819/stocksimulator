import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
    required this.playbackPosition,
    required this.basePriceA,
    required this.basePriceB,
    required this.marketCodeA,
    required this.marketCodeB,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final List<int> dates;
  final int playbackIndex;
  final double playbackPosition;
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
    final double safePlaybackPosition = widget.playbackPosition.clamp(0, (length - 1).toDouble());
    final int safeIndex = safePlaybackPosition.floor();
    final int renderEndIndex = safePlaybackPosition.ceil();
    final int visibleStart = battleVisibleStartIndex(totalCount: length, currentIndex: renderEndIndex);

    double minY = widget.seriesA[visibleStart];
    double maxY = widget.seriesA[visibleStart];
    for (int i = visibleStart; i <= renderEndIndex; i++) {
      final double a = widget.seriesA[i];
      final double b = widget.seriesB[i];
      if (a < minY) minY = a;
      if (b < minY) minY = b;
      if (a > maxY) maxY = a;
      if (b > maxY) maxY = b;
    }

    const double minVisualRange = 10.0;
    const double nearBoundaryThreshold = 0.82;
    final double rawRange = max(maxY - minY, minVisualRange * 0.35);
    final double baseHeadroom = max(rawRange * 0.18, 1.6);

    double targetMin = minY - baseHeadroom;
    double targetMax = maxY + baseHeadroom;

    if (_smoothedMinY != null && _smoothedMaxY != null) {
      final double previousMin = _smoothedMinY!;
      final double previousMax = _smoothedMaxY!;
      final double previousRange = max(previousMax - previousMin, minVisualRange);

      final double upperTrigger = previousMin + (previousRange * nearBoundaryThreshold);
      if (maxY > upperTrigger) {
        final double overflow = maxY - upperTrigger;
        targetMax = max(targetMax, previousMax + (overflow / (1 - nearBoundaryThreshold)));
      }

      final double lowerTrigger = previousMax - (previousRange * nearBoundaryThreshold);
      if (minY < lowerTrigger) {
        final double overflow = lowerTrigger - minY;
        targetMin = min(targetMin, previousMin - (overflow / (1 - nearBoundaryThreshold)));
      }
    }

    if ((targetMax - targetMin) < minVisualRange) {
      final double mid = (targetMax + targetMin) / 2;
      targetMin = mid - minVisualRange / 2;
      targetMax = mid + minVisualRange / 2;
    }

    if (_smoothedMinY == null) {
      _smoothedMinY = targetMin;
    } else {
      final double lowerT = targetMin < _smoothedMinY! ? 0.22 : 0.10;
      _smoothedMinY = ui.lerpDouble(_smoothedMinY, targetMin, lowerT)!;
    }

    if (_smoothedMaxY == null) {
      _smoothedMaxY = targetMax;
    } else {
      final double upperT = targetMax > _smoothedMaxY! ? 0.22 : 0.10;
      _smoothedMaxY = ui.lerpDouble(_smoothedMaxY, targetMax, upperT)!;
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _BattleChartPainter(
        seriesA: widget.seriesA,
        seriesB: widget.seriesB,
        dates: widget.dates,
        visibleStartIndex: visibleStart,
        currentIndex: safeIndex,
        renderEndIndex: renderEndIndex,
        playbackPosition: safePlaybackPosition,
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
    required this.renderEndIndex,
    required this.playbackPosition,
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
  final int renderEndIndex;
  final double playbackPosition;
  final double minY;
  final double maxY;
  final double basePriceA;
  final double basePriceB;
  final String marketCodeA;
  final String marketCodeB;
  final double lineStrokeWidth;
  final double pointRadius;
  final double pointGlowRadius;
  static const double _kTopExtraPadding = 6.0;
  static int _debugFrameCounter = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final int length = min(seriesA.length, seriesB.length);
    if (length == 0 || currentIndex < visibleStartIndex) return;

    final _BattleChartGeometry geometry = _BattleChartGeometry.create(
      size: size,
      minY: minY,
      maxY: maxY,
      lineStrokeWidth: lineStrokeWidth,
      pointGlowRadius: pointGlowRadius,
      topExtraPadding: _kTopExtraPadding,
      visibleStartIndex: visibleStartIndex,
      renderEndIndex: renderEndIndex,
      currentIndex: currentIndex,
      playbackPosition: playbackPosition,
    );

    const double yAxisWidth = 64;

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
      final double y = geometry.safeRect.top + ratio * geometry.safeRect.height;
      final double value = tickValues[i];
      canvas.drawLine(Offset(geometry.chartRect.left, y), Offset(geometry.chartRect.right, y), gridPaint);
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
      tp.paint(canvas, Offset(geometry.chartRect.right + 8, y - tp.height / 2));
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
      final Offset pa = geometry.pointFor(i, seriesA[i]);
      final Offset pb = geometry.pointFor(i, seriesB[i]);
      if (i == visibleStartIndex) {
        aPath.moveTo(pa.dx, pa.dy);
        bPath.moveTo(pb.dx, pb.dy);
      } else {
        aPath.lineTo(pa.dx, pa.dy);
        bPath.lineTo(pb.dx, pb.dy);
      }
    }

    final _HeadSegment aHead = geometry.headSegment(seriesA);
    final _HeadSegment bHead = geometry.headSegment(seriesB);

    if (aHead.nextIndex > aHead.baseIndex && aHead.t > 0) {
      aPath.lineTo(aHead.end.dx, aHead.end.dy);
    }
    if (bHead.nextIndex > bHead.baseIndex && bHead.t > 0) {
      bPath.lineTo(bHead.end.dx, bHead.end.dy);
    }

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(geometry.chartRect, const Radius.circular(10)));

    canvas.drawPath(aPath, aPaint);
    canvas.drawPath(bPath, bPaint);

    canvas.drawCircle(aHead.end, pointGlowRadius, Paint()..color = const Color(0xFFE54B4B).withOpacity(0.22));
    canvas.drawCircle(bHead.end, pointGlowRadius, Paint()..color = const Color(0xFF266DD3).withOpacity(0.22));
    canvas.drawCircle(aHead.end, pointRadius, Paint()..color = const Color(0xFFE54B4B));
    canvas.drawCircle(bHead.end, pointRadius, Paint()..color = const Color(0xFF266DD3));

    canvas.restore();

    if (kDebugMode && (_debugFrameCounter++ % 30 == 0)) {
      debugPrint(
        '[BattleChartSync] progress(index=$currentIndex,pos=${playbackPosition.toStringAsFixed(3)}) '
        'plotRect=${geometry.chartRect} yRange=[${geometry.minY.toStringAsFixed(3)},${geometry.maxY.toStringAsFixed(3)}] '
        'headA=${aHead.end} headB=${bHead.end}',
      );
    }

    _drawXLabels(canvas, geometry.chartRect, geometry.stepX, visibleStartIndex, currentIndex);
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

  String _formatPrice(double price, String _marketCode) {
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
        oldDelegate.renderEndIndex != renderEndIndex ||
        oldDelegate.playbackPosition != playbackPosition ||
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

class _BattleChartGeometry {
  _BattleChartGeometry({
    required this.chartRect,
    required this.safeRect,
    required this.minY,
    required this.maxY,
    required this.stepX,
    required this.visibleStartIndex,
    required this.currentIndex,
    required this.renderEndIndex,
    required this.playbackPosition,
  });

  factory _BattleChartGeometry.create({
    required Size size,
    required double minY,
    required double maxY,
    required double lineStrokeWidth,
    required double pointGlowRadius,
    required double topExtraPadding,
    required int visibleStartIndex,
    required int currentIndex,
    required int renderEndIndex,
    required double playbackPosition,
  }) {
    const double yAxisWidth = 64;
    const double xAxisHeight = 24;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height - xAxisHeight);
    final double verticalSafety = max(pointGlowRadius, lineStrokeWidth * 0.5) + 1;
    final double topSafety = verticalSafety + topExtraPadding;
    final Rect safeRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + topSafety,
      chartRect.right,
      chartRect.bottom - verticalSafety,
    );
    final int visibleCount = renderEndIndex - visibleStartIndex + 1;
    final double stepX = chartRect.width / max(1, visibleCount - 1);
    return _BattleChartGeometry(
      chartRect: chartRect,
      safeRect: safeRect,
      minY: minY,
      maxY: maxY,
      stepX: stepX,
      visibleStartIndex: visibleStartIndex,
      currentIndex: currentIndex,
      renderEndIndex: renderEndIndex,
      playbackPosition: playbackPosition,
    );
  }

  final Rect chartRect;
  final Rect safeRect;
  final double minY;
  final double maxY;
  final double stepX;
  final int visibleStartIndex;
  final int currentIndex;
  final int renderEndIndex;
  final double playbackPosition;

  double get _range => max(maxY - minY, 0.0001);

  Offset pointFor(int absoluteIndex, double value) {
    final double rawX = chartRect.left + (stepX * (absoluteIndex - visibleStartIndex));
    final double rawY = safeRect.bottom - ((value - minY) / _range) * safeRect.height;
    return Offset(
      rawX.clamp(chartRect.left, chartRect.right),
      rawY.clamp(safeRect.top, safeRect.bottom),
    );
  }

  _HeadSegment headSegment(List<double> series) {
    final int nextIndex = min(currentIndex + 1, renderEndIndex);
    final double t = (playbackPosition - currentIndex).clamp(0, 1);
    final Offset start = pointFor(currentIndex, series[currentIndex]);
    final Offset endPoint = pointFor(nextIndex, series[nextIndex]);
    final Offset end = Offset(
      ui.lerpDouble(start.dx, endPoint.dx, t)!,
      ui.lerpDouble(start.dy, endPoint.dy, t)!,
    );
    return _HeadSegment(baseIndex: currentIndex, nextIndex: nextIndex, t: t, end: end);
  }
}

class _HeadSegment {
  const _HeadSegment({required this.baseIndex, required this.nextIndex, required this.t, required this.end});

  final int baseIndex;
  final int nextIndex;
  final double t;
  final Offset end;
}
