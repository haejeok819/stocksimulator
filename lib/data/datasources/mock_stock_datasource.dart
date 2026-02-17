import 'dart:math';

import 'package:stocksimulator/data/models/stock_model.dart';

class MockStockDataSource {
  final Random _random = Random();

  List<StockModel> fetchStocks({required StockMarket market}) {
    final List<String> krNames = <String>[
      '삼성전자',
      'SK하이닉스',
      'NAVER',
      '카카오',
      'LG에너지솔루션',
      '현대차',
      '셀트리온',
      '기아',
      'POSCO홀딩스',
      '삼성바이오로직스',
    ];

    final List<String> usNames = <String>[
      'Apple',
      'Microsoft',
      'NVIDIA',
      'Amazon',
      'Alphabet',
      'Meta',
      'Tesla',
      'Broadcom',
      'Netflix',
      'AMD',
    ];

    final String marketCode = market == StockMarket.kr ? 'KR' : 'US';

    return List<StockModel>.generate(100, (int index) {
      final int rank = index + 1;
      if (market == StockMarket.kr) {
        final String base = krNames[index % krNames.length];
        final String ticker = (5930 + index).toString().padLeft(6, '0');
        return StockModel(
          ticker: ticker,
          nameKo: '$base ${rank}위',
          nameEn: '',
          market: marketCode,
          rank: rank,
        );
      }

      final String base = usNames[index % usNames.length];
      final String ticker = '${base.substring(0, min(4, base.length)).toUpperCase()}$rank';
      return StockModel(
        ticker: ticker,
        nameKo: '',
        nameEn: '$base #$rank',
        market: marketCode,
        rank: rank,
      );
    });
  }

  List<double> fetchPriceSeries({required int totalDays}) {
    double price = 100;
    return List<double>.generate(totalDays, (_) {
      price += (_random.nextDouble() - 0.45) * 4.6;
      if (price < 20) {
        price = 20;
      }
      return double.parse(price.toStringAsFixed(2));
    });
  }
}
