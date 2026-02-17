class SimulationCache {
  String? selectedTicker;
  String selectedMarket = 'KR';
  DateTime startDate = DateTime.now().subtract(const Duration(days: 89));
  DateTime endDate = DateTime.now();
  int investment = 1000000;
}
