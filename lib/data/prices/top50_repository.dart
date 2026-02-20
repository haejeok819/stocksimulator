import 'package:stocksimulator/data/assets/price_asset_index.dart';

/// Backward-compatible repository wrapper for top50/year loading.
class Top50Repository {
  Top50Repository({PriceAssetIndex? assetIndex}) : _assetIndex = assetIndex ?? const PriceAssetIndex();

  final PriceAssetIndex _assetIndex;

  Future<List<String>> loadTop50Tickers(String market) async {
    _validateMarket(market);

    final String assetPath = 'assets/prices/${market}_top50_meta.json';
    final List<String> assets = await _assetIndex.listPriceAssets();
    if (!assets.contains(assetPath)) {
      throw StateError(
        'Top50 meta asset not found. prefix=assets/prices/, market=$market, ticker=, year=, triedAssetPath=$assetPath',
      );
    }

    final Object? decoded = await _assetIndex.loadAnyJsonAsset(assetPath);
    if (decoded is! List<Object?>) {
      throw FormatException('Unexpected top50 JSON structure. assetPath=$assetPath, expected=List<Map>');
    }

    return decoded
        .whereType<Map>()
        .map((Map<Object?, Object?> row) => Map<String, Object?>.from(row))
        .map((Map<String, Object?> row) => row['ticker'])
        .whereType<String>()
        .where((String ticker) => ticker.trim().isNotEmpty)
        .toList();
  }

  Future<Object?> loadYearData({
    required String market,
    required String ticker,
    required int year,
  }) async {
    _validateMarket(market);

    final String assetPath = 'assets/prices/KR/KR_${ticker}_$year.json.gz';
    final List<String> assets = await _assetIndex.listPriceAssets();
    if (!assets.contains(assetPath)) {
      throw StateError(
        'Year asset not found. prefix=assets/prices/, market=$market, ticker=$ticker, year=$year, triedAssetPath=$assetPath',
      );
    }

    try {
      return await _assetIndex.loadGzJsonAsset(assetPath);
    } catch (error) {
      throw FormatException('Failed to parse year data. assetPath=$assetPath, exception=$error');
    }
  }

  void _validateMarket(String market) {
    if (market != 'KR') {
      throw ArgumentError.value(market, 'market', 'market must be KR');
    }
  }
}
