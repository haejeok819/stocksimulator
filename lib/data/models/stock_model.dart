enum AssetType { stockKR, gold, fx }

enum StockMarket { kr }

AssetType assetTypeFromCode(String code) {
  switch (code) {
    case 'KR':
      return AssetType.stockKR;
    case 'GOLD':
      return AssetType.gold;
    case 'FX':
      return AssetType.fx;
    default:
      throw ArgumentError.value(code, 'code', 'unsupported asset type code');
  }
}

extension AssetTypeX on AssetType {
  String get code {
    switch (this) {
      case AssetType.stockKR:
        return 'KR';
      case AssetType.gold:
        return 'GOLD';
      case AssetType.fx:
        return 'FX';
    }
  }

  String get defaultKey {
    switch (this) {
      case AssetType.stockKR:
        return '';
      case AssetType.gold:
        return 'KRX';
      case AssetType.fx:
        return 'USD_KRW';
    }
  }
}

extension StockMarketX on StockMarket {
  AssetType get assetType {
    switch (this) {
      case StockMarket.kr:
        return AssetType.stockKR;
    }
  }
}

class StockModel {
  const StockModel({
    required this.ticker,
    required this.assetType,
    required this.assetKey,
    required this.nameKo,
    required this.nameEn,
    required this.rank,
  });

  final String ticker;
  final AssetType assetType;
  final String assetKey;
  final String nameKo;
  final String nameEn;
  final int rank;

  /// Legacy getter kept for existing screens/providers.
  String get market => assetType.code;

  String get displayName {
    if (nameKo.trim().isNotEmpty) {
      return nameKo;
    }
    if (nameEn.trim().isNotEmpty) {
      return nameEn;
    }
    return ticker;
  }

  bool matchesQuery(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return displayName.toLowerCase().contains(normalized) || ticker.toLowerCase().contains(normalized);
  }

  factory StockModel.fromJson(
    Map<String, dynamic> json, {
    required int rank,
    AssetType assetType = AssetType.stockKR,
  }) {
    final String ticker = (json['ticker'] as String? ?? '').trim();
    final String key = assetType == AssetType.stockKR ? ticker : assetType.defaultKey;

    return StockModel(
      ticker: ticker,
      assetType: assetType,
      assetKey: key,
      nameKo: (json['name_ko'] as String? ?? '').trim(),
      nameEn: (json['name_en'] as String? ?? '').trim(),
      rank: rank,
    );
  }
}
