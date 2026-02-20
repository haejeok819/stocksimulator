import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

int simVisibleStartIndex({required int totalCount, required int currentIndex}) {
  if (totalCount <= 2) return 0;
  final int safe = currentIndex.clamp(0, totalCount - 1);
  final double t = safe / (totalCount - 1);
  final double eased = sqrt(t);
  final int minWindow = max(12, (totalCount * 0.08).round()).clamp(2, totalCount);
  final int window = (minWindow + ((totalCount - minWindow) * eased)).round().clamp(minWindow, totalCount);
  if (safe >= totalCount - 1) return 0;
  return max(0, safe - window + 1);
}

class StockChartPlayer extends StatefulWidget {
  const StockChartPlayer({
    super.key,
    required this.points,
    required this.currentIndex,
    required this.playbackPosition,
    required this.pulse,
    required this.marketCode,
  });

  final List<SimulationPoint> points;
  final int currentIndex;
  final double playbackPosition;
  final double pulse;
  final String marketCode;

  @override
  State<StockChartPlayer> createState() => _StockChartPlayerState();
}

class _StockChartPlayerState extends State<StockChartPlayer> {
  late List<double> _allPercents;
  late double _basePrice;
  double? _smoothedMinY;
  double? _smoothedMaxY;

  static const double _kLineStroke = 2.7;
  static const double _kPointRadius = 4.8;
  static const double _kPointGlow = 15.0;

  @override
  void initState() {
    super.initState();
    _recomputeDerivedData();
  }

  @override
  void didUpdateWidget(covariant StockChartPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points) || oldWidget.points.length != widget.points.length) {
      _recomputeDerivedData();
      _smoothedMinY = null;
      _smoothedMaxY = null;
    }
  }

  void _recomputeDerivedData() {
    if (widget.points.isEmpty) {
      _allPercents = const <double>[];
      _basePrice = 1;
      return;
    }

    _basePrice = widget.points.first.close <= 0 ? 1 : widget.points.first.close;
    _allPercents = widget.points
        .map((SimulationPoint point) => ((point.close / _basePrice) - 1) * 100)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.'));
    }

    final int safeIndex = widget.currentIndex.clamp(0, widget.points.length - 1);
    final int renderEndIndex = widget.playbackPosition.ceil().clamp(0, widget.points.length - 1);
    final int visibleStart = simVisibleStartIndex(totalCount: widget.points.length, currentIndex: renderEndIndex);

    double minY = _allPercents[visibleStart];
    double maxY = _allPercents[visibleStart];
    for (int i = visibleStart; i <= renderEndIndex; i++) {
      final double v = _allPercents[i];
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    final double rawRange = maxY - minY;
    final double pad = rawRange < 0.15 ? 1.2 : max(rawRange * 0.12, 0.6);
    double targetMin = minY - pad;
    double targetMax = maxY + pad;

    const double minVisualRange = 6.0;
    if ((targetMax - targetMin) < minVisualRange) {
      final double mid = (targetMax + targetMin) / 2;
      targetMin = mid - minVisualRange / 2;
      targetMax = mid + minVisualRange / 2;
    }

    _smoothedMinY = _smoothedMinY == null ? targetMin : ui.lerpDouble(_smoothedMinY, targetMin, 0.16)!;
    _smoothedMaxY = _smoothedMaxY == null ? targetMax : ui.lerpDouble(_smoothedMaxY, targetMax, 0.16)!;

    if ((_smoothedMaxY! - _smoothedMinY!) < minVisualRange) {
      final double mid = (_smoothedMaxY! + _smoothedMinY!) / 2;
      _smoothedMinY = mid - minVisualRange / 2;
      _smoothedMaxY = mid + minVisualRange / 2;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FullPeriodPercentChartPainter(
            points: widget.points,
            allPercents: _allPercents,
            visibleStartIndex: visibleStart,
            currentIndex: safeIndex,
            renderEndIndex: renderEndIndex,
            playbackPosition: widget.playbackPosition,
            minY: _smoothedMinY!,
            maxY: _smoothedMaxY!,
            pulse: widget.pulse,
            basePrice: _basePrice,
            marketCode: widget.marketCode,
            lineStrokeWidth: _kLineStroke,
            pointRadius: _kPointRadius,
            pointGlowRadius: _kPointGlow,
          ),
        );
      },
    );
  }
}

class _FullPeriodPercentChartPainter extends CustomPainter {
  _FullPeriodPercentChartPainter({
    required this.points,
    required this.allPercents,
    required this.visibleStartIndex,
    required this.currentIndex,
    required this.renderEndIndex,
    required this.playbackPosition,
    required this.minY,
    required this.maxY,
    required this.pulse,
    required this.basePrice,
    required this.marketCode,
    required this.lineStrokeWidth,
    required this.pointRadius,
    required this.pointGlowRadius,
  });

