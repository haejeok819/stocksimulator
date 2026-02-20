import 'package:stocksimulator/data/models/price_year_data.dart';

class NormalizedBattleSeries {
  const NormalizedBattleSeries({
    required this.dates,
    required this.closeA,
    required this.closeB,
  });

  final List<int> dates;
  final List<double> closeA;
  final List<double> closeB;
}

NormalizedBattleSeries normalizeBattleSeries({
  required List<PricePoint> aSeries,
  required List<PricePoint> bSeries,
}) {
  final Map<int, double> mapA = <int, double>{for (final PricePoint p in aSeries) p.ymd: p.close};
  final Map<int, double> mapB = <int, double>{for (final PricePoint p in bSeries) p.ymd: p.close};

  final List<int> dates = mapA.keys.where((int ymd) => mapB.containsKey(ymd)).toList()..sort();

  final List<double> closeA = dates.map((int ymd) => mapA[ymd]!).toList(growable: false);
  final List<double> closeB = dates.map((int ymd) => mapB[ymd]!).toList(growable: false);

  return NormalizedBattleSeries(dates: dates, closeA: closeA, closeB: closeB);
}

NormalizedBattleSeries snapNormalizedSeriesToNearestRange({
  required NormalizedBattleSeries normalized,
  required int selectedStartYmd,
  required int selectedEndYmd,
}) {
  if (normalized.dates.isEmpty) {
    return normalized;
  }

  final int snappedStart = _nearestYmd(normalized.dates, selectedStartYmd);
  final int snappedEnd = _nearestYmd(normalized.dates, selectedEndYmd);
  final int rangeStart = snappedStart <= snappedEnd ? snappedStart : snappedEnd;
  final int rangeEnd = snappedStart <= snappedEnd ? snappedEnd : snappedStart;

  final List<int> dates = <int>[];
  final List<double> closeA = <double>[];
  final List<double> closeB = <double>[];

  for (int i = 0; i < normalized.dates.length; i++) {
    final int ymd = normalized.dates[i];
    if (ymd < rangeStart || ymd > rangeEnd) {
      continue;
    }
    dates.add(ymd);
    closeA.add(normalized.closeA[i]);
    closeB.add(normalized.closeB[i]);
  }

  return NormalizedBattleSeries(dates: dates, closeA: closeA, closeB: closeB);
}

int _nearestYmd(List<int> sortedDates, int target) {
  int best = sortedDates.first;
  int bestDistance = (best - target).abs();
  for (final int ymd in sortedDates) {
    final int distance = (ymd - target).abs();
    if (distance < bestDistance) {
      best = ymd;
      bestDistance = distance;
    }
  }
  return best;
}
