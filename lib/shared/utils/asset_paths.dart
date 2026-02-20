import 'package:stocksimulator/data/models/stock_model.dart';

class AssetPaths {
  AssetPaths._();

  static String assetPathMetaListByAsset(AssetType assetType) =>
      'assets/prices/${assetType.code}_top50_meta.json';

  static String assetPathYearByAsset({
    required AssetType assetType,
    required String assetKey,
    required int year,
  }) {
    switch (assetType) {
      case AssetType.stockKR:
        return 'assets/prices/KR/KR_${assetKey}_$year.json.gz';
      case AssetType.gold:
        return 'assets/prices/GOLD/GOLD_KRX_$year.json.gz';
      case AssetType.fx:
        return 'assets/prices/FX/FX_USD_KRW_$year.json.gz';
    }
  }

  // Legacy wrappers (to keep existing flow intact during migration).
  static String assetPathMetaList(String market) => 'assets/prices/${market}_top50_meta.json';

  static String assetPathYear(String market, String ticker, int year) {
    switch (market) {
      case 'KR':
        return 'assets/prices/KR/KR_${ticker}_$year.json.gz';
      case 'GOLD':
        return 'assets/prices/GOLD/GOLD_KRX_$year.json.gz';
      case 'FX':
        return 'assets/prices/FX/FX_USD_KRW_$year.json.gz';
      default:
        throw ArgumentError.value(market, 'market', 'unsupported market code for asset path');
    }
  }
}
