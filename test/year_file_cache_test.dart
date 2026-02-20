import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/data/cache/year_file_cache.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';

void main() {
  test('YearFileCache does not store entries when capacity is zero', () {
    final YearFileCache cache = YearFileCache(capacity: 0);

    cache.write(
      market: 'US',
      ticker: 'AAPL',
      year: 2024,
      points: const <PricePoint>[PricePoint(ymd: 20240102, close: 100)],
    );

    expect(
      cache.read(market: 'US', ticker: 'AAPL', year: 2024),
      isNull,
    );
  });

  test('YearFileCache clamps negative capacity to zero', () {
    final YearFileCache cache = YearFileCache(capacity: -3);

    cache.write(
      market: 'KR',
      ticker: '005930',
      year: 2023,
      points: const <PricePoint>[PricePoint(ymd: 20231228, close: 70000)],
    );

    expect(
      cache.read(market: 'KR', ticker: '005930', year: 2023),
      isNull,
    );
  });
}
