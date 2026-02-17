import 'package:stocksimulator/data/cache/simulation_cache.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class SimulationFlowState {
  SimulationFlowState({SimulationCache? cache}) : _cache = cache ?? SimulationCache();

  final SimulationCache _cache;

  StockModel? selectedStock;

  int get startIndex => _cache.startIndex;
  int get endIndex => _cache.endIndex;
  int get investment => _cache.investment;

  void selectStock(StockModel stock) {
    selectedStock = stock;
    _cache.selectedSymbol = stock.symbol;
  }

  void setRange(int start, int end) {
    _cache.startIndex = start;
    _cache.endIndex = end;
  }

  void setInvestment(int amount) {
    _cache.investment = amount;
  }
}
