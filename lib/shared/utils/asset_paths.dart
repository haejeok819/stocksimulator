class AssetPaths {
  AssetPaths._();

  static String assetPathMeta(String market, String ticker) =>
      'assets/prices/$market/$ticker/meta.json';

  static String assetPathMetaList(String market) =>
      'assets/prices/$market/_top50_meta.json';

  static String assetPathYear(String market, String ticker, int year) =>
      'assets/prices/$market/$ticker/$year.json.gz';
}
