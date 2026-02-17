import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';

class StockChartPlayer extends StatefulWidget {
  const StockChartPlayer({
    super.key,
    required this.series,
    required this.onFinished,
  });

  final List<double> series;
  final VoidCallback onFinished;

  @override
  State<StockChartPlayer> createState() => _StockChartPlayerState();
}

class _StockChartPlayerState extends State<StockChartPlayer> {
  int _currentFrame = 30;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted && _currentFrame < widget.series.length) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) {
        return;
      }
      setState(() {
        _currentFrame += 1;
      });
    }

    if (mounted) {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int start = max(0, _currentFrame - 30);
    final List<double> visible = widget.series.sublist(start, _currentFrame);

    return CustomPaint(
      painter: _SlidingChartPainter(values: visible),
      size: Size.infinite,
    );
  }
}

class _SlidingChartPainter extends CustomPainter {
  _SlidingChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final double minValue = values.reduce(min);
    final double maxValue = values.reduce(max);
    final double range = (maxValue - minValue).abs() < 0.001 ? 1 : (maxValue - minValue);
    final double stepX = size.width / (values.length - 1);

    final Paint upPaint = Paint()
      ..color = AppColors.upSegment
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = AppColors.downSegment
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < values.length - 1; i++) {
      final Offset p1 = Offset(
        i * stepX,
        size.height - ((values[i] - minValue) / range) * size.height,
      );
      final Offset p2 = Offset(
        (i + 1) * stepX,
        size.height - ((values[i + 1] - minValue) / range) * size.height,
      );
      canvas.drawLine(p1, p2, values[i + 1] >= values[i] ? upPaint : downPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SlidingChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
