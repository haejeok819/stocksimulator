enum StockMarket { kr, us }

class StockModel {
  const StockModel({
    required this.symbol,
    required this.name,
    required this.market,
    required this.rank,
  });

  final String symbol;
  final String name;
  final StockMarket market;
  final int rank;
}
