import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/datasources/price_file_datasource.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/shared/utils/asset_paths.dart';

class StockRepository {
  StockRepository({PriceFileDataSource? priceDataSource}) : _priceDataSource = priceDataSource ?? PriceFileDataSource();

  final PriceFileDataSource _priceDataSource;
  final Map<String, List<StockModel>> _stockCache = <String, List<StockModel>>{};

  Future<List<StockModel>> getTopStocks({required StockMarket market, String query = ''}) async {
    final String marketCode = market == StockMarket.kr ? 'KR' : 'US';
    final List<StockModel> all = await _loadTopMetaByMarket(marketCode);
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return all;
    }
    return all.where((StockModel stock) => stock.matchesQuery(normalized)).toList();
  }

  Future<List<PricePoint>> loadRange({
    required String market,
    required String ticker,
    required DateTime start,
    required DateTime end,
  }) async {
    final int startYear = start.year;
    final int endYear = end.year;
    final List<PricePoint> all = <PricePoint>[];

    for (int year = startYear; year <= endYear; year++) {
      final List<PricePoint> yearly = await _priceDataSource.loadYear(
        market: market,
        ticker: ticker,
        year: year,
      );
      all.addAll(yearly);
    }

    final int startYmd = _toYmd(start);
    final int endYmd = _toYmd(end);

    return all
        .where((PricePoint point) => point.ymd >= startYmd && point.ymd <= endYmd)
        .toList()
      ..sort((PricePoint a, PricePoint b) => a.ymd.compareTo(b.ymd));
  }

  List<SimulationPoint> toSimulationSeries({
    required List<PricePoint> prices,
    required int investment,
  }) {
    if (prices.isEmpty) {
      return <SimulationPoint>[];
    }

    final double shares = investment / prices.first.close;
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

  int _toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
}
