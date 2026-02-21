import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

class ShareChartCard extends StatelessWidget {
  const ShareChartCard({
    super.key,
    required this.boundaryKey,
    required this.payload,
    required this.chartValues,
  });

  final GlobalKey boundaryKey;
  final SimulationSharePayload payload;
  final List<double> chartValues;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF191C24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('그때 살걸', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFAFC4FF))),
            const SizedBox(height: 10),
            _BadgePill(text: payload.badgeText),
            const SizedBox(height: 10),
            Text(payload.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(payload.periodText, style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _MinimalChartPainter(
                  values: chartValues,
                  lineColor: const Color(0xFF8AB4FF),
                  dotColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: Text(payload.investText, style: const TextStyle(fontSize: 12, color: Color(0xFFB8BBC4)))),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF7D8598)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    payload.finalText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB8BBC4)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(payload.returnText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class BattleShareCard extends StatelessWidget {
  const BattleShareCard({super.key, required this.boundaryKey, required this.payload});

  final GlobalKey boundaryKey;
  final BattleSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF22222B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('그때 살걸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _BadgePill(text: payload.badgeText),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: _VsCell(title: payload.aTitle, value: payload.aReturnText)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                Expanded(child: _VsCell(title: payload.bTitle, value: payload.bReturnText)),
              ],
            ),
            const SizedBox(height: 12),
            Text(payload.winnerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF8AB4FF))),
            const SizedBox(height: 8),
            Text(payload.periodText, style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            const Text('나도 해보기', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8AB4FF))),
          ],
        ),
      ),
    );
  }
}

class _MinimalChartPainter extends CustomPainter {
  const _MinimalChartPainter({required this.values, required this.lineColor, required this.dotColor});

  final List<double> values;
  final Color lineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 1; i <= 2; i++) {
      final double y = chartRect.top + (chartRect.height * i / 3);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    if (values.length < 2) {
      return;
    }

    final double minValue = values.reduce(min);
    final double maxValue = values.reduce(max);
    final double span = (maxValue - minValue).abs() < 0.0001 ? 1 : (maxValue - minValue);

    final Path path = Path();
    final double stepX = chartRect.width / (values.length - 1);
    Offset? firstPoint;
    Offset? lastPoint;

    for (int i = 0; i < values.length; i++) {
      final double t = (values[i] - minValue) / span;
      final double x = chartRect.left + (i * stepX);
      final double y = chartRect.bottom - (t * chartRect.height);
      final Offset point = Offset(x, y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        firstPoint = point;
      } else {
        path.lineTo(point.dx, point.dy);
      }
      lastPoint = point;
    }

    final Paint linePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF8AB4FF), Color(0xFF5EEAD4)],
      ).createShader(chartRect)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final Paint startPaint = Paint()..color = dotColor.withOpacity(0.85);
    final Paint endPaint = Paint()..color = const Color(0xFF5EEAD4);
    if (firstPoint != null) {
      canvas.drawCircle(firstPoint, 3.2, startPaint);
    }
    if (lastPoint != null) {
      canvas.drawCircle(lastPoint, 4, endPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.lineColor != lineColor || oldDelegate.dotColor != dotColor;
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2F3442),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _VsCell extends StatelessWidget {
  const _VsCell({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
