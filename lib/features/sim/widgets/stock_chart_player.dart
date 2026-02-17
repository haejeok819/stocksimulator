import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';

class StockChartPlayer extends StatelessWidget {
  const StockChartPlayer({
    super.key,
    required this.points,
    required this.currentIndex,
    required this.pulse,
  });

  final List<SimulationPoint> points;
  final int currentIndex;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.'));
    }

    final int safeIndex = currentIndex.clamp(0, points.length - 1);
    final int start = max(0, safeIndex - 29);
    final List<SimulationPoint> visible = points.sublist(start, safeIndex + 1);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SlidingChartPainter(values: visible, pulse: pulse),
        );
      },
    );
  }
}

class _SlidingChartPainter extends CustomPainter {
  _SlidingChartPainter({required this.values, required this.pulse});

  final List<SimulationPoint> values;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    const double yAxisWidth = 56;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height);

    final List<double> yValues = values.map((SimulationPoint p) => p.value).toList();
    final double minValue = yValues.reduce(min);
    final double maxValue = yValues.reduce(max);
    final double range = (maxValue - minValue).abs() < 0.001 ? 1 : (maxValue - minValue);
    final double stepX = chartRect.width / (values.length - 1);

    final Paint upPaint = Paint()
      ..color = AppColors.upSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = AppColors.downSegment
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < values.length - 1; i++) {
      final Offset p1 = Offset(
        chartRect.left + i * stepX,
        chartRect.bottom - ((values[i].value - minValue) / range) * chartRect.height,
      );
      final Offset p2 = Offset(
        chartRect.left + (i + 1) * stepX,
        chartRect.bottom - ((values[i + 1].value - minValue) / range) * chartRect.height,
      );
      canvas.drawLine(p1, p2, values[i + 1].value > values[i].value ? upPaint : downPaint);
    }

    final SimulationPoint last = values.last;
    final Offset lastPoint = Offset(
      chartRect.left + (values.length - 1) * stepX,
      chartRect.bottom - ((last.value - minValue) / range) * chartRect.height,
    );

    final double glowRadius = 6 + 6 * pulse;
    canvas.drawCircle(
      lastPoint,
      glowRadius,
      Paint()..color = AppColors.action.withOpacity(0.22),
    );
    canvas.drawCircle(lastPoint, 4 + 2 * pulse, Paint()..color = Colors.white);

    final Paint axisPaint = Paint()..color = AppColors.helperText.withOpacity(0.3);
    const int tickCount = 4;
    for (int i = 0; i < tickCount; i++) {
      final double ratioTick = i / (tickCount - 1);
      final double value = maxValue - ratioTick * (maxValue - minValue);
      final double y = chartRect.top + ratioTick * chartRect.height;

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _compact(value),
          style: const TextStyle(color: AppColors.helperText, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 8);
      tp.paint(canvas, Offset(chartRect.right + 8, y - tp.height / 2));
    }
  }

  String _compact(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _SlidingChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.pulse != pulse;
  }
}
