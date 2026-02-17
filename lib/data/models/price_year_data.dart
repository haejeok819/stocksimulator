class PricePoint {
  const PricePoint({required this.ymd, required this.close});

  final int ymd;
  final double close;
}

class PriceYearData {
  const PriceYearData({
    required this.v,
    required this.market,
    required this.ticker,
    required this.currency,
    required this.priceScale,
    required this.year,
    required this.series,
  });

  final int v;
  final String market;
  final String ticker;
  final String currency;
  final int priceScale;
  final int year;
  final List<PricePoint> series;

  factory PriceYearData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSeries = json['series'] as List<dynamic>? ?? <dynamic>[];
    return PriceYearData(
      v: json['v'] as int? ?? 1,
      market: json['market'] as String? ?? '',
      ticker: json['ticker'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      priceScale: json['priceScale'] as int? ?? 1,
      year: json['year'] as int? ?? 0,
      series: rawSeries
          .whereType<List<dynamic>>()
          .where((List<dynamic> row) => row.length >= 2)
          .map(
            (List<dynamic> row) => PricePoint(
              ymd: row[0] as int,
              close: (row[1] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}
