import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';

const int kOneYearTradingDays = 252;

class ChartGameFlowState {
  const ChartGameFlowState({
    required this.initialBetPoints,
    required this.cashPoints,
    required this.positionUnits,
    required this.hasPosition,
    required this.currentIndex,
    required this.equityPoints,
    required this.isFinished,
    required this.finalValue,
    required this.finalReturnPercent,
    required this.assetId,
    required this.assetName,
    required this.startIndex,
    required this.endIndex,
    required this.segment,
    required this.isReady,
    required this.errorMessage,
  });

  const ChartGameFlowState.initial()
      : initialBetPoints = 0,
        cashPoints = 0,
        positionUnits = 0,
        hasPosition = false,
        currentIndex = 0,
        equityPoints = 0,
        isFinished = false,
        finalValue = null,
        finalReturnPercent = null,
        assetId = null,
        assetName = null,
        startIndex = null,
        endIndex = null,
        segment = const <PricePoint>[],
        isReady = false,
        errorMessage = null;

  final int initialBetPoints;
  final double cashPoints;
  final double positionUnits;
  final bool hasPosition;
  final int currentIndex;
  final double equityPoints;
  final bool isFinished;
  final double? finalValue;
  final double? finalReturnPercent;

  final String? assetId;
  final String? assetName;
  final int? startIndex;
  final int? endIndex;
  final List<PricePoint> segment;
  final bool isReady;
  final String? errorMessage;

