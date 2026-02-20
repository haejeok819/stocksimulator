import 'package:stocksimulator/data/models/stock_model.dart';

class AssetPaths {
  AssetPaths._();

  static String assetPathMetaListByAsset(AssetType assetType) =>
      'assets/prices/${assetType.code}_top50_meta.json';

  static String assetPathYearByAsset({
    required AssetType assetType,
    required String assetKey,
    required int year,
  }) =>
      'assets/prices/${assetType.code}_${assetKey}_$year.json.gz';

  // Legacy wrappers (to keep existing flow intact during migration).
  static String assetPathMetaList(String market) => 'assets/prices/${market}_top50_meta.json';

  static String assetPathYear(String market, String ticker, int year) =>
      'assets/prices/${market}_${ticker}_${year}.json.gz';
}
