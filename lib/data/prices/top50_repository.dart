import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:stocksimulator/data/assets/price_asset_index.dart';

class Top50Repository {
  Top50Repository({PriceAssetIndex? assetIndex}) : _assetIndex = assetIndex ?? const PriceAssetIndex();

  final PriceAssetIndex _assetIndex;

  Future<List<String>> loadTop50Tickers(String market) async {
    _validateMarket(market);

    final String assetPath = 'assets/prices/$market/_top50_meta.json';
    final List<String> assets = await _assetIndex.listPriceAssets();
    if (!assets.contains(assetPath)) {
      throw StateError(
        'Top50 meta asset not found. prefix=assets/prices/, market=$market, ticker=, year=, triedAssetPath=$assetPath',
      );
    }

    final Object? metaObject = jsonDecode(await rootBundle.loadString(assetPath));
    final List<Map<String, Object?>> rows = _extractMetaRows(metaObject);

    return rows
        .map((Map<String, Object?> item) => item['ticker'])
        .whereType<String>()
        .where((String ticker) => ticker.trim().isNotEmpty)
        .toList();
  }

  Future<dynamic> loadYearData({
    required String market,
    required String ticker,
    required int year,
  }) async {
    _validateMarket(market);

    final String assetPath = 'assets/prices/$market/$ticker/$year.json.gz';
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

  Future<void> debugScanAssets() async {
    final List<String> priceAssets = await _assetIndex.listPriceAssets();
    print('[debugScanAssets] prices asset count=${priceAssets.length}');

    final List<String> krTickers = await loadTop50Tickers('KR');
    final List<String> usTickers = await loadTop50Tickers('US');
    print('[debugScanAssets] KR top50 tickers=${krTickers.length}, US top50 tickers=${usTickers.length}');

    if (krTickers.isNotEmpty) {
      final dynamic kr2005 = await loadYearData(market: 'KR', ticker: krTickers.first, year: 2005);
      final int length = kr2005 is List<Object?> ? kr2005.length : -1;
      print('[debugScanAssets] KR first ticker=${krTickers.first}, 2005 load success=true, length=$length');
    }

    if (usTickers.isNotEmpty) {
      final dynamic us2005 = await loadYearData(market: 'US', ticker: usTickers.first, year: 2005);
      final int length = us2005 is List<Object?> ? us2005.length : -1;
      print('[debugScanAssets] US first ticker=${usTickers.first}, 2005 load success=true, length=$length');
    }
  }

  List<Map<String, Object?>> _extractMetaRows(Object? metaObject) {
    if (metaObject is List<Object?>) {
      return metaObject
          .whereType<Map>()
          .map((Map<Object?, Object?> row) => Map<String, Object?>.from(row))
          .toList();
    }

    if (metaObject is Map<Object?, Object?>) {
      final Map<String, Object?> mapObject = Map<String, Object?>.from(metaObject);
      final Object? listCandidate = mapObject['items'] ?? mapObject['data'] ?? mapObject['results'];
      if (listCandidate is List<Object?>) {
        return listCandidate
            .whereType<Map>()
            .map((Map<Object?, Object?> row) => Map<String, Object?>.from(row))
            .toList();
      }
    }

    throw FormatException('Unexpected top50 JSON structure: expected list of objects');
  }

  void _validateMarket(String market) {
    if (market != 'KR' && market != 'US') {
      throw ArgumentError.value(market, 'market', 'market must be KR or US');
    }
  }
}
