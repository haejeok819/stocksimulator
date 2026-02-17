import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:stocksimulator/data/cache/year_file_cache.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';

class PriceFileDataSource {
  PriceFileDataSource({YearFileCache? cache}) : _cache = cache ?? YearFileCache();

  final YearFileCache _cache;

  Future<PriceYearData> loadYear({
    required String market,
    required String ticker,
    required int year,
  }) async {
    final String relative = 'prices/$market/$ticker/$year.json.gz';
    final String cacheKey = relative;

    Uint8List? bytes = await _cache.read(cacheKey);
    bytes ??= await _readAssetBytes(relative);

    if (bytes != null) {
      await _cache.write(cacheKey, bytes);
      final List<int> decoded = const GZipCodec().decode(bytes);
      final Map<String, dynamic> jsonMap = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
      return PriceYearData.fromJson(jsonMap);
    }

    return _generateFallback(market: market, ticker: ticker, year: year);
  }

  Future<Uint8List?> _readAssetBytes(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  PriceYearData _generateFallback({
    required String market,
    required String ticker,
    required int year,
  }) {
    final Random random = Random(year + ticker.hashCode);
    double close = 100 + random.nextDouble() * 40;
    final List<PricePoint> points = <PricePoint>[];
    for (int m = 1; m <= 12; m++) {
      for (int d = 1; d <= 28; d++) {
        close += (random.nextDouble() - 0.48) * 2.8;
        if (close < 10) {
          close = 10;
        }
        points.add(
          PricePoint(
            ymd: year * 10000 + m * 100 + d,
            close: double.parse(close.toStringAsFixed(2)),
          ),
        );
      }
    }

    return PriceYearData(
      v: 1,
      market: market,
      ticker: ticker,
      currency: market == 'KR' ? 'KRW' : 'USD',
      priceScale: 1,
      year: year,
      series: points,
    );
  }
}
