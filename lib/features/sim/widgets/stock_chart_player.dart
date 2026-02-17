import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

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
  late double _minY;
  late double _maxY;
  late double _basePrice;

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
    }
  }

  void _recomputeDerivedData() {
    if (widget.points.isEmpty) {
      _allPercents = const <double>[];
      _minY = -1;
      _maxY = 1;
      _basePrice = 1;
      return;
    }

    _basePrice = widget.points.first.close <= 0 ? 1 : widget.points.first.close;
    _allPercents = widget.points
        .map((SimulationPoint point) => ((point.close / _basePrice) - 1) * 100)
        .toList(growable: false);

    double minY = _allPercents.reduce(min);
    double maxY = _allPercents.reduce(max);
    final double rawRange = maxY - minY;
    final double pad = rawRange < 0.1 ? 1.0 : max(rawRange * 0.08, 0.5);
    _minY = minY - pad;
    _maxY = maxY + pad;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.'));
    }

    final int safeIndex = widget.currentIndex.clamp(0, widget.points.length - 1);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FullPeriodPercentChartPainter(
            points: widget.points,
            allPercents: _allPercents,
            currentIndex: safeIndex,
            minY: _minY,
            maxY: _maxY,
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
    required this.currentIndex,
    required this.minY,
    required this.maxY,
    required this.pulse,
    required this.basePrice,
    required this.marketCode,
  });

  final List<SimulationPoint> points;
  final List<double> allPercents;
  final int currentIndex;
  final double minY;
  final double maxY;
  final double pulse;
  final double basePrice;
  final String marketCode;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

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

    final double range = max(maxY - minY, 0.0001);
    final double stepX = chartRect.width / (points.length - 1);

    final Paint upPaint = Paint()
      ..color = AppColors.upSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = AppColors.downSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < currentIndex; i++) {
      final Offset p1 = Offset(
        chartRect.left + i * stepX,
        chartRect.bottom - ((allPercents[i] - minY) / range) * chartRect.height,
      );
      final Offset p2 = Offset(
        chartRect.left + (i + 1) * stepX,
        chartRect.bottom - ((allPercents[i + 1] - minY) / range) * chartRect.height,
      );
      canvas.drawLine(p1, p2, allPercents[i + 1] >= allPercents[i] ? upPaint : downPaint);
    }

    final Offset currentPoint = Offset(
      chartRect.left + currentIndex * stepX,
      chartRect.bottom - ((allPercents[currentIndex] - minY) / range) * chartRect.height,
    );

    final double glowRadius = 6 + 6 * pulse;
    canvas.drawCircle(currentPoint, glowRadius, Paint()..color = AppColors.action.withOpacity(0.22));
    canvas.drawCircle(currentPoint, 4 + 2 * pulse, Paint()..color = Colors.white);

    _drawXLabels(canvas, chartRect, stepX);
  }

  void _drawXLabels(Canvas canvas, Rect chartRect, double stepX) {
    final int labelCount = 7;
    final Set<int> indices = <int>{0, points.length - 1};
    for (int i = 1; i < labelCount - 1; i++) {
      final int index = ((points.length - 1) * (i / (labelCount - 1))).round();
      indices.add(index.clamp(0, points.length - 1));
    }

    for (final int index in indices.toList()..sort()) {
      final double x = chartRect.left + index * stepX;
      final String label = _formatCompactYmd(points[index].ymd);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: AppColors.helperText, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double drawX = (x - tp.width / 2).clamp(chartRect.left, chartRect.right - tp.width);
      tp.paint(canvas, Offset(drawX, chartRect.bottom + 6));
    }
  }

  String _formatPriceLabel(double percent) {
    final double price = basePrice * (1 + percent / 100);
    if (marketCode == 'US') {
      return '\$${AppNumberFormat.formatPrice(price, decimals: 2)}';
    }
    return '${AppNumberFormat.formatInt(price)}원';
  }

  String _formatCompactYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}';
  }

  @override
  bool shouldRepaint(covariant _FullPeriodPercentChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.pulse != pulse ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.basePrice != basePrice ||
        oldDelegate.marketCode != marketCode;
  }
}
