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
