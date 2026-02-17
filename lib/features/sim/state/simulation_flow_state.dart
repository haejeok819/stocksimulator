import 'package:stocksimulator/data/cache/simulation_cache.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class SimulationFlowState {
  SimulationFlowState({SimulationCache? cache}) : _cache = cache ?? SimulationCache();

  final SimulationCache _cache;

  StockModel? selectedStock;

  DateTime get startDate => _cache.startDate;
  DateTime get endDate => _cache.endDate;
  int get investment => _cache.investment;
  String get marketCode => _cache.selectedMarket;

  void selectStock(StockModel stock) {
    selectedStock = stock;
    _cache.selectedSymbol = stock.symbol;
    _cache.selectedMarket = stock.market == StockMarket.kr ? 'KR' : 'US';
  }

  void setDateRange(DateTime start, DateTime end) {
    _cache.startDate = start;
    _cache.endDate = end;
  }

  void setInvestment(int amount) {
    _cache.investment = amount;
  }
}
