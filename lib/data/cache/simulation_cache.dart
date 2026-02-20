import 'package:stocksimulator/data/models/stock_model.dart';

class SimulationCache {
  String? selectedTicker;
  AssetType selectedAssetType = AssetType.stockKR;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 89));
  DateTime endDate = DateTime.now();
  int investment = 1000000;
}
