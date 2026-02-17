import 'package:stocksimulator/data/assets/asset_index_generator.dart';

/// Repository for flat asset layout:
/// - assets/prices/KR_top50_meta.json
/// - assets/prices/US_top50_meta.json
/// - assets/prices/{MARKET}_{TICKER}_{YEAR}.json.gz
class PriceRepository {
  PriceRepository({AssetIndexGenerator? assetIndex}) : _assetIndex = assetIndex ?? const AssetIndexGenerator();

  final AssetIndexGenerator _assetIndex;

  /// Loads KR/US top50 ticker list from meta file.
  Future<List<String>> loadTop50Tickers(String market) async {
    _validateMarket(market);
    final String metaPath = 'assets/prices/${market}_top50_meta.json';

    final Object? decoded = await _assetIndex.loadJsonAsset(metaPath);
    final List<Map<String, Object?>> rows = _extractMetaRows(decoded, metaPath);

    return rows
        .map((Map<String, Object?> row) => row['ticker'])
        .whereType<String>()
        .where((String ticker) => ticker.trim().isNotEmpty)
        .toList();
  }

  /// Loads one year price data from flat gzip asset.
  Future<Object?> loadYearData({
    required String market,
    required String ticker,
    required int year,
  }) async {
    _validateMarket(market);
    final String assetPath = _assetIndex.flatYearAssetPath(market: market, ticker: ticker, year: year);

    final List<String> keys = await _assetIndex.listPriceAssets();
    if (!keys.contains(assetPath)) {
      throw StateError(
        'Requested asset does not exist. prefix=assets/prices/, market=$market, ticker=$ticker, year=$year, triedAssetPath=$assetPath',
      );
    }

    try {
      return await _assetIndex.loadGzJsonAsset(assetPath);
    } catch (error) {
      throw FormatException('Failed to load year data. assetPath=$assetPath, exception=$error');
    }
  }

  /// Returns available years for one ticker in flat layout.
  Future<List<int>> availableYears({required String market, required String ticker}) async {
    _validateMarket(market);
    final Map<String, Map<String, List<int>>> index = await _assetIndex.buildFlatIndex();
    final List<int> years = index[market]?[ticker] ?? <int>[];
    return List<int>.from(years)..sort();
  }

  List<Map<String, Object?>> _extractMetaRows(Object? decoded, String metaPath) {
    if (decoded is List<Object?>) {
      return decoded
          .whereType<Map>()
          .map((Map<Object?, Object?> row) => Map<String, Object?>.from(row))
          .toList();
    }

    throw FormatException('Unsupported meta format. assetPath=$metaPath, expected=List<Map>');
  }

  void _validateMarket(String market) {
    if (market != 'KR' && market != 'US') {
      throw ArgumentError.value(market, 'market', 'market must be KR or US');
    }
  }
}
