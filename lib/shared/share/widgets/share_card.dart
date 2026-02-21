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
    final Color aColor = const Color(0xFF63B3FF);
    final Color bColor = const Color(0xFFFF7A93);

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D26),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x5A000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('그때 살걸', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFAFC4FF))),
                ),
                Flexible(
                  child: Text(payload.periodText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B5))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${payload.assetAName} vs ${payload.assetBName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _BattleMetricCell(
                    title: payload.assetAName,
                    percentText: payload.assetAReturnText,
                    finalText: payload.finalValueAText,
                    accent: aColor,
                    isWinner: payload.aWon && !payload.isTie,
                    isTie: payload.isTie,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BattleMetricCell(
                    title: payload.assetBName,
                    percentText: payload.assetBReturnText,
                    finalText: payload.finalValueBText,
                    accent: bColor,
                    isWinner: !payload.aWon && !payload.isTie,
                    isTie: payload.isTie,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              payload.initialInvestmentText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B5)),
            ),
            Text(
              payload.deltaText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: payload.isTie ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F5)),
            ),
            if (payload.shortIntersectionNotice)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('짧은 구간 결과', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF9BA3B5))),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _DualLineChartPainter(
                  seriesA: payload.seriesA,
                  seriesB: payload.seriesB,
                  aColor: aColor,
                  bColor: bColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(payload.curiosityLine, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFBFC9DA))),
            const SizedBox(height: 2),
            const Text('앱에서 직접 해보기', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8AB4FF))),
          ],
        ),
      ),
    );
  }
}

class _BattleMetricCell extends StatelessWidget {
  const _BattleMetricCell({
    required this.title,
    required this.percentText,
    required this.finalText,
    required this.accent,
    required this.isWinner,
    required this.isTie,
  });

  final String title;
  final String percentText;
  final String finalText;
  final Color accent;
  final bool isWinner;
  final bool isTie;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF242A38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWinner ? accent.withOpacity(0.75) : const Color(0x2CFFFFFF)),
        boxShadow: isWinner
            ? <BoxShadow>[BoxShadow(color: accent.withOpacity(0.22), blurRadius: 12, spreadRadius: 0.4)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
          const SizedBox(height: 4),
          Text(
            percentText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isTie ? const Color(0xFFFCD34D) : accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(finalText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFE6EAF5))),
        ],
      ),
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  const _DualLineChartPainter({
    required this.seriesA,
    required this.seriesB,
    required this.aColor,
    required this.bColor,
  });

  final List<double> seriesA;
  final List<double> seriesB;
  final Color aColor;
  final Color bColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 1;
    for (int i = 1; i <= 2; i++) {
      final double y = rect.top + (rect.height * i / 3);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }

    if (seriesA.length < 2 || seriesB.length < 2) return;

    final List<double> merged = <double>[...seriesA, ...seriesB];
    final double minValue = merged.reduce(min);
    final double maxValue = merged.reduce(max);
    final double span = (maxValue - minValue).abs() < 0.0001 ? 1 : (maxValue - minValue);

    Path buildPath(List<double> values) {
      final Path path = Path();
      final int count = values.length;
      final double stepX = rect.width / max(1, count - 1);
      for (int i = 0; i < count; i++) {
        final double t = (values[i] - minValue) / span;
        final Offset p = Offset(rect.left + (i * stepX), rect.bottom - (t * rect.height));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    Offset endPoint(List<double> values) {
      final int last = values.length - 1;
      final double t = (values[last] - minValue) / span;
      final double stepX = rect.width / max(1, values.length - 1);
      return Offset(rect.left + (last * stepX), rect.bottom - (t * rect.height));
    }

    final Paint aPaint = Paint()..color = aColor..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final Paint bPaint = Paint()..color = bColor..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    canvas.drawPath(buildPath(seriesA), aPaint);
    canvas.drawPath(buildPath(seriesB), bPaint);

    final Offset aEnd = endPoint(seriesA);
    final Offset bEnd = endPoint(seriesB);
    canvas.drawCircle(aEnd, 3.4, Paint()..color = aColor);
    canvas.drawCircle(bEnd, 3.4, Paint()..color = bColor);
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA || oldDelegate.seriesB != seriesB || oldDelegate.aColor != aColor || oldDelegate.bColor != bColor;
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
