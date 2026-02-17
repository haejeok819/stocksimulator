import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BattleLineChart extends StatelessWidget {
  const BattleLineChart({
    super.key,
    required this.seriesA,
    required this.seriesB,
    required this.progressListenable,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final ValueListenable<int> progressListenable;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BattleLineChartPainter(
        seriesA: seriesA,
        seriesB: seriesB,
        progressListenable: progressListenable,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BattleLineChartPainter extends CustomPainter {
  _BattleLineChartPainter({
    required this.seriesA,
    required this.seriesB,
    required this.progressListenable,
  }) : super(repaint: progressListenable);

  final List<double> seriesA;
  final List<double> seriesB;
  final ValueListenable<int> progressListenable;

  @override
  void paint(Canvas canvas, Size size) {
    if (seriesA.isEmpty || seriesB.isEmpty) {
      return;
    }

    final int end = progressListenable.value.clamp(0, seriesA.length - 1);
    final Iterable<double> visibleA = seriesA.take(end + 1);
    final Iterable<double> visibleB = seriesB.take(end + 1);
    final double minValue = [...visibleA, ...visibleB].reduce((double a, double b) => a < b ? a : b);
    final double maxValue = [...visibleA, ...visibleB].reduce((double a, double b) => a > b ? a : b);
    final double range = (maxValue - minValue).abs() < 1 ? 1 : (maxValue - minValue);

    Offset pointFor(int i, double v) {
      final double x = end == 0 ? 0 : (size.width * i / end);
      final double y = size.height - ((v - minValue) / range) * size.height;
      return Offset(x, y);
    }

    final Paint aPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5677E7);

    final Paint bPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFF59E0B);

    final Path aPath = Path();
    final Path bPath = Path();

    for (int i = 0; i <= end; i++) {
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
  }

  @override
  bool shouldRepaint(covariant _BattleLineChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA || oldDelegate.seriesB != seriesB;
  }
}
