import 'dart:math';

import 'package:stocksimulator/data/models/stock_model.dart';

class MockStockDataSource {
  final Random _random = Random();

  List<StockModel> fetchStocks() {
    return const <StockModel>[
      StockModel(symbol: '005930', name: '삼성전자'),
      StockModel(symbol: '000660', name: 'SK하이닉스'),
      StockModel(symbol: '035420', name: 'NAVER'),
      StockModel(symbol: '035720', name: '카카오'),
    ];
  }

  List<double> fetchPriceSeries({required int totalDays}) {
    double price = 100;
    return List<double>.generate(totalDays, (_) {
      price += (_random.nextDouble() - 0.45) * 4.6;
      if (price < 20) price = 20;
      return double.parse(price.toStringAsFixed(2));
    });
  }
}
