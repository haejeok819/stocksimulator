import 'dart:collection';

import 'package:stocksimulator/data/models/price_year_data.dart';

class YearFileCache {
  YearFileCache({int capacity = 5}) : capacity = capacity < 0 ? 0 : capacity;

  final int capacity;
  final LinkedHashMap<String, List<PricePoint>> _cache = LinkedHashMap<String, List<PricePoint>>();

  List<PricePoint>? read({required String market, required String ticker, required int year}) {
    final String key = _key(market: market, ticker: ticker, year: year);
    final List<PricePoint>? value = _cache.remove(key);
    if (value == null) {
      return null;
    }
    _cache[key] = value;
    return value;
  }

  void write({
    required String market,
    required String ticker,
    required int year,
    required List<PricePoint> points,
  }) {
    if (capacity == 0) {
      return;
    }

    final String key = _key(market: market, ticker: ticker, year: year);
    _cache.remove(key);
    _cache[key] = points;

    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  String _key({required String market, required String ticker, required int year}) =>
      '$market|$ticker|$year';
}
