import 'package:stocksimulator/data/prices/price_repository.dart';

/// Example usage:
/// 1) Load KR top50 tickers
/// 2) Load one ticker's available years
/// 3) Load selected year data for RangeSlider source
Future<void> usageSnippet() async {
  final PriceRepository repository = PriceRepository();

  final List<String> krTickers = await repository.loadTop50Tickers('KR');
  if (krTickers.isEmpty) {
    throw StateError('No KR tickers in KR_top50_meta.json');
  }

  final String ticker = krTickers.first;
  final List<int> years = await repository.availableYears(market: 'KR', ticker: ticker);
  if (years.isEmpty) {
    throw StateError('No years found for ticker=$ticker');
  }

  final int selectedYear = years.first;
  final Object? yearData = await repository.loadYearData(
    market: 'KR',
    ticker: ticker,
    year: selectedYear,
  );

  // yearData can now be transformed into chart points and bound to RangeSlider.
  print('Loaded year data for $ticker/$selectedYear: ${yearData.runtimeType}');
}
