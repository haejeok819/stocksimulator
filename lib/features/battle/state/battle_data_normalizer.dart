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

const NormalizedBattleSeries _emptyNormalizedBattleSeries =
    NormalizedBattleSeries(dates: <int>[], closeA: <double>[], closeB: <double>[]);

NormalizedBattleSeries normalizeBattleSeries({
  required List<PricePoint> aSeries,
  required List<PricePoint> bSeries,
}) {
  if (aSeries.isEmpty || bSeries.isEmpty) {
    return _emptyNormalizedBattleSeries;
  }

  final List<PricePoint> sortedA = _ensureSortedByDate(aSeries);
  final List<PricePoint> sortedB = _ensureSortedByDate(bSeries);
  final int maxIntersectionLength =
      sortedA.length < sortedB.length ? sortedA.length : sortedB.length;

  final List<int> dates = List<int>.filled(maxIntersectionLength, 0);
  final List<double> closeA = List<double>.filled(maxIntersectionLength, 0);
  final List<double> closeB = List<double>.filled(maxIntersectionLength, 0);
  int writeIndex = 0;
  int i = 0;
  int j = 0;
  while (i < sortedA.length && j < sortedB.length) {
    final PricePoint pointA = sortedA[i];
    final PricePoint pointB = sortedB[j];

    if (pointA.ymd == pointB.ymd) {
      dates[writeIndex] = pointA.ymd;
      closeA[writeIndex] = pointA.close;
      closeB[writeIndex] = pointB.close;
      writeIndex += 1;
      i += 1;
      j += 1;
      continue;
    }

    if (pointA.ymd < pointB.ymd) {
      i += 1;
    } else {
      j += 1;
    }
  }

  if (writeIndex == 0) {
    return _emptyNormalizedBattleSeries;
  }

  if (writeIndex != maxIntersectionLength) {
    dates.length = writeIndex;
    closeA.length = writeIndex;
    closeB.length = writeIndex;
  }

  return NormalizedBattleSeries(
    dates: List<int>.unmodifiable(dates),
    closeA: List<double>.unmodifiable(closeA),
    closeB: List<double>.unmodifiable(closeB),
  );
}

List<PricePoint> _ensureSortedByDate(List<PricePoint> values) {
  if (_isSortedByDate(values)) {
    return values;
  }

  return List<PricePoint>.from(values)
    ..sort((PricePoint l, PricePoint r) => l.ymd.compareTo(r.ymd));
}

bool _isSortedByDate(List<PricePoint> values) {
  if (values.length < 2) {
    return true;
  }

  int prev = values.first.ymd;
  for (int index = 1; index < values.length; index += 1) {
    final int current = values[index].ymd;
    if (current < prev) {
      return false;
    }
    prev = current;
  }

  return true;
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

  return NormalizedBattleSeries(
    dates: List<int>.unmodifiable(dates),
    closeA: List<double>.unmodifiable(closeA),
    closeB: List<double>.unmodifiable(closeB),
  );
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
