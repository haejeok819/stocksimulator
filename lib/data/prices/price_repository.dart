import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/assets/asset_index_generator.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class PriceRepository {
  PriceRepository({AssetIndexGenerator? assetIndex}) : _assetIndex = assetIndex ?? const AssetIndexGenerator();

  final AssetIndexGenerator _assetIndex;
  static const int _minimumTradingDays = 30;

  Future<List<String>> loadTop50TickersByAsset(AssetType assetType) async {
    _validateAssetType(assetType);
    final String marketCode = assetType.code;
    final String metaPath = 'assets/prices/${marketCode}_top50_meta.json';

    final Object? decoded = await _assetIndex.loadJsonAsset(metaPath);
    final List<Map<String, Object?>> rows = _extractMetaRows(decoded, metaPath);

    return rows
        .map((Map<String, Object?> row) => row['ticker'])
        .whereType<String>()
        .where((String ticker) => ticker.trim().isNotEmpty)
        .toList();
  }

  Future<Object?> loadYearDataByAsset({
    required AssetType assetType,
    required String assetKey,
    required int year,
  }) async {
    _validateAssetType(assetType);
    final String marketCode = assetType.code;
    final String assetPath = _assetIndex.flatYearAssetPath(market: marketCode, ticker: assetKey, year: year);

    final List<String> keys = await _assetIndex.listPriceAssets();
    if (!keys.contains(assetPath)) {
      throw StateError(
        'Requested asset does not exist. prefix=assets/prices/, assetType=$assetType, assetKey=$assetKey, year=$year, triedAssetPath=$assetPath',
      );
    }

    try {
      return await _assetIndex.loadGzJsonAsset(assetPath);
    } catch (error) {
      throw FormatException('Failed to load year data. assetPath=$assetPath, exception=$error');
    }
  }

  Future<List<int>> availableYearsByAsset({
    required AssetType assetType,
    required String assetKey,
  }) async {
    _validateAssetType(assetType);
    final Map<String, Map<String, List<int>>> index = await _assetIndex.buildFlatIndex();
    final List<int> years = index[assetType.code]?[assetKey] ?? <int>[];
    return List<int>.from(years)..sort();
  }

  Future<List<PricePoint>> loadSeriesByAsset({
    required AssetType assetType,
    required String assetKey,
    required DateTime start,
    required DateTime end,
  }) async {
    _validateAssetType(assetType);
    if (end.isBefore(start)) {
      throw ArgumentError('end must be greater than or equal to start');
    }

    final String marketCode = assetType.code;
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final Set<String> assetKeys = manifest.listAssets().toSet();
    final List<int> loadedYears = <int>[];
    final List<PricePoint> merged = <PricePoint>[];

    for (int year = start.year; year <= end.year; year++) {
      final String assetPath = _assetIndex.flatYearAssetPath(market: marketCode, ticker: assetKey, year: year);
      if (!assetKeys.contains(assetPath)) {
        debugPrint(
          '[PriceRepository] missing yearly asset. assetType=$assetType, assetKey=$assetKey, year=$year, path=$assetPath',
        );
        continue;
      }

      final Object? decoded = await _assetIndex.loadGzJsonAsset(assetPath);
      if (decoded is! List<Object?>) {
        throw FormatException('Invalid yearly data format. assetPath=$assetPath, expected=List');
      }

      merged.addAll(
        decoded
            .whereType<List<Object?>>()
            .where((List<Object?> row) => row.length >= 2)
            .map(
              (List<Object?> row) => PricePoint(
                ymd: (row[0] as num).toInt(),
                close: (row[1] as num).toDouble(),
              ),
            ),
      );
      loadedYears.add(year);
    }

    merged.sort((PricePoint a, PricePoint b) => a.ymd.compareTo(b.ymd));

    final int startYmd = _toYmd(start);
    final int endYmd = _toYmd(end);
    final PricePoint? correctedStart = _findStartOrAfter(merged, startYmd);
    final PricePoint? correctedEnd = _findEndOrBefore(merged, endYmd);

    if (correctedStart == null || correctedEnd == null || correctedStart.ymd > correctedEnd.ymd) {
      throw StateError('선택한 기간에 거래 데이터가 없습니다. (${_formatYmd(start)} ~ ${_formatYmd(end)})');
    }

    final List<PricePoint> filtered = merged
        .where((PricePoint point) => point.ymd >= correctedStart.ymd && point.ymd <= correctedEnd.ymd)
        .toList();

    if (filtered.length < _minimumTradingDays) {
      throw StateError(
        '선택한 구간의 실제 거래일이 부족합니다. 최소 $_minimumTradingDays일 필요, 실제 ${filtered.length}일',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[Simulation] assetType=$assetType, assetKey=$assetKey, start=${_formatYmd(start)}, end=${_formatYmd(end)}',
      );
      debugPrint('[Simulation] loadedYears=$loadedYears, filteredPoints=${filtered.length}');
    }

    return filtered;
  }

  // Legacy wrappers kept to avoid touching existing screen flow in this step.
  Future<List<String>> loadTop50Tickers(String market) =>
      loadTop50TickersByAsset(_assetTypeFromMarket(market));

  Future<Object?> loadYearData({required String market, required String ticker, required int year}) =>
      loadYearDataByAsset(assetType: _assetTypeFromMarket(market), assetKey: ticker, year: year);

  Future<List<int>> availableYears({required String market, required String ticker}) =>
      availableYearsByAsset(assetType: _assetTypeFromMarket(market), assetKey: ticker);

  Future<List<PricePoint>> loadSeries({
    required String market,
    required String ticker,
    required DateTime start,
    required DateTime end,
  }) =>
      loadSeriesByAsset(
        assetType: _assetTypeFromMarket(market),
        assetKey: ticker,
        start: start,
        end: end,
      );

  PricePoint? _findStartOrAfter(List<PricePoint> merged, int targetYmd) {
    for (final PricePoint point in merged) {
      if (point.ymd >= targetYmd) {
        return point;
      }
    }
    return null;
  }

  PricePoint? _findEndOrBefore(List<PricePoint> merged, int targetYmd) {
    for (int i = merged.length - 1; i >= 0; i--) {
      final PricePoint point = merged[i];
      if (point.ymd <= targetYmd) {
        return point;
      }
    }
    return null;
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

  AssetType _assetTypeFromMarket(String market) {
    if (market == 'KR') {
      return AssetType.stockKR;
    }
    throw ArgumentError.value(market, 'market', 'unsupported market for this step');
  }

  void _validateAssetType(AssetType assetType) {
    if (assetType != AssetType.stockKR) {
      throw ArgumentError.value(assetType, 'assetType', 'only stockKR is enabled in this step');
    }
  }

  int _toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  String _formatYmd(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}.$mm.$dd';
  }
}