  ChartGameFlowState copyWith({
    int? initialBetPoints,
    double? cashPoints,
    double? positionUnits,
    bool? hasPosition,
    int? currentIndex,
    double? equityPoints,
    bool? isFinished,
    double? finalValue,
    bool clearFinalValue = false,
    double? finalReturnPercent,
    bool clearFinalReturnPercent = false,
    String? assetId,
    bool clearAssetId = false,
    String? assetName,
    bool clearAssetName = false,
    int? startIndex,
    bool clearStartIndex = false,
    int? endIndex,
    bool clearEndIndex = false,
    List<PricePoint>? segment,
    bool? isReady,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChartGameFlowState(
      initialBetPoints: initialBetPoints ?? this.initialBetPoints,
      cashPoints: cashPoints ?? this.cashPoints,
      positionUnits: positionUnits ?? this.positionUnits,
      hasPosition: hasPosition ?? this.hasPosition,
      currentIndex: currentIndex ?? this.currentIndex,
      equityPoints: equityPoints ?? this.equityPoints,
      isFinished: isFinished ?? this.isFinished,
      finalValue: clearFinalValue ? null : (finalValue ?? this.finalValue),
      finalReturnPercent:
          clearFinalReturnPercent ? null : (finalReturnPercent ?? this.finalReturnPercent),
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
      assetName: clearAssetName ? null : (assetName ?? this.assetName),
      startIndex: clearStartIndex ? null : (startIndex ?? this.startIndex),
      endIndex: clearEndIndex ? null : (endIndex ?? this.endIndex),
      segment: segment ?? this.segment,
      isReady: isReady ?? this.isReady,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final NotifierProvider<ChartGameFlowController, ChartGameFlowState>
    chartGameFlowControllerProvider =
    NotifierProvider<ChartGameFlowController, ChartGameFlowState>(
  ChartGameFlowController.new,
);

class ChartGameFlowController extends Notifier<ChartGameFlowState> {
  final StockRepository _repository = StockRepository();
  final Random _random = Random();

  @override
  ChartGameFlowState build() => const ChartGameFlowState.initial();

  void setBetPoints(int n) {
    final double bet = n.toDouble();
    state = state.copyWith(
      initialBetPoints: n,
      cashPoints: bet,
      positionUnits: 0,
      hasPosition: false,
      currentIndex: 0,
      equityPoints: bet,
      isFinished: false,
      clearFinalValue: true,
      clearFinalReturnPercent: true,
      clearAssetId: true,
      clearAssetName: true,
      clearStartIndex: true,
      clearEndIndex: true,
      segment: const <PricePoint>[],
      isReady: false,
      clearError: true,
    );
  }

  Future<void> startGame() async {
    if (state.isReady && state.segment.isNotEmpty) {
      return;
    }

    try {
      final StockModel picked = await _pickRandomAsset();
      final List<PricePoint> fullSeries = await _loadFullSeries(picked);
      if (fullSeries.length < 200) {
        throw Exception('not enough data');
      }

      final int oneYearLength = min(kOneYearTradingDays, fullSeries.length);
      final int maxStart = fullSeries.length - oneYearLength;

      int chosenStart = 0;
      bool found = false;
      for (int i = 0; i < 10; i++) {
        final int candidate = maxStart <= 0 ? 0 : _random.nextInt(maxStart + 1);
        final int candidateEnd = candidate + oneYearLength - 1;
        if (candidateEnd - candidate + 1 >= 200) {
          chosenStart = candidate;
          found = true;
          break;
        }
      }
      if (!found) {
        throw Exception('range pick failed');
      }

      final int chosenEnd = chosenStart + oneYearLength - 1;
      final List<PricePoint> segment = fullSeries.sublist(chosenStart, chosenEnd + 1);

      final double bet = state.initialBetPoints.toDouble();
      state = state.copyWith(
        assetId: picked.assetKey,
        assetName: picked.displayName,
        startIndex: chosenStart,
        endIndex: chosenEnd,
        segment: segment,
        isReady: true,
        clearError: true,
        cashPoints: bet,
        positionUnits: 0,
        hasPosition: false,
        currentIndex: 0,
        equityPoints: bet,
        isFinished: false,
        clearFinalValue: true,
        clearFinalReturnPercent: true,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: '랜덤 선택에 실패했어요', isReady: false);
      rethrow;
    }
  }

  void updateCurrentIndex(int index) {
    if (state.segment.isEmpty || state.isFinished) return;
    final int clamped = index.clamp(0, state.segment.length - 1);
    final double currentPrice = state.segment[clamped].close;
    final double equity = state.cashPoints + (state.positionUnits * currentPrice);
    state = state.copyWith(currentIndex: clamped, equityPoints: equity);
  }

  void onBuy(int currentIndex) {
    if (state.isFinished || state.hasPosition || state.cashPoints <= 0 || state.segment.isEmpty) return;

    final int clamped = currentIndex.clamp(0, state.segment.length - 1);
    final double currentPrice = state.segment[clamped].close;
    if (currentPrice <= 0) return;

    final double units = state.cashPoints / currentPrice;
    final double equity = units * currentPrice;
    state = state.copyWith(
      currentIndex: clamped,
      positionUnits: units,
      cashPoints: 0,
      hasPosition: true,
      equityPoints: equity,
    );
  }

  void onSell(int currentIndex) {
    if (state.isFinished || !state.hasPosition || state.segment.isEmpty) return;

    final int clamped = currentIndex.clamp(0, state.segment.length - 1);
    final double currentPrice = state.segment[clamped].close;
    final double cash = state.positionUnits * currentPrice;
    state = state.copyWith(
      currentIndex: clamped,
      cashPoints: cash,
      positionUnits: 0,
      hasPosition: false,
      equityPoints: cash,
    );
  }

  void finishGame() {
    if (state.segment.isEmpty || state.isFinished) return;

    final int lastIndex = state.segment.length - 1;
    double cash = state.cashPoints;
    double units = state.positionUnits;
    final double lastPrice = state.segment[lastIndex].close;

    if (state.hasPosition && units > 0) {
      cash = units * lastPrice;
      units = 0;
    }

    final double initial = state.initialBetPoints.toDouble();
    final double finalValue = cash;
    final double finalReturn = initial <= 0 ? 0 : ((finalValue / initial) - 1) * 100;

    state = state.copyWith(
      currentIndex: lastIndex,
      cashPoints: cash,
      positionUnits: units,
      hasPosition: false,
      equityPoints: finalValue,
      isFinished: true,
      finalValue: finalValue,
      finalReturnPercent: finalReturn,
    );
  }

  Future<StockModel> _pickRandomAsset() async {
    final List<StockModel> all = await _repository.getTopStocks(assetType: AssetType.stockKR);
    final List<StockModel> pool = all
        .where(
          (StockModel e) =>
              e.assetType == AssetType.stockKR ||
              e.assetType == AssetType.gold ||
              e.assetType == AssetType.fx,
        )
        .toList(growable: false);
    if (pool.isEmpty) throw Exception('no asset');
    return pool[_random.nextInt(pool.length)];
  }

  Future<List<PricePoint>> _loadFullSeries(StockModel stock) async {
    final List<int> days =
        await _repository.loadTradingDays(assetType: stock.assetType, assetKey: stock.assetKey);
    if (days.isEmpty) return <PricePoint>[];
    final DateTime start = _fromYmd(days.first);
    final DateTime end = _fromYmd(days.last);
    return _repository.loadRangeByAsset(
      assetType: stock.assetType,
      assetKey: stock.assetKey,
      start: start,
      end: end,
    );
  }

  DateTime _fromYmd(int ymd) {
    final int y = ymd ~/ 10000;
    final int m = (ymd % 10000) ~/ 100;
    final int d = ymd % 100;
    return DateTime(y, m, d);
  }
}
