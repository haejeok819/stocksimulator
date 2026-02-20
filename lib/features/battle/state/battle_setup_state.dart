import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/stock_model.dart';

class BattleSetupState {
  const BattleSetupState({
    required this.market,
    required this.stockA,
    required this.stockB,
    required this.startDate,
    required this.endDate,
    required this.investAmount,
  });

  final StockMarket market;
  final StockModel? stockA;
  final StockModel? stockB;
  final DateTime startDate;
  final DateTime endDate;
  final int investAmount;

  BattleSetupState copyWith({
    StockMarket? market,
    StockModel? stockA,
    StockModel? stockB,
    DateTime? startDate,
    DateTime? endDate,
    int? investAmount,
    bool clearA = false,
    bool clearB = false,
  }) {
    return BattleSetupState(
      market: market ?? this.market,
      stockA: clearA ? null : (stockA ?? this.stockA),
      stockB: clearB ? null : (stockB ?? this.stockB),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      investAmount: investAmount ?? this.investAmount,
    );
  }
}

class BattleSetupNotifier extends StateNotifier<BattleSetupState> {
  BattleSetupNotifier()
      : super(
          BattleSetupState(
            market: StockMarket.kr,
            stockA: null,
            stockB: null,
            startDate: DateTime.now().subtract(const Duration(days: 180)),
            endDate: DateTime.now(),
            investAmount: 1000000,
          ),
        );

  void setMarket(StockMarket market) {
    state = state.copyWith(market: market, clearA: true, clearB: true);
  }

  void setStockA(StockModel? stock) => state = state.copyWith(stockA: stock);
  void setStockB(StockModel? stock) => state = state.copyWith(stockB: stock);
  void setDateRange(DateTime startDate, DateTime endDate) => state = state.copyWith(startDate: startDate, endDate: endDate);
  void setInvestAmount(int amount) => state = state.copyWith(investAmount: amount);
}

final StateNotifierProvider<BattleSetupNotifier, BattleSetupState> battleSetupProvider =
    StateNotifierProvider<BattleSetupNotifier, BattleSetupState>((Ref ref) => BattleSetupNotifier());

enum BattleRunStatus { ready, running, paused, finished }

class BattleRunState {
  const BattleRunState({
    required this.status,
    required this.progressIndex,
    required this.currentValueA,
    required this.currentValueB,
    required this.currentReturnA,
    required this.currentReturnB,
  });

  final BattleRunStatus status;
  final int progressIndex;
  final double currentValueA;
  final double currentValueB;
  final double currentReturnA;
  final double currentReturnB;

  BattleRunState copyWith({
    BattleRunStatus? status,
    int? progressIndex,
    double? currentValueA,
    double? currentValueB,
    double? currentReturnA,
    double? currentReturnB,
  }) {
    return BattleRunState(
      status: status ?? this.status,
      progressIndex: progressIndex ?? this.progressIndex,
      currentValueA: currentValueA ?? this.currentValueA,
      currentValueB: currentValueB ?? this.currentValueB,
      currentReturnA: currentReturnA ?? this.currentReturnA,
      currentReturnB: currentReturnB ?? this.currentReturnB,
    );
  }
}

class BattleRunNotifier extends StateNotifier<BattleRunState> {
  BattleRunNotifier()
      : super(
          const BattleRunState(
            status: BattleRunStatus.ready,
            progressIndex: 0,
            currentValueA: 0,
            currentValueB: 0,
            currentReturnA: 0,
            currentReturnB: 0,
          ),
        );

  void setStateValue(BattleRunState value) => state = value;
}

final StateNotifierProvider<BattleRunNotifier, BattleRunState> battleRunProvider =
    StateNotifierProvider<BattleRunNotifier, BattleRunState>((Ref ref) => BattleRunNotifier());

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
