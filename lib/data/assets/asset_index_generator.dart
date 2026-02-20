import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

/// Builds an index of price assets from AssetManifest at runtime.
class AssetIndexGenerator {
  const AssetIndexGenerator();

  static const String _prefix = 'assets/prices/';
  static final RegExp _krPattern = RegExp(r'^assets/prices/KR/KR_(\d{6})_(\d{4})\.json\.gz$');
  static final RegExp _goldPattern = RegExp(r'^assets/prices/GOLD/GOLD_KRX_(\d{4})\.json\.gz$');
  static final RegExp _fxPattern = RegExp(r'^assets/prices/FX/FX_USD_KRW_(\d{4})\.json\.gz$');
  static bool _hasLoggedIndexSummary = false;

  /// Returns all price-related asset keys under assets/prices/ (sorted).
  Future<List<String>> listPriceAssets() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> keys = manifest.listAssets().where((String key) => key.startsWith(_prefix)).toList()
      ..sort();
    return keys;
  }

  /// Creates index: AssetType -> assetKey -> sorted list of years.
  Future<Map<AssetType, Map<String, List<int>>>> buildAssetTypeIndex() async {
    final List<String> keys = await listPriceAssets();

    final Map<AssetType, Map<String, Set<int>>> mutable = <AssetType, Map<String, Set<int>>>{
      AssetType.stockKR: <String, Set<int>>{},
      AssetType.gold: <String, Set<int>>{},
      AssetType.fx: <String, Set<int>>{},
    };

    for (final String key in keys) {
      final RegExpMatch? kr = _krPattern.firstMatch(key);
      if (kr != null) {
        final String code6 = kr.group(1)!;
        final int year = int.parse(kr.group(2)!);
        mutable[AssetType.stockKR]!.putIfAbsent(code6, () => <int>{}).add(year);
        continue;
      }

      final RegExpMatch? gold = _goldPattern.firstMatch(key);
      if (gold != null) {
        final int year = int.parse(gold.group(1)!);
        mutable[AssetType.gold]!.putIfAbsent('KRX', () => <int>{}).add(year);
        continue;
      }

      final RegExpMatch? fx = _fxPattern.firstMatch(key);
      if (fx != null) {
        final int year = int.parse(fx.group(1)!);
        mutable[AssetType.fx]!.putIfAbsent('USD_KRW', () => <int>{}).add(year);
      }
    }

    final Map<AssetType, Map<String, List<int>>> immutable = <AssetType, Map<String, List<int>>>{};
    mutable.forEach((AssetType type, Map<String, Set<int>> byKey) {
      final Map<String, List<int>> yearsByKey = <String, List<int>>{};
      byKey.forEach((String assetKey, Set<int> yearsSet) {
        final List<int> years = yearsSet.toList()..sort();
        yearsByKey[assetKey] = years;
      });
      immutable[type] = yearsByKey;
    });

    if (kDebugMode && !_hasLoggedIndexSummary) {
      final String? krSample = immutable[AssetType.stockKR]?.keys.isNotEmpty == true
          ? (immutable[AssetType.stockKR]!.keys.toList()..sort()).first
          : null;
      final bool hasGold = immutable[AssetType.gold]?['KRX']?.isNotEmpty ?? false;
      final bool hasFx = immutable[AssetType.fx]?['USD_KRW']?.isNotEmpty ?? false;
      debugPrint(
        '[AssetIndex] sampleKR=${krSample ?? 'none'}, hasGOLD_KRX=$hasGold, hasFX_USD_KRW=$hasFx',
      );
      _hasLoggedIndexSummary = true;
    }

    return immutable;
  }

  /// Backward-compatible view: market-code string map.
  Future<Map<String, Map<String, List<int>>>> buildFlatIndex() async {
    final Map<AssetType, Map<String, List<int>>> typed = await buildAssetTypeIndex();
    return <String, Map<String, List<int>>>{
      'KR': typed[AssetType.stockKR] ?? <String, List<int>>{},
      'GOLD': typed[AssetType.gold] ?? <String, List<int>>{},
      'FX': typed[AssetType.fx] ?? <String, List<int>>{},
    };
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
      final List<int> decoded = GZipCodec().decode(bytes);
      return jsonDecode(utf8.decode(decoded));
    } catch (error) {
      throw FormatException('gzip/json parse failed. assetPath=$path, exception=$error');
    }
  }

  /// Helper path for yearly gzip files.
  String flatYearAssetPath({required String market, required String ticker, required int year}) {
    if (market == 'KR') {
      return 'assets/prices/KR/KR_${ticker}_$year.json.gz';
    }
    if (market == 'GOLD') {
      return 'assets/prices/GOLD/GOLD_KRX_$year.json.gz';
    }
    if (market == 'FX') {
      return 'assets/prices/FX/FX_USD_KRW_$year.json.gz';
    }
    throw ArgumentError.value(market, 'market', 'unsupported market code for asset path');
  }
}
