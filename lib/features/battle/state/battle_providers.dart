import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/battle/state/battle_data_normalizer.dart';

class BattleSetupState {
  const BattleSetupState({
    required this.stockA,
    required this.stockB,
    required this.startDate,
    required this.endDate,
    required this.investAmount,
    required this.safeMode,
  });

  final StockModel? stockA;
  final StockModel? stockB;
  final DateTime startDate;
  final DateTime endDate;
  final int investAmount;
  final bool safeMode;

  BattleSetupState copyWith({
    StockModel? stockA,
    StockModel? stockB,
    DateTime? startDate,
    DateTime? endDate,
    int? investAmount,
    bool? safeMode,
    bool clearA = false,
    bool clearB = false,
  }) {
    return BattleSetupState(
      stockA: clearA ? null : (stockA ?? this.stockA),
      stockB: clearB ? null : (stockB ?? this.stockB),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      investAmount: investAmount ?? this.investAmount,
      safeMode: safeMode ?? this.safeMode,
    );
  }
}

class BattleSetupNotifier extends StateNotifier<BattleSetupState> {
  BattleSetupNotifier({required bool defaultSafeMode})
      : super(
          BattleSetupState(
            stockA: null,
            stockB: null,
            startDate: DateTime.now().subtract(const Duration(days: 180)),
            endDate: DateTime.now(),
            investAmount: 1000000,
            safeMode: defaultSafeMode,
          ),
        );

  void setStockA(StockModel? stock) => state = state.copyWith(stockA: stock);

  void setStockB(StockModel? stock) => state = state.copyWith(stockB: stock);

  void setDateRange(DateTime startDate, DateTime endDate) => state = state.copyWith(startDate: startDate, endDate: endDate);

  void setInvestAmount(int amount) => state = state.copyWith(investAmount: amount);

  void setSafeMode(bool enabled) => state = state.copyWith(safeMode: enabled);

  void resetSelection() => state = state.copyWith(clearA: true, clearB: true);
}

final Provider<StockRepository> battleStockRepositoryProvider = Provider<StockRepository>((Ref ref) => StockRepository());

final StateNotifierProvider<BattleSetupNotifier, BattleSetupState> battleSetupProvider =
    StateNotifierProvider<BattleSetupNotifier, BattleSetupState>(
  (Ref ref) => BattleSetupNotifier(defaultSafeMode: ref.watch(battleDefaultSafeModeProvider)),
);

final Provider<bool> battleDefaultSafeModeProvider = Provider<bool>((Ref ref) {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
    _ => false,
  };
});

class BattleSeriesData {
  const BattleSeriesData({
    required this.normalized,
    required this.amount,
    required this.sharesA,
    required this.sharesB,
    required this.valuesA,
    required this.valuesB,
  });

  final NormalizedBattleSeries normalized;
  final double amount;
  final double sharesA;
  final double sharesB;
  final List<double> valuesA;
  final List<double> valuesB;

  int get length => normalized.dates.length;

  BattleTick tickAt(int index) {
    final int safe = index.clamp(0, length - 1);
    final double valueA = valuesA[safe];
    final double valueB = valuesB[safe];
    return BattleTick(
      ymd: normalized.dates[safe],
      valueA: valueA,
      valueB: valueB,
      returnA: ((valueA - amount) / amount) * 100,
      returnB: ((valueB - amount) / amount) * 100,
    );
  }
}

class BattleTick {
  const BattleTick({
    required this.ymd,
    required this.valueA,
    required this.valueB,
    required this.returnA,
    required this.returnB,
  });

  final int ymd;
  final double valueA;
  final double valueB;
  final double returnA;
  final double returnB;
}

final FutureProvider.autoDispose<BattleSeriesData> battleDataProvider = FutureProvider.autoDispose<BattleSeriesData>((Ref ref) async {
  final BattleSetupState setup = ref.watch(battleSetupProvider);
  if (setup.stockA == null || setup.stockB == null) {
    throw StateError('종목 A/B를 먼저 선택하세요.');
  }

  final StockRepository repository = ref.watch(battleStockRepositoryProvider);
  final List<PricePoint> aSeries = await repository.loadRange(
    market: setup.stockA!.market,
    ticker: setup.stockA!.ticker,
    start: setup.startDate,
    end: setup.endDate,
  );
  final List<PricePoint> bSeries = await repository.loadRange(
    market: setup.stockB!.market,
    ticker: setup.stockB!.ticker,
    start: setup.startDate,
    end: setup.endDate,
  );

  final NormalizedBattleSeries normalized = normalizeBattleSeries(aSeries: aSeries, bSeries: bSeries);
  if (normalized.dates.length < 30) {
    throw StateError('교집합 거래일이 부족합니다(최소 30일).');
  }

  final double amount = setup.investAmount.toDouble();
  final double sharesA = amount / normalized.closeA.first;
  final double sharesB = amount / normalized.closeB.first;

  final List<double> valuesA = normalized.closeA.map((double close) => sharesA * close).toList(growable: false);
  final List<double> valuesB = normalized.closeB.map((double close) => sharesB * close).toList(growable: false);

  return BattleSeriesData(
    normalized: normalized,
    amount: amount,
    sharesA: sharesA,
    sharesB: sharesB,
    valuesA: valuesA,
    valuesB: valuesB,
  );
});

class BattleResultState {
  const BattleResultState({
    required this.finalValueA,
    required this.finalValueB,
    required this.finalReturnA,
    required this.finalReturnB,
    required this.winner,
  });

  final double finalValueA;
  final double finalValueB;
  final double finalReturnA;
  final double finalReturnB;
  final String winner;
}

final StateProvider<BattleResultState?> battleResultProvider = StateProvider<BattleResultState?>((Ref ref) => null);
