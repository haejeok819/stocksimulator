import 'package:stocksimulator/data/cache/simulation_cache.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

enum InvestMode { lumpSum, dca }

enum DcaInterval { monthly, weekly, tradingDaily }

class SimulationFlowState {
  SimulationFlowState({SimulationCache? cache}) : _cache = cache ?? SimulationCache();

  final SimulationCache _cache;

  StockModel? selectedStock;

  DateTime get startDate => _cache.startDate;
  DateTime get endDate => _cache.endDate;
  int get investment => _cache.investment;
  String get marketCode => _cache.selectedMarket;

  InvestMode investMode = InvestMode.lumpSum;
  DcaInterval dcaInterval = DcaInterval.monthly;
  int dcaAmountPerTrade = 100000;

  void selectStock(StockModel stock) {
    selectedStock = stock;
    _cache.selectedTicker = stock.ticker;
    _cache.selectedMarket = stock.market;
  }

  void setDateRange(DateTime start, DateTime end) {
    _cache.startDate = start;
    _cache.endDate = end;
  }

  void setInvestment(int amount) {
    _cache.investment = amount;
  }

  void setInvestMode(InvestMode mode) {
    investMode = mode;
  }

  void setDcaInterval(DcaInterval interval) {
    dcaInterval = interval;
  }

  void setDcaAmountPerTrade(int amount) {
    dcaAmountPerTrade = amount;
  }
}
