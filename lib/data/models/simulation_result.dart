class SimulationResult {
  const SimulationResult({
    required this.ticker,
    required this.startYmd,
    required this.endYmd,
    required this.amount,
    required this.profitRate,
  });

  final String ticker;
  final int startYmd;
  final int endYmd;
  final int amount;
  final double profitRate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ticker': ticker,
      'startYmd': startYmd,
      'endYmd': endYmd,
      'amount': amount,
      'profitRate': profitRate,
    };
  }

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      ticker: json['ticker'] as String? ?? '',
      startYmd: json['startYmd'] as int? ?? 0,
      endYmd: json['endYmd'] as int? ?? 0,
      amount: json['amount'] as int? ?? 0,
      profitRate: (json['profitRate'] as num?)?.toDouble() ?? 0,
    );
  }
}
