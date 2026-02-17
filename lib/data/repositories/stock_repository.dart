import 'package:stocksimulator/data/datasources/mock_stock_datasource.dart';
import 'package:stocksimulator/data/datasources/price_file_datasource.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class StockRepository {
  StockRepository({
    MockStockDataSource? dataSource,
    PriceFileDataSource? priceDataSource,
  })  : _dataSource = dataSource ?? MockStockDataSource(),
        _priceDataSource = priceDataSource ?? PriceFileDataSource();

  final MockStockDataSource _dataSource;
  final PriceFileDataSource _priceDataSource;

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

  Future<List<SimulationPoint>> loadSimulationSeries({
    required String market,
    required String ticker,
    required DateTime start,
    required DateTime end,
    required int investment,
  }) async {
    final int startYear = start.year;
    final int endYear = end.year;
    final List<PricePoint> all = <PricePoint>[];

    for (int year = startYear; year <= endYear; year++) {
      final PriceYearData payload = await _priceDataSource.loadYear(
        market: market,
        ticker: ticker,
        year: year,
      );
      all.addAll(payload.series);
    }

    final int startYmd = _toYmd(start);
    final int endYmd = _toYmd(end);

    final List<PricePoint> filtered = all
        .where((PricePoint point) => point.ymd >= startYmd && point.ymd <= endYmd)
        .toList()
      ..sort((PricePoint a, PricePoint b) => a.ymd.compareTo(b.ymd));

    if (filtered.isEmpty) {
      return <SimulationPoint>[];
    }

    final double shares = investment / filtered.first.close;
    return filtered
        .map(
          (PricePoint point) => SimulationPoint(
            ymd: point.ymd,
            close: point.close,
            value: shares * point.close,
          ),
        )
        .toList();
  }

  int _toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
}
