enum StockMarket { kr }

class StockModel {
  const StockModel({
    required this.ticker,
    required this.market,
    required this.nameKo,
    required this.nameEn,
    required this.rank,
  });

  final String ticker;
  final String market;
  final String nameKo;
  final String nameEn;
  final int rank;

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
    return displayName.toLowerCase().contains(normalized) ||
        ticker.toLowerCase().contains(normalized);
  }

  factory StockModel.fromJson(Map<String, dynamic> json, {required int rank, required String market}) {
    return StockModel(
      ticker: (json['ticker'] as String? ?? '').trim(),
      market: market,
      nameKo: (json['name_ko'] as String? ?? '').trim(),
      nameEn: (json['name_en'] as String? ?? '').trim(),
      rank: rank,
    );
  }
}
