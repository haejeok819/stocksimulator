import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/prices/price_repository.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';

class _FakePriceRepository extends PriceRepository {
  _FakePriceRepository({required this.years, required this.yearData});

  final List<int> years;
  final Map<int, Object?> yearData;
  final List<int> requestedYears = <int>[];

  @override
  Future<List<int>> availableYearsByAsset({
    required AssetType assetType,
    required String assetKey,
  }) async {
    return List<int>.from(years);
  }

  @override
  Future<Object?> loadYearDataByAsset({
    required AssetType assetType,
    required String assetKey,
    required int year,
  }) async {
    requestedYears.add(year);
    return yearData[year] ?? <Object?>[];
  }
}

void main() {
  test('loadTradingDays scans only indexed years after minimum baseline', () async {
    final _FakePriceRepository fake = _FakePriceRepository(
      years: <int>[2005, 2007],
      yearData: <int, Object?>{
        2005: <Object?>[
          <Object?>[20050103, 100.0],
        ],
        2007: <Object?>[
          <Object?>['20070102', 200.0],
        ],
      },
    );
    final StockRepository repository = StockRepository(priceRepository: fake);

    final List<int> days = await repository.loadTradingDays(
      assetType: AssetType.stockKR,
      assetKey: '005930',
    );

    expect(fake.requestedYears, <int>[2005, 2007]);
    expect(days, <int>[20050103, 20070102]);
  });
}
