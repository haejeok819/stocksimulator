import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/assets/asset_index_generator.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/prices/price_repository.dart';
import 'package:stocksimulator/shared/utils/asset_paths.dart';

class StockRepository {
  StockRepository({PriceRepository? priceRepository}) : _priceRepository = priceRepository ?? PriceRepository();

  final PriceRepository _priceRepository;
  final AssetIndexGenerator _assetIndex = const AssetIndexGenerator();
  final Map<String, List<StockModel>> _stockCache = <String, List<StockModel>>{};
  final Map<String, List<int>> _tradingDaysCache = <String, List<int>>{};
  static final RegExp _code6Pattern = RegExp(r'^\d{6}$');
  static final RegExp _code6ExtractorPattern = RegExp(r'(\d{6})');

  static const StockModel _goldStock = StockModel(
    ticker: 'KRX',
    assetType: AssetType.gold,
    assetKey: 'KRX',
    nameKo: '금(KRX)',
    nameEn: 'Gold(KRX)',
    rank: 1,
  );

  static const StockModel _fxStock = StockModel(
    ticker: 'USD_KRW',
    assetType: AssetType.fx,
    assetKey: 'USD_KRW',
    nameKo: '달러/원 환율',
    nameEn: 'USD/KRW',
    rank: 1,
  );


