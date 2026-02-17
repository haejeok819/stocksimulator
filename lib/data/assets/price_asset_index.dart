import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class PriceAssetIndex {
  const PriceAssetIndex();

  static const String _pricesPrefix = 'assets/prices/';

  Future<List<String>> listPriceAssets() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> keys = manifest.listAssets().where((String key) => key.startsWith(_pricesPrefix)).toList()
      ..sort();
    return keys;
  }

  Future<Map<String, dynamic>> loadJsonAsset(String path) async {
    final String jsonString = await rootBundle.loadString(path);
    final Object? decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('JSON asset is not an object: $path');
    }
    return decoded;
  }

  Future<dynamic> loadGzJsonAsset(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final List<int> unzipped = const GZipCodec().decode(bytes);
      final String jsonString = utf8.decode(unzipped);
      return jsonDecode(jsonString);
    } catch (error) {
      throw FormatException('Failed to load/parse gz JSON asset. assetPath=$path, exception=$error');
    }
  }
}
