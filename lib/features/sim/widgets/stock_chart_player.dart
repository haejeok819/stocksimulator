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
    required this.pulse,
    required this.marketCode,
  });

  final List<SimulationPoint> points;
  final int currentIndex;
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
    final int visibleStart = simVisibleStartIndex(totalCount: widget.points.length, currentIndex: safeIndex);

    double minY = _allPercents[visibleStart];
    double maxY = _allPercents[visibleStart];
    for (int i = visibleStart; i <= safeIndex; i++) {
      final double v = _allPercents[i];
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    final double rawRange = maxY - minY;
    final double pad = rawRange < 0.15 ? 1.2 : max(rawRange * 0.12, 0.6);
    final double targetMin = minY - pad;
    final double targetMax = maxY + pad;

    _smoothedMinY = _smoothedMinY == null ? targetMin : ui.lerpDouble(_smoothedMinY, targetMin, 0.18)!;
    _smoothedMaxY = _smoothedMaxY == null ? targetMax : ui.lerpDouble(_smoothedMaxY, targetMax, 0.18)!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FullPeriodPercentChartPainter(
            points: widget.points,
            allPercents: _allPercents,
            visibleStartIndex: visibleStart,
            currentIndex: safeIndex,
            minY: _smoothedMinY!,
            maxY: _smoothedMaxY!,
            pulse: widget.pulse,
            basePrice: _basePrice,
            marketCode: widget.marketCode,
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
    required this.minY,
    required this.maxY,
    required this.pulse,
    required this.basePrice,
    required this.marketCode,
  });

  final List<SimulationPoint> points;
  final List<double> allPercents;
  final int visibleStartIndex;
  final int currentIndex;
  final double minY;
  final double maxY;
  final double pulse;
  final double basePrice;
  final String marketCode;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || currentIndex <= visibleStartIndex) return;

    const double yAxisWidth = 64;
    const double xAxisHeight = 24;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height - xAxisHeight);

    final Paint axisPaint = Paint()..color = AppColors.helperText.withOpacity(0.3);
    const int yTickCount = 5;
    for (int i = 0; i < yTickCount; i++) {
      final double ratio = i / (yTickCount - 1);
      final double y = chartRect.top + ratio * chartRect.height;
      final double value = maxY - ratio * (maxY - minY);

      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), axisPaint);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _formatPriceLabel(value),
          style: const TextStyle(color: AppColors.helperText, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 8);
      tp.paint(canvas, Offset(chartRect.right + 8, y - tp.height / 2));
    }

    final int visibleCount = currentIndex - visibleStartIndex + 1;
    final double range = max(maxY - minY, 0.0001);
    final double stepX = chartRect.width / max(1, visibleCount - 1);

    Offset pointAt(int absoluteIndex) {
      final int local = absoluteIndex - visibleStartIndex;
      return Offset(
        chartRect.left + local * stepX,
        chartRect.bottom - ((allPercents[absoluteIndex] - minY) / range) * chartRect.height,
      );
    }

    final Paint upPaint = Paint()
      ..color = AppColors.upSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = AppColors.downSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (int i = visibleStartIndex; i < currentIndex; i++) {
      final Offset p1 = pointAt(i);
      final Offset p2 = pointAt(i + 1);
      canvas.drawLine(p1, p2, allPercents[i + 1] >= allPercents[i] ? upPaint : downPaint);
    }

    final Offset currentPoint = pointAt(currentIndex);
    final double glowRadius = 6 + 6 * pulse;
    canvas.drawCircle(currentPoint, glowRadius, Paint()..color = AppColors.action.withOpacity(0.22));
    canvas.drawCircle(currentPoint, 4 + 2 * pulse, Paint()..color = Colors.white);

    _drawXLabels(canvas, chartRect, stepX, visibleStartIndex, currentIndex);
  }

  void _drawXLabels(Canvas canvas, Rect chartRect, double stepX, int startIndex, int endIndex) {
    final int visibleCount = endIndex - startIndex + 1;
    final int labelCount = min(7, max(2, visibleCount));
    final Set<int> indices = <int>{startIndex, endIndex};
    for (int i = 1; i < labelCount - 1; i++) {
      final int index = startIndex + ((visibleCount - 1) * (i / (labelCount - 1))).round();
      indices.add(index.clamp(startIndex, endIndex));
    }

    for (final int index in indices.toList()..sort()) {
      final double x = chartRect.left + (index - startIndex) * stepX;
      final String label = _formatCompactYmd(points[index].ymd);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: AppColors.helperText, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final double drawX = (x - tp.width / 2).clamp(chartRect.left, chartRect.right - tp.width);
      tp.paint(canvas, Offset(drawX, chartRect.bottom + 6));
    }
  }

  String _formatCompactYmd(int ymd) {
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
        oldDelegate.visibleStartIndex != visibleStartIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.pulse != pulse ||
        oldDelegate.basePrice != basePrice ||
        oldDelegate.marketCode != marketCode;
  }
}