  Future<List<StockModel>> getTopStocks({
    AssetType assetType = AssetType.stockKR,
    StockMarket? market,
    String query = '',
  }) async {
    final AssetType resolvedAssetType = market?.assetType ?? assetType;

    final List<StockModel> all = switch (resolvedAssetType) {
      AssetType.stockKR => <StockModel>[
          ...await _loadTopMetaByAssetType(AssetType.stockKR),
          _goldStock,
          _fxStock,
        ],
      AssetType.gold => <StockModel>[_goldStock],
      AssetType.fx => <StockModel>[_fxStock],
    };

    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return all;
    }
    return all.where((StockModel stock) => stock.matchesQuery(normalized)).toList();
  }

  Future<List<int>> loadTradingDays({required AssetType assetType, required String assetKey}) async {
    final String cacheKey = '${assetType.code}|$assetKey';
    final List<int>? cached = _tradingDaysCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final List<int> availableYears = await _priceRepository.availableYearsByAsset(
      assetType: assetType,
      assetKey: assetKey,
    );
    if (availableYears.isEmpty) {
      _tradingDaysCache[cacheKey] = <int>[];
      return <int>[];
    }

    final bool has2005 = availableYears.contains(2005);
    final int minYear = has2005 ? 2005 : availableYears.first;
    final List<int> targetYears = availableYears.where((int year) => year >= minYear).toList();

    final Set<int> mergedDays = <int>{};
    for (final int year in targetYears) {
      try {
        final Object? decoded = await _priceRepository.loadYearDataByAsset(
          assetType: assetType,
          assetKey: assetKey,
          year: year,
        );
        _collectTradingDays(decoded, mergedDays);
      } catch (error) {
        debugPrint('Trading day scan skipped: assetType=$assetType, assetKey=$assetKey, year=$year ($error)');
      }
    }

    final List<int> sortedDays = mergedDays.toList()..sort();
    _tradingDaysCache[cacheKey] = sortedDays;
    return sortedDays;
  }

  Future<List<int>> loadTradingDaysYmd({required String market, required String ticker}) {
    return loadTradingDays(assetType: assetTypeFromCode(market), assetKey: ticker);
  }

  Future<List<PricePoint>> loadRangeByAsset({
    required AssetType assetType,
    required String assetKey,
    required DateTime start,
    required DateTime end,
  }) {
    return _priceRepository.loadSeriesByAsset(
      assetType: assetType,
      assetKey: assetKey,
      start: start,
      end: end,
    );
  }

  Future<List<PricePoint>> loadRange({
    required String market,
    required String ticker,
    required DateTime start,
    required DateTime end,
  }) {
    return loadRangeByAsset(
      assetType: assetTypeFromCode(market),
      assetKey: ticker,
      start: start,
      end: end,
    );
  }

  List<SimulationPoint> toSimulationSeries({
    required List<PricePoint> prices,
    required int investment,
  }) {
    if (prices.isEmpty || investment <= 0) {
      return <SimulationPoint>[];
    }

    final double startClose = prices.first.close;
    if (startClose <= 0) {
      return <SimulationPoint>[];
    }

    final double shares = investment / startClose;

    if (kDebugMode) {
      debugPrint(
        '[Simulation] startClose=$startClose, shares=$shares, points=${prices.length}',
      );
    }

    return prices
        .map(
          (PricePoint point) => SimulationPoint(
            ymd: point.ymd,
            close: point.close,
            value: shares * point.close,
          ),
        )
        .toList();
  }

  List<SimulationPoint> toSimulationSeriesWithEvents({
    required List<PricePoint> prices,
    required Map<int, int> investEventsByYmd,
  }) {
    if (prices.isEmpty || investEventsByYmd.isEmpty) {
      return <SimulationPoint>[];
    }

    double cash = 0;
    double shares = 0;
    final List<SimulationPoint> points = <SimulationPoint>[];

    for (final PricePoint point in prices) {
      final int invest = investEventsByYmd[point.ymd] ?? 0;
      if (invest > 0) {
        cash += invest.toDouble();
      }

      if (cash > 0 && point.close > 0) {
        shares += cash / point.close;
        cash = 0;
      }

      points.add(
        SimulationPoint(
          ymd: point.ymd,
          close: point.close,
          value: shares * point.close,
        ),
      );
    }

    return points;
  }

  Future<List<StockModel>> _loadTopMetaByAssetType(AssetType assetType) async {
    final String cacheKey = assetType.code;
    final List<StockModel>? cached = _stockCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final List<String> candidates = AssetPaths.assetPathMetaListCandidatesByAsset(assetType);
    for (final String path in candidates) {
      try {
        final Object? decodedObject = jsonDecode(await rootBundle.loadString(path));
        final List<Map<String, dynamic>> typedMetaList = _coerceMetaRows(decodedObject);

        final List<StockModel> loaded;
        if (assetType == AssetType.stockKR) {
          final Set<String> krKeys = await _loadKrIndexKeys();

          final List<StockModel> normalized = typedMetaList
              .asMap()
              .entries
              .map((MapEntry<int, Map<String, dynamic>> entry) {
                final String? code6 = _normalizeKrCode6(entry.value);
                if (code6 == null) {
                  return null;
                }
                final Map<String, dynamic> normalizedJson = Map<String, dynamic>.from(entry.value);
                normalizedJson['ticker'] = code6;
                final String resolvedName = _resolveKrDisplayName(entry.value, code6);
                normalizedJson['name_ko'] = resolvedName;
                if ((normalizedJson['name_en'] as String? ?? '').trim().isEmpty) {
                  normalizedJson['name_en'] = resolvedName;
                }
                return StockModel.fromJson(normalizedJson, rank: entry.key + 1, assetType: assetType);
              })
              .whereType<StockModel>()
              .toList();

          if (typedMetaList.isEmpty) {
            continue;
          }

          loaded = normalized.where((StockModel stock) => krKeys.contains(stock.ticker)).toList();

        } else {
          loaded = typedMetaList
              .asMap()
              .entries
              .map(
                (MapEntry<int, Map<String, dynamic>> entry) =>
                    StockModel.fromJson(entry.value, rank: entry.key + 1, assetType: assetType),
              )
              .where((StockModel stock) => stock.ticker.isNotEmpty)
              .toList();
        }

        _stockCache[cacheKey] = loaded;
        return loaded;
      } catch (error) {
        debugPrint('Top meta load failed: $path ($error)');
      }
    }

    if (assetType == AssetType.stockKR) {
      final List<StockModel> fallback = await _buildKrFallbackStocks();
      _stockCache[cacheKey] = fallback;
      return fallback;
    }

    throw StateError('메타 파일이 없습니다');
  }


  Future<Set<String>> _loadKrIndexKeys() async {
    final Map<AssetType, Map<String, List<int>>> typedIndex = await _assetIndex.buildAssetTypeIndex();
    return typedIndex[AssetType.stockKR]?.keys.toSet() ?? <String>{};
  }

  Future<List<StockModel>> _buildKrFallbackStocks() async {
    final List<String> sortedKrKeys = (await _loadKrIndexKeys()).toList()..sort();
    return sortedKrKeys
        .asMap()
        .entries
        .map(
          (MapEntry<int, String> entry) => StockModel.fromJson(
            <String, dynamic>{
              'code6': entry.value,
              'ticker': entry.value,
              'name_ko': '종목 ${entry.value}',
              'name_en': '종목 ${entry.value}',
            },
            rank: entry.key + 1,
            assetType: AssetType.stockKR,
          ),
        )
        .toList();
  }


  List<Map<String, dynamic>> _coerceMetaRows(Object? decodedObject) {
    if (decodedObject is List<Object?>) {
      return decodedObject
          .whereType<Map>()
          .map((Map<Object?, Object?> row) => Map<String, dynamic>.from(row))
          .toList();
    }

    if (decodedObject is Map<Object?, Object?>) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(decodedObject)];
    }

    return <Map<String, dynamic>>[];
  }

  String _resolveKrDisplayName(Map<String, dynamic> row, String code6) {
    final List<String> candidates = <String>[
      (row['name_ko'] as String? ?? '').trim(),
      (row['name_en'] as String? ?? '').trim(),
      (row['name_k'] as String? ?? '').trim(),
      (row['displayName'] as String? ?? '').trim(),
      (row['name'] as String? ?? '').trim(),
      (row['corp_name'] as String? ?? '').trim(),
    ];

    for (final String candidate in candidates) {
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return '종목 $code6';
  }

  String? _normalizeKrCode6(Map<String, dynamic> row) {
    final String code6 = (row['code6'] as String? ?? '').trim();
    if (_code6Pattern.hasMatch(code6)) {
      return code6;
    }

    final String ticker = (row['ticker'] as String? ?? '').trim();
    if (ticker.contains('.')) {
      final String left = ticker.split('.').first.trim();
      if (_code6Pattern.hasMatch(left)) {
        return left;
      }
    }

    final RegExpMatch? match = _code6ExtractorPattern.firstMatch(ticker);
    return match?.group(1);
  }

  void _collectTradingDays(Object? decoded, Set<int> mergedDays) {
    if (decoded is! List<Object?>) {
      return;
    }

    for (final List<Object?> row in decoded.whereType<List<Object?>>()) {
      if (row.length < 2) {
        continue;
      }

      final int? ymd = _toYmd(row.first);
      if (ymd != null) {
        mergedDays.add(ymd);
      }
    }
  }

  int? _toYmd(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

}
