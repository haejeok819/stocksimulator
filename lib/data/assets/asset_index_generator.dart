import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Builds an index of flat price assets from AssetManifest at runtime.
class AssetIndexGenerator {
  const AssetIndexGenerator();

  static const String _prefix = 'assets/prices/';
  static final RegExp _flatPricePattern =
      RegExp(r'^assets/prices/(KR|US)_([^_]+)_(\d{4})\.json\.gz$');

  /// Returns all price-related asset keys under assets/prices/ (sorted).
  Future<List<String>> listPriceAssets() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> keys = manifest.listAssets().where((String key) => key.startsWith(_prefix)).toList()
      ..sort();
    return keys;
  }

  /// Creates index: market -> ticker -> sorted list of years.
  Future<Map<String, Map<String, List<int>>>> buildFlatIndex() async {
    final List<String> keys = await listPriceAssets();
    final Map<String, Map<String, Set<int>>> mutable = <String, Map<String, Set<int>>>{
      'KR': <String, Set<int>>{},
      'US': <String, Set<int>>{},
    };

    for (final String key in keys) {
      final RegExpMatch? match = _flatPricePattern.firstMatch(key);
      if (match == null) {
        continue;
      }

      final String market = match.group(1)!;
      final String ticker = match.group(2)!;
      final int year = int.parse(match.group(3)!);

      final Map<String, Set<int>> byTicker = mutable[market]!;
      byTicker.putIfAbsent(ticker, () => <int>{}).add(year);
    }

    final Map<String, Map<String, List<int>>> immutable = <String, Map<String, List<int>>>{};
    mutable.forEach((String market, Map<String, Set<int>> byTicker) {
      final Map<String, List<int>> yearsByTicker = <String, List<int>>{};
      byTicker.forEach((String ticker, Set<int> yearsSet) {
        final List<int> years = yearsSet.toList()..sort();
        yearsByTicker[ticker] = years;
      });
      immutable[market] = yearsByTicker;
    });

    return immutable;
  }

  /// Loads a plain JSON asset and returns decoded object.
  Future<Object?> loadJsonAsset(String path) async {
    final String jsonText = await rootBundle.loadString(path);
    return jsonDecode(jsonText);
  }

  /// Loads gzip JSON asset and returns decoded object.
  Future<Object?> loadGzJsonAsset(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final List<int> decoded = const GZipCodec().decode(bytes);
      return jsonDecode(utf8.decode(decoded));
    } catch (error) {
      throw FormatException('gzip/json parse failed. assetPath=$path, exception=$error');
    }
  }

  /// Helper path for flat yearly gzip files.
  String flatYearAssetPath({required String market, required String ticker, required int year}) {
    return 'assets/prices/${market}_${ticker}_$year.json.gz';
  }
}
