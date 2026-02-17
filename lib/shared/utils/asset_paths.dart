class AssetPaths {
  AssetPaths._();

  // Flat top50 meta file path (KR_top50_meta.json / US_top50_meta.json).
  static String assetPathMetaList(String market) => 'assets/prices/${market}_top50_meta.json';

  // Flat yearly gzip path (KR_{ticker}_{year}.json.gz / US_{ticker}_{year}.json.gz).
  static String assetPathYear(String market, String ticker, int year) =>
      'assets/prices/${market}_$ticker_$year.json.gz';
}
