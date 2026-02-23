import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';

const int kOneYearTradingDays = 252;

enum ChartGamePhase { canBuy, canSell, done }

class ChartGameResult {
  const ChartGameResult({
    required this.returnPercent,
    required this.buyDate,
    required this.sellDate,
    required this.buyIndex,
    required this.sellIndex,
  });

  final double returnPercent;
  final int buyDate;
  final int sellDate;
  final int buyIndex;
  final int sellIndex;
}

class ChartGameFlowState {
  const ChartGameFlowState({
    required this.betPoints,
    required this.assetId,
    required this.assetName,
    required this.startIndex,
    required this.endIndex,
    required this.phase,
    required this.buyIndex,
    required this.sellIndex,
    required this.result,
    required this.segment,
    required this.isReady,
    required this.errorMessage,
  });

  const ChartGameFlowState.initial()
      : betPoints = 0,
        assetId = null,
        assetName = null,
        startIndex = null,
        endIndex = null,
        phase = ChartGamePhase.canBuy,
        buyIndex = null,
        sellIndex = null,
        result = null,
        segment = const <PricePoint>[],
        isReady = false,
        errorMessage = null;

  final int betPoints;
  final String? assetId;
  final String? assetName;
  final int? startIndex;
  final int? endIndex;
  final ChartGamePhase phase;
  final int? buyIndex;
  final int? sellIndex;
  final ChartGameResult? result;
  final List<PricePoint> segment;
  final bool isReady;
  final String? errorMessage;

  ChartGameFlowState copyWith({
    int? betPoints,
    String? assetId,
    bool clearAssetId = false,
    String? assetName,
    bool clearAssetName = false,
    int? startIndex,
    bool clearStartIndex = false,
    int? endIndex,
    bool clearEndIndex = false,
    ChartGamePhase? phase,
    int? buyIndex,
    bool clearBuyIndex = false,
    int? sellIndex,
    bool clearSellIndex = false,
    ChartGameResult? result,
    bool clearResult = false,
    List<PricePoint>? segment,
    bool? isReady,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChartGameFlowState(
      betPoints: betPoints ?? this.betPoints,
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
      assetName: clearAssetName ? null : (assetName ?? this.assetName),
      startIndex: clearStartIndex ? null : (startIndex ?? this.startIndex),
      endIndex: clearEndIndex ? null : (endIndex ?? this.endIndex),
      phase: phase ?? this.phase,
      buyIndex: clearBuyIndex ? null : (buyIndex ?? this.buyIndex),
      sellIndex: clearSellIndex ? null : (sellIndex ?? this.sellIndex),
      result: clearResult ? null : (result ?? this.result),
      segment: segment ?? this.segment,
      isReady: isReady ?? this.isReady,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final NotifierProvider<ChartGameFlowController, ChartGameFlowState> chartGameFlowControllerProvider =
    NotifierProvider<ChartGameFlowController, ChartGameFlowState>(ChartGameFlowController.new);

class ChartGameFlowController extends Notifier<ChartGameFlowState> {
  final StockRepository _repository = StockRepository();
  final Random _random = Random();

  @override
  ChartGameFlowState build() => const ChartGameFlowState.initial();

  void setBetPoints(int n) {
    state = state.copyWith(
      betPoints: n,
      phase: ChartGamePhase.canBuy,
      clearBuyIndex: true,
      clearSellIndex: true,
      clearResult: true,
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

      state = state.copyWith(
        assetId: picked.assetKey,
        assetName: picked.displayName,
        startIndex: chosenStart,
        endIndex: chosenEnd,
        segment: segment,
        phase: ChartGamePhase.canBuy,
        clearBuyIndex: true,
        clearSellIndex: true,
        clearResult: true,
        isReady: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: '랜덤 선택에 실패했어요', isReady: false);
      rethrow;
    }
  }

  void onBuy(int currentIndex) {
    if (state.phase != ChartGamePhase.canBuy) return;
    state = state.copyWith(buyIndex: currentIndex, phase: ChartGamePhase.canSell);
  }

  void onSell(int currentIndex) {
    if (state.phase != ChartGamePhase.canSell || state.buyIndex == null || state.segment.isEmpty) return;

    final int sell = currentIndex.clamp(0, state.segment.length - 1);
    final int buy = state.buyIndex!.clamp(0, state.segment.length - 1);
    final PricePoint buyPoint = state.segment[buy];
    final PricePoint sellPoint = state.segment[sell];
    final double returnPercent = ((sellPoint.close / buyPoint.close) - 1) * 100;

    state = state.copyWith(
      sellIndex: sell,
      phase: ChartGamePhase.done,
      result: ChartGameResult(
        returnPercent: returnPercent,
        buyDate: buyPoint.ymd,
        sellDate: sellPoint.ymd,
        buyIndex: buy,
        sellIndex: sell,
      ),
    );
  }

  Future<StockModel> _pickRandomAsset() async {
    final List<StockModel> all = await _repository.getTopStocks(assetType: AssetType.stockKR);
    final List<StockModel> pool = all
        .where((StockModel e) =>
            e.assetType == AssetType.stockKR || e.assetType == AssetType.gold || e.assetType == AssetType.fx)
        .toList(growable: false);
    if (pool.isEmpty) throw Exception('no asset');
    return pool[_random.nextInt(pool.length)];
  }

  Future<List<PricePoint>> _loadFullSeries(StockModel stock) async {
    final List<int> days = await _repository.loadTradingDays(assetType: stock.assetType, assetKey: stock.assetKey);
    if (days.isEmpty) return <PricePoint>[];
    final DateTime start = _fromYmd(days.first);
    final DateTime end = _fromYmd(days.last);
    return _repository.loadRangeByAsset(assetType: stock.assetType, assetKey: stock.assetKey, start: start, end: end);
  }

  DateTime _fromYmd(int ymd) {
    final int y = ymd ~/ 10000;
    final int m = (ymd % 10000) ~/ 100;
    final int d = ymd % 100;
    return DateTime(y, m, d);
  }
}
