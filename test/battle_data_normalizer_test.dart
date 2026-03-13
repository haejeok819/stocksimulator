import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/features/battle/state/battle_data_normalizer.dart';

void main() {
  test('normalizeBattleSeries keeps only intersection dates in sorted order', () {
    final NormalizedBattleSeries normalized = normalizeBattleSeries(
      aSeries: const <PricePoint>[
        PricePoint(ymd: 20240103, close: 120),
        PricePoint(ymd: 20240101, close: 100),
        PricePoint(ymd: 20240102, close: 110),
      ],
      bSeries: const <PricePoint>[
        PricePoint(ymd: 20240102, close: 210),
        PricePoint(ymd: 20240101, close: 200),
        PricePoint(ymd: 20240104, close: 220),
      ],
    );

    expect(normalized.dates, <int>[20240101, 20240102]);
    expect(normalized.closeA, <double>[100, 110]);
    expect(normalized.closeB, <double>[200, 210]);
  });

  test('snapNormalizedSeriesToNearestRange snaps to nearest intersection bounds', () {
    const NormalizedBattleSeries normalized = NormalizedBattleSeries(
      dates: <int>[20240102, 20240105, 20240109],
      closeA: <double>[100, 102, 110],
      closeB: <double>[200, 198, 210],
    );

    final NormalizedBattleSeries snapped = snapNormalizedSeriesToNearestRange(
      normalized: normalized,
      selectedStartYmd: 20240101,
      selectedEndYmd: 20240106,
    );

    expect(snapped.dates, <int>[20240102, 20240105]);
    expect(snapped.closeA, <double>[100, 102]);
    expect(snapped.closeB, <double>[200, 198]);
  });


  test('normalizeBattleSeries handles pre-sorted inputs without reordering side effects', () {
    final List<PricePoint> aSeries = <PricePoint>[
      const PricePoint(ymd: 20240101, close: 100),
      const PricePoint(ymd: 20240102, close: 110),
      const PricePoint(ymd: 20240103, close: 120),
    ];
    final List<PricePoint> bSeries = <PricePoint>[
      const PricePoint(ymd: 20240101, close: 200),
      const PricePoint(ymd: 20240103, close: 220),
    ];

    final NormalizedBattleSeries normalized = normalizeBattleSeries(
      aSeries: aSeries,
      bSeries: bSeries,
    );

    expect(normalized.dates, <int>[20240101, 20240103]);
    expect(normalized.closeA, <double>[100, 120]);
    expect(normalized.closeB, <double>[200, 220]);
  });

  test('normalizeBattleSeries returns empty when either side is empty', () {
    final NormalizedBattleSeries normalized = normalizeBattleSeries(
      aSeries: const <PricePoint>[],
      bSeries: const <PricePoint>[PricePoint(ymd: 20240101, close: 200)],
    );

    expect(normalized.dates, isEmpty);
    expect(normalized.closeA, isEmpty);
    expect(normalized.closeB, isEmpty);
  });
}