  final List<SimulationPoint> points;
  final List<double> allPercents;
  final int visibleStartIndex;
  final int currentIndex;
  final int renderEndIndex;
  final double playbackPosition;
  final double minY;
  final double maxY;
  final double pulse;
  final double basePrice;
  final String marketCode;
  final double lineStrokeWidth;
  final double pointRadius;
  final double pointGlowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || currentIndex < visibleStartIndex) return;

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

    final Paint axisPaint = Paint()..color = AppColors.helperText.withOpacity(0.18);
    const int yTickCount = 4;
    final double currentPercent = allPercents[currentIndex];
    double nearestTickDist = double.infinity;
    int nearestTick = 0;
    final List<double> tickValues = <double>[];
    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      tickValues.add(maxY - ratio * (maxY - minY));
      final double d = (tickValues.last - currentPercent).abs();
      if (d < nearestTickDist) {
        nearestTickDist = d;
        nearestTick = i;
      }
    }

    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      final double y = safeRect.top + ratio * safeRect.height;
      final double value = tickValues[i];
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), axisPaint);

      final bool isCurrentBand = i == nearestTick;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _formatPriceLabel(value),
          style: TextStyle(
            color: isCurrentBand ? AppColors.helperText.withOpacity(0.92) : AppColors.helperText.withOpacity(0.60),
            fontSize: 11,
            fontWeight: isCurrentBand ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 8);
      tp.paint(canvas, Offset(chartRect.right + 8, y - tp.height / 2));
    }

    final int visibleCount = renderEndIndex - visibleStartIndex + 1;
    final double range = max(maxY - minY, 0.0001);
    final double stepX = chartRect.width / max(1, visibleCount - 1);

    Offset pointAt(int absoluteIndex) {
      final int local = absoluteIndex - visibleStartIndex;
      final double rawX = chartRect.left + local * stepX;
      final double rawY = safeRect.bottom - ((allPercents[absoluteIndex] - minY) / range) * safeRect.height;
      return Offset(
        rawX.clamp(chartRect.left, chartRect.right),
        rawY.clamp(safeRect.top, safeRect.bottom),
      );
    }

    final Paint upPaint = Paint()
      ..color = AppColors.upSegment.withOpacity(0.84)
      ..strokeWidth = lineStrokeWidth
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = AppColors.downSegment.withOpacity(0.84)
      ..strokeWidth = lineStrokeWidth
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(chartRect, const Radius.circular(10)));

    for (int i = visibleStartIndex; i < currentIndex; i++) {
      final Offset p1 = pointAt(i);
      final Offset p2 = pointAt(i + 1);
      canvas.drawLine(p1, p2, allPercents[i + 1] >= allPercents[i] ? upPaint : downPaint);
    }

    final int nextIndex = min(currentIndex + 1, points.length - 1);
    final double segmentT = (playbackPosition - currentIndex).clamp(0, 1);
    if (nextIndex > currentIndex && segmentT > 0) {
      final Offset p1 = pointAt(currentIndex);
      final Offset p2 = pointAt(nextIndex);
      final Offset partial = Offset(
        ui.lerpDouble(p1.dx, p2.dx, segmentT)!,
        ui.lerpDouble(p1.dy, p2.dy, segmentT)!,
      );
      canvas.drawLine(p1, partial, allPercents[nextIndex] >= allPercents[currentIndex] ? upPaint : downPaint);
    }

    final double currentPercent = ui.lerpDouble(
      allPercents[currentIndex],
      allPercents[nextIndex],
      segmentT,
    )!;
    final int localCurrent = currentIndex - visibleStartIndex;
    final double currentX = chartRect.left + (localCurrent + segmentT) * stepX;
    final double currentY = safeRect.bottom - ((currentPercent - minY) / range) * safeRect.height;
    final Offset currentPoint = Offset(
      currentX.clamp(chartRect.left, chartRect.right),
      currentY.clamp(safeRect.top, safeRect.bottom),
    );

    final double glowRadius = pointGlowRadius * (0.72 + 0.28 * pulse);
    canvas.drawCircle(currentPoint, glowRadius, Paint()..color = AppColors.action.withOpacity(0.26));
    canvas.drawCircle(currentPoint, pointRadius + 2.4 * pulse, Paint()..color = Colors.white);

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
      final String label = index == endIndex ? _formatFocusYmd(points[index].ymd) : _formatCompactYmd(points[index].ymd);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: AppColors.helperText.withOpacity(0.68), fontSize: 10)),
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

  String _formatCompactYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}';
  }

  String _formatFocusYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatPriceLabel(double percent) {
    final double price = basePrice * (1 + percent / 100);
    return '${AppNumberFormat.formatInt(price)}원';
  }

  @override
  bool shouldRepaint(covariant _FullPeriodPercentChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.renderEndIndex != renderEndIndex ||
        oldDelegate.playbackPosition != playbackPosition ||
        oldDelegate.visibleStartIndex != visibleStartIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.pulse != pulse ||
        oldDelegate.basePrice != basePrice ||
        oldDelegate.marketCode != marketCode ||
        oldDelegate.lineStrokeWidth != lineStrokeWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.pointGlowRadius != pointGlowRadius;
  }
}
