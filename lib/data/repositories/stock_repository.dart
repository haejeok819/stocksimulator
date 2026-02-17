import 'package:stocksimulator/data/datasources/mock_stock_datasource.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class StockRepository {
  StockRepository({MockStockDataSource? dataSource})
      : _dataSource = dataSource ?? MockStockDataSource();

  final MockStockDataSource _dataSource;

  List<StockModel> getStocks() => _dataSource.fetchStocks();

  List<double> getChartPrices() => _dataSource.fetchPriceSeries(totalDays: 90);
}
