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

  final int startIndex = _nearestYmdIndex(normalized.dates, selectedStartYmd);
  final int endIndex = _nearestYmdIndex(normalized.dates, selectedEndYmd);
  final int from = startIndex <= endIndex ? startIndex : endIndex;
  final int to = startIndex <= endIndex ? endIndex : startIndex;
  final int exclusiveEnd = to + 1;

  final List<int> dates = normalized.dates.sublist(from, exclusiveEnd);
  final List<double> closeA = normalized.closeA.sublist(from, exclusiveEnd);
  final List<double> closeB = normalized.closeB.sublist(from, exclusiveEnd);

  return NormalizedBattleSeries(dates: dates, closeA: closeA, closeB: closeB);
}

int _nearestYmdIndex(List<int> sortedDates, int target) {
  if (sortedDates.length == 1) {
    return 0;
  }

  final int insertionIndex = _lowerBound(sortedDates, target);
  if (insertionIndex <= 0) {
    return 0;
  }
  if (insertionIndex >= sortedDates.length) {
    return sortedDates.length - 1;
  }

  final int leftIndex = insertionIndex - 1;
  final int rightIndex = insertionIndex;
  final int leftDistance = (sortedDates[leftIndex] - target).abs();
  final int rightDistance = (sortedDates[rightIndex] - target).abs();
  return leftDistance <= rightDistance ? leftIndex : rightIndex;
}

int _lowerBound(List<int> sortedValues, int target) {
  int low = 0;
  int high = sortedValues.length;
  while (low < high) {
    final int mid = low + ((high - low) >> 1);
    if (sortedValues[mid] < target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}
