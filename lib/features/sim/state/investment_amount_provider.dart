import 'package:flutter_riverpod/flutter_riverpod.dart';

const int kMinInvestmentAmount = 100;
const int kMaxInvestmentAmount = 100000000;

class InvestmentAmountNotifier extends StateNotifier<int> {
  InvestmentAmountNotifier([int initialAmount = 1000000]) : super(_clamp(initialAmount));

  void setAmount(int value) {
    state = _clamp(value);
  }

  void addAmount(int delta) {
    state = _clamp(state + delta);
  }

  static int _clamp(int value) {
    return value.clamp(kMinInvestmentAmount, kMaxInvestmentAmount);
  }
}

final StateNotifierProvider<InvestmentAmountNotifier, int> investmentAmountProvider =
    StateNotifierProvider<InvestmentAmountNotifier, int>((Ref ref) {
      return InvestmentAmountNotifier();
    });
