import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/prices/price_repository.dart';
import 'package:stocksimulator/shared/utils/asset_paths.dart';

class StockRepository {
  StockRepository({PriceRepository? priceRepository}) : _priceRepository = priceRepository ?? PriceRepository();

  final PriceRepository _priceRepository;
  final Map<String, List<StockModel>> _stockCache = <String, List<StockModel>>{};
  final Map<String, List<int>> _tradingDaysCache = <String, List<int>>{};

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
    final int maxYear = availableYears.last;

    final Set<int> mergedDays = <int>{};
    for (int year = minYear; year <= maxYear; year++) {
      try {
        final Object? decoded = await _priceRepository.loadYearDataByAsset(
          assetType: assetType,
          assetKey: assetKey,
          year: year,
        );
        if (decoded is! List<Object?>) {
          continue;
        }

        for (final List<Object?> row in decoded.whereType<List<Object?>>()) {
          if (row.length < 2) {
            continue;
          }
          mergedDays.add((row[0] as num).toInt());
        }
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
    if (prices.isEmpty) {
      return <SimulationPoint>[];
    }

    final double amount = investment.toDouble();
    final double startClose = prices.first.close;
    final double endClose = prices.last.close;
    final double shares = amount / startClose;
    final double finalValue = shares * endClose;
    final double profit = finalValue - amount;
    final double profitRate = profit / amount;

    if (kDebugMode) {
      debugPrint(
        '[Simulation] startClose=$startClose, endClose=$endClose, finalValue=$finalValue, '
        'profit=$profit, profitRate=$profitRate',
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
        if (decodedObject is! List<Object?>) {
          continue;
        }

        final List<Map<String, dynamic>> typedMetaList =
            (decodedObject.whereType<Map>().map((Map<Object?, Object?> e) => Map<String, dynamic>.from(e)).toList())
                .asMap()
                .entries
                .map((MapEntry<int, Map<String, dynamic>> entry) => entry.value)
                .toList();

        final List<StockModel> loaded = typedMetaList
            .asMap()
            .entries
            .map(
              (MapEntry<int, Map<String, dynamic>> entry) =>
                  StockModel.fromJson(entry.value, rank: entry.key + 1, assetType: assetType),
            )
            .where((StockModel stock) => stock.ticker.isNotEmpty)
            .toList();

        _stockCache[cacheKey] = loaded;
        return loaded;
      } catch (error) {
        debugPrint('Top meta load failed: $path ($error)');
      }
    }

    throw StateError('메타 파일이 없습니다');
  }
}
