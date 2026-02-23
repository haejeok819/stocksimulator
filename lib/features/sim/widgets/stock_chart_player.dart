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
    this.buyIndex,
    this.sellIndex,
    this.referencePrice,
  });

  final List<SimulationPoint> points;
  final int currentIndex;
  final double playbackPosition;
  final double pulse;
  final int? buyIndex;
  final int? sellIndex;
  final double? referencePrice;

  @override
  State<StockChartPlayer> createState() => _StockChartPlayerState();
}

class _StockChartPlayerState extends State<StockChartPlayer> {
  late List<double> _allPercents;
  late List<String> _compactDateLabels;
  late List<String> _focusDateLabels;
  late double _basePrice;
  double? _smoothedMinY;
  double? _smoothedMaxY;
  double? _targetMinY;
  double? _targetMaxY;
  double? _axisStep;
  int _shrinkHoldFrames = 0;
  int _stableInsideFrames = 0;
  int _lastVisibleCount = 0;

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
      _targetMinY = null;
      _targetMaxY = null;
      _axisStep = null;
      _shrinkHoldFrames = 0;
      _stableInsideFrames = 0;
      _lastVisibleCount = 0;
    }
  }

  void _recomputeDerivedData() {
    if (widget.points.isEmpty) {
      _allPercents = const <double>[];
      _compactDateLabels = const <String>[];
      _focusDateLabels = const <String>[];
      _basePrice = 1;
      return;
    }

    _basePrice = widget.points.first.close <= 0 ? 1 : widget.points.first.close;
    _allPercents = widget.points
        .map((SimulationPoint point) => ((point.close / _basePrice) - 1) * 100)
        .toList(growable: false);
    _compactDateLabels = widget.points
        .map((SimulationPoint point) => _formatCompactYmd(point.ymd))
        .toList(growable: false);
    _focusDateLabels = widget.points
        .map((SimulationPoint point) => _formatFocusYmd(point.ymd))
        .toList(growable: false);
  }

  String _formatCompactYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}';
  }

  String _formatFocusYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(2, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.'));
    }

    final double safePlaybackPosition = widget.playbackPosition.clamp(0, (widget.points.length - 1).toDouble());
    final int safeIndex = safePlaybackPosition.floor();
    final int renderEndIndex = safePlaybackPosition.ceil();
    final int visibleStart = simVisibleStartIndex(totalCount: widget.points.length, currentIndex: renderEndIndex);

    double minY = _allPercents[visibleStart];
    double maxY = _allPercents[visibleStart];
    for (int i = visibleStart; i <= renderEndIndex; i++) {
      final double v = _allPercents[i];
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    const double minVisualRange = 6.0;
    const double nearBoundaryThreshold = 0.80;
    const double desiredOccupancy = 0.72;
    final double rawRange = max(maxY - minY, minVisualRange * 0.35);
    final double baseHeadroom = max(rawRange * 0.14, 0.8);

    double targetMin = minY - baseHeadroom;
    double targetMax = maxY + baseHeadroom;

    if (_smoothedMinY != null && _smoothedMaxY != null) {
      final double previousMin = _smoothedMinY!;
      final double previousMax = _smoothedMaxY!;
      final double previousRange = max(previousMax - previousMin, minVisualRange);

      final double upperTrigger = previousMin + (previousRange * nearBoundaryThreshold);
      if (maxY >= upperTrigger) {
        final double expandedRange = (maxY - previousMin) / desiredOccupancy;
        targetMax = max(targetMax, previousMin + expandedRange);
      }

      final double lowerTrigger = previousMax - (previousRange * nearBoundaryThreshold);
      if (minY <= lowerTrigger) {
        final double expandedRange = (previousMax - minY) / desiredOccupancy;
        targetMin = min(targetMin, previousMax - expandedRange);
      }
    }

    if ((targetMax - targetMin) < minVisualRange) {
      final double mid = (targetMax + targetMin) / 2;
      targetMin = mid - minVisualRange / 2;
      targetMax = mid + minVisualRange / 2;
    }

    final int visibleCount = renderEndIndex - visibleStart + 1;
    final bool windowGrowing = visibleCount > _lastVisibleCount;
    _lastVisibleCount = visibleCount;

    if (_targetMinY == null || _targetMaxY == null) {
      _targetMinY = targetMin;
      _targetMaxY = targetMax;
      _shrinkHoldFrames = 20;
    } else {
      final double currentTargetRange = max(_targetMaxY! - _targetMinY!, minVisualRange);
      final double minDeltaRatio = (targetMin - _targetMinY!).abs() / currentTargetRange;
      final double maxDeltaRatio = (targetMax - _targetMaxY!).abs() / currentTargetRange;
      final bool inDeadband = minDeltaRatio < 0.015 && maxDeltaRatio < 0.015;
      if (inDeadband) {
        targetMin = _targetMinY!;
        targetMax = _targetMaxY!;
      }

      final bool expansionRequested = targetMin < _targetMinY! || targetMax > _targetMaxY!;
      if (expansionRequested || windowGrowing) {
        _targetMinY = min(_targetMinY!, targetMin);
        _targetMaxY = max(_targetMaxY!, targetMax);
        _shrinkHoldFrames = windowGrowing ? 24 : 14;
        _stableInsideFrames = 0;
      } else {
        if (_shrinkHoldFrames > 0) {
          _shrinkHoldFrames -= 1;
        }
        final double comfortMargin = currentTargetRange * 0.20;
        final bool comfortablyInside =
            minY > _targetMinY! + comfortMargin && maxY < _targetMaxY! - comfortMargin;
        _stableInsideFrames = comfortablyInside ? _stableInsideFrames + 1 : 0;
        if (_shrinkHoldFrames == 0 && _stableInsideFrames >= 10) {
          _targetMinY = ui.lerpDouble(_targetMinY, targetMin, 0.06)!;
          _targetMaxY = ui.lerpDouble(_targetMaxY, targetMax, 0.06)!;
        }
      }
    }

    if (_smoothedMinY == null) {
      _smoothedMinY = _targetMinY;
    } else {
      final double lowerT = _targetMinY! < _smoothedMinY! ? 0.35 : 0.08;
      _smoothedMinY = ui.lerpDouble(_smoothedMinY, _targetMinY, lowerT)!;
    }

    if (_smoothedMaxY == null) {
      _smoothedMaxY = _targetMaxY;
    } else {
      final double upperT = _targetMaxY! > _smoothedMaxY! ? 0.35 : 0.08;
      _smoothedMaxY = ui.lerpDouble(_smoothedMaxY, _targetMaxY, upperT)!;
    }

    final double smoothedRange = max(_smoothedMaxY! - _smoothedMinY!, minVisualRange);
    final double desiredStep = max(smoothedRange / 3, minVisualRange / 3);
    if (_axisStep == null) {
      _axisStep = desiredStep;
    } else {
      final double stepDeltaRatio = (desiredStep - _axisStep!).abs() / max(_axisStep!, 0.0001);
      if (stepDeltaRatio > 0.12) {
        _axisStep = ui.lerpDouble(_axisStep, desiredStep, 0.28)!;
      }
    }

    final double midY = (_smoothedMinY! + _smoothedMaxY!) / 2;
    final double half = max((_axisStep ?? desiredStep) * 1.5, minVisualRange / 2);
    _smoothedMinY = midY - half;
    _smoothedMaxY = midY + half;

    final double stabilizedRange = max(_smoothedMaxY! - _smoothedMinY!, minVisualRange);
    final double guardBand = max(stabilizedRange * 0.12, baseHeadroom * 0.45);
    if (maxY > _smoothedMaxY! - guardBand) {
      _smoothedMaxY = maxY + guardBand;
    }
    if (minY < _smoothedMinY! + guardBand) {
      _smoothedMinY = minY - guardBand;
    }

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
            compactDateLabels: _compactDateLabels,
            focusDateLabels: _focusDateLabels,
            visibleStartIndex: visibleStart,
            currentIndex: safeIndex,
            renderEndIndex: renderEndIndex,
            playbackPosition: safePlaybackPosition,
            minY: _smoothedMinY!,
            maxY: _smoothedMaxY!,
            pulse: widget.pulse,
            basePrice: _basePrice,
            lineStrokeWidth: _kLineStroke,
            pointRadius: _kPointRadius,
            pointGlowRadius: _kPointGlow,
            buyIndex: widget.buyIndex,
            sellIndex: widget.sellIndex,
            referencePrice: widget.referencePrice,
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
    required this.compactDateLabels,
    required this.focusDateLabels,
    required this.visibleStartIndex,
    required this.currentIndex,
    required this.renderEndIndex,
    required this.playbackPosition,
    required this.minY,
    required this.maxY,
    required this.pulse,
    required this.basePrice,
    required this.lineStrokeWidth,
    required this.pointRadius,
    required this.pointGlowRadius,
    required this.buyIndex,
    required this.sellIndex,
    required this.referencePrice,
  });

  final List<SimulationPoint> points;
  final List<double> allPercents;
  final List<String> compactDateLabels;
  final List<String> focusDateLabels;
  final int visibleStartIndex;
  final int currentIndex;
  final int renderEndIndex;
  final double playbackPosition;
  final double minY;
  final double maxY;
  final double pulse;
  final int? buyIndex;
  final int? sellIndex;
  final double? referencePrice;
  final double basePrice;
  final double lineStrokeWidth;
  final double pointRadius;
  final double pointGlowRadius;

  static const double _kTopExtraPadding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || currentIndex < visibleStartIndex) return;

    const double yAxisWidth = 64;
    const double xAxisHeight = 24;
    final Rect chartRect = Rect.fromLTWH(0, 0, size.width - yAxisWidth, size.height - xAxisHeight);
    final double verticalSafety = max(pointGlowRadius, lineStrokeWidth * 0.5) + 1;
    final double topSafety = verticalSafety + _kTopExtraPadding;
    final Rect safeRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + topSafety,
      chartRect.right,
      chartRect.bottom - verticalSafety,
    );

    final Paint axisPaint = Paint()..color = AppColors.helperText.withOpacity(0.12);
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

    final double currentPrice = points[currentIndex].close;
    if (referencePrice != null && referencePrice! > 0) {
      final double refPercent = ((referencePrice! / basePrice) - 1) * 100;
      final double refY = safeRect.bottom - ((refPercent - minY) / range) * safeRect.height;
      if (refY >= safeRect.top && refY <= safeRect.bottom) {
        final Paint refPaint = Paint()
          ..color = AppColors.helperText.withOpacity(0.28)
          ..strokeWidth = 1.2;
        const double dash = 6;
        const double gap = 4;
        double x = chartRect.left;
        while (x < chartRect.right) {
          canvas.drawLine(Offset(x, refY), Offset(min(x + dash, chartRect.right), refY), refPaint);
          x += dash + gap;
        }
      }

      final Color tintColor = currentPrice >= referencePrice!
          ? AppColors.upSegment.withOpacity(0.035)
          : AppColors.downSegment.withOpacity(0.035);
      canvas.drawRect(chartRect, Paint()..color = tintColor);
    }

    for (int i = visibleStartIndex; i < currentIndex; i++) {
      final Offset p1 = pointAt(i);
      final Offset p2 = pointAt(i + 1);
      canvas.drawLine(p1, p2, allPercents[i + 1] >= allPercents[i] ? upPaint : downPaint);
    }

    final int nextIndex = min(currentIndex + 1, points.length - 1);
    final double segmentT = (playbackPosition - currentIndex).clamp(0, 1);

    final Offset segmentStart = pointAt(currentIndex);
    final Offset segmentEnd = pointAt(nextIndex);
    final Offset currentPoint = Offset(
      ui.lerpDouble(segmentStart.dx, segmentEnd.dx, segmentT)!,
      ui.lerpDouble(segmentStart.dy, segmentEnd.dy, segmentT)!,
    );

    if (nextIndex > currentIndex && segmentT > 0) {
      canvas.drawLine(
        segmentStart,
        currentPoint,
        allPercents[nextIndex] >= allPercents[currentIndex] ? upPaint : downPaint,
      );
    }

    final double glowRadius = pointGlowRadius * (0.72 + 0.28 * pulse);
    canvas.drawCircle(currentPoint, glowRadius, Paint()..color = AppColors.action.withOpacity(0.20));
    canvas.drawCircle(currentPoint, pointRadius + 2.4 * pulse, Paint()..color = Colors.white);

    final String currentPriceLabel = '${AppNumberFormat.formatInt(currentPrice)}원';
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        text: currentPriceLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double labelPadX = 8;
    final double labelWidth = labelPainter.width + labelPadX * 2;
    final double labelHeight = labelPainter.height + 6;
    final double desiredLeft = currentPoint.dx + 8;
    final double labelLeft = desiredLeft + labelWidth > chartRect.right
        ? currentPoint.dx - labelWidth - 8
        : desiredLeft;
    final double labelTop = (currentPoint.dy - labelHeight - 6)
        .clamp(safeRect.top + 2, safeRect.bottom - labelHeight - 2);
    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()..color = AppColors.surface.withOpacity(0.92),
    );
    labelPainter.paint(canvas, Offset(labelLeft + labelPadX, labelTop + 3));

    if (buyIndex != null && buyIndex! >= visibleStartIndex && buyIndex! <= renderEndIndex) {
      final Offset buyPoint = pointAt(buyIndex!);
      canvas.drawCircle(buyPoint, pointRadius + 1.8, Paint()..color = AppColors.action);
    }
    if (sellIndex != null && sellIndex! >= visibleStartIndex && sellIndex! <= renderEndIndex) {
      final Offset sellPoint = pointAt(sellIndex!);
      canvas.drawCircle(sellPoint, pointRadius + 1.8, Paint()..color = AppColors.upSegment);
    }

    canvas.restore();

    _drawXLabels(canvas, chartRect, stepX, visibleStartIndex, currentIndex);
  }

  void _drawXLabels(Canvas canvas, Rect chartRect, double stepX, int startIndex, int endIndex) {
    final int visibleCount = endIndex - startIndex + 1;
    final int midIndex = visibleCount >= 36 ? startIndex + ((visibleCount - 1) * 0.55).round() : -1;

    double lastRight = -1e9;
    for (final int index in <int>[startIndex, if (midIndex >= 0) midIndex, endIndex]) {
      final double x = chartRect.left + (index - startIndex) * stepX;
      final String label = index == endIndex ? focusDateLabels[index] : compactDateLabels[index];
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
        oldDelegate.lineStrokeWidth != lineStrokeWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.pointGlowRadius != pointGlowRadius ||
        oldDelegate.buyIndex != buyIndex ||
        oldDelegate.sellIndex != sellIndex ||
        oldDelegate.referencePrice != referencePrice;
  }
}
