import 'package:stocksimulator/data/datasources/mock_stock_datasource.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class StockRepository {
  StockRepository({MockStockDataSource? dataSource})
      : _dataSource = dataSource ?? MockStockDataSource();

  final MockStockDataSource _dataSource;

  List<StockModel> getTopStocks({required StockMarket market, String query = ''}) {
    final List<StockModel> stocks = _dataSource.fetchStocks(market: market);
    final String normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return stocks;
    }

    return stocks
        .where(
          (StockModel stock) =>
              stock.name.toLowerCase().contains(normalized) ||
              stock.symbol.toLowerCase().contains(normalized),
        )
        .toList();
  }

  List<double> getChartPrices() => _dataSource.fetchPriceSeries(totalDays: 90);
}
