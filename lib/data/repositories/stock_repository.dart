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

  Future<List<StockModel>> getTopStocks({required StockMarket market, String query = ''}) async {
    final String marketCode = market == StockMarket.kr ? 'KR' : 'US';
    final List<StockModel> all = await _loadTopMetaByMarket(marketCode);
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return all;
    }
    return all.where((StockModel stock) => stock.matchesQuery(normalized)).toList();
  }

  Future<List<int>> loadTradingDaysYmd({required String market, required String ticker}) async {
    final String cacheKey = '$market|$ticker';
    final List<int>? cached = _tradingDaysCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final List<int> availableYears = await _priceRepository.availableYears(market: market, ticker: ticker);
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
        final Object? decoded = await _priceRepository.loadYearData(
          market: market,
          ticker: ticker,
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
        debugPrint('Trading day scan skipped: market=$market, ticker=$ticker, year=$year ($error)');
      }
    }

    final List<int> sortedDays = mergedDays.toList()..sort();
    _tradingDaysCache[cacheKey] = sortedDays;
    return sortedDays;
  }

  Future<List<PricePoint>> loadRange({
    required String market,
    required String ticker,
    required DateTime start,
    required DateTime end,
  }) {
    return _priceRepository.loadSeries(
      market: market,
      ticker: ticker,
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

  Future<List<StockModel>> _loadTopMetaByMarket(String market) async {
    final List<StockModel>? cached = _stockCache[market];
    if (cached != null) {
      return cached;
    }

    final String path = AssetPaths.assetPathMetaList(market);
    try {
      final Object? decodedObject = jsonDecode(await rootBundle.loadString(path));
      if (decodedObject is! List<Object?>) {
        return <StockModel>[];
      }

      final List<Map<String, dynamic>> typedMetaList =
          (decodedObject
                  .whereType<Map>()
                  .map((Map<Object?, Object?> e) => Map<String, dynamic>.from(e))
                  .toList())
              .asMap()
              .entries
              .map((MapEntry<int, Map<String, dynamic>> entry) => entry.value)
              .toList();

      final List<StockModel> loaded = typedMetaList
          .asMap()
          .entries
          .map(
            (MapEntry<int, Map<String, dynamic>> entry) =>
                StockModel.fromJson(entry.value, rank: entry.key + 1, market: market),
          )
          .where((StockModel stock) => stock.ticker.isNotEmpty)
          .toList();

      _stockCache[market] = loaded;
      return loaded;
    } catch (error) {
      debugPrint('Top meta load failed: $path ($error)');
      return <StockModel>[];
    }
  }
}
