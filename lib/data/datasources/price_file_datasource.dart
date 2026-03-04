import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/cache/year_file_cache.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/shared/utils/asset_paths.dart';

class PriceFileDataSource {
  PriceFileDataSource({YearFileCache? cache}) : _cache = cache ?? YearFileCache();

  final YearFileCache _cache;

  Future<List<PricePoint>> loadYear({
    required String market,
    required String ticker,
    required int year,
  }) async {
    final List<PricePoint>? cached = _cache.read(market: market, ticker: ticker, year: year);
    if (cached != null) {
      return cached;
    }

    final String path = AssetPaths.assetPathYear(market, ticker, year);
    try {
      final ByteData bytes = await rootBundle.load(path);
      final List<int> decoded = GZipDecoder().decodeBytes(bytes.buffer.asUint8List());
      final dynamic parsed = jsonDecode(utf8.decode(decoded));
      final List<dynamic> rows = parsed as List<dynamic>;
      final List<PricePoint> points = <PricePoint>[];
      points.length = rows.length;
      int writeIndex = 0;
      for (final dynamic rawRow in rows) {
        if (rawRow is! List<dynamic> || rawRow.length < 2) {
          continue;
        }

        final dynamic ymdRaw = rawRow[0];
        final dynamic closeRaw = rawRow[1];
        if (ymdRaw is! num || closeRaw is! num) {
          continue;
        }

        points[writeIndex++] = PricePoint(
          ymd: ymdRaw.toInt(),
          close: closeRaw.toDouble(),
        );
      }
      if (writeIndex != points.length) {
        points.length = writeIndex;
      }

      _cache.write(market: market, ticker: ticker, year: year, points: points);
      return points;
    } catch (error) {
      debugPrint('Price asset load failed: $path ($error)');
      return <PricePoint>[];
    }
  }
}
