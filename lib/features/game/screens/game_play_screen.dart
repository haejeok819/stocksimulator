import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';
import 'package:stocksimulator/features/game/state/game_point_providers.dart';
import 'package:stocksimulator/features/game/widgets/chart_game_result_dialog.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key});

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Timer? _sellLockTimer;
  double _playbackPosition = 0;
  Duration? _last;
  int _index = 0;
  double _pulse = 0;
  bool _resultShown = false;
  bool _settlementDone = false;
  int _sellRemainingSec = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _sellLockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final int next = _computeSellRemaining(ref.read(chartGameFlowControllerProvider));
      if (next != _sellRemainingSec) {
        setState(() => _sellRemainingSec = next);
      }
    });
  }

  @override
  void dispose() {
    _sellLockTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);
    if (flow.segment.isEmpty || flow.isFinished) return;

    final Duration previous = _last ?? elapsed;
    _last = elapsed;
    final double dt = max(0, (elapsed - previous).inMicroseconds) / 1000000;
    if (dt <= 0) return;

    final int maxIndex = flow.segment.length - 1;
    _playbackPosition = (_playbackPosition + (2.2 * dt)).clamp(0, maxIndex.toDouble());
    _index = _playbackPosition.floor();
    _pulse += dt * 4.4;

    ref.read(chartGameFlowControllerProvider.notifier).updateCurrentIndex(_index);
    if (mounted) {
      final int next = _computeSellRemaining(ref.read(chartGameFlowControllerProvider));
      setState(() => _sellRemainingSec = next);
    }

    if (_index >= maxIndex) {
      _finishAndShowResult();
    }
  }

  int _computeSellRemaining(ChartGameFlowState flow) {
    if (!flow.hasPosition || flow.sellUnlockAt == null || flow.isFinished) return 0;
    final int ms = flow.sellUnlockAt!.difference(DateTime.now()).inMilliseconds;
    final int sec = (ms / 1000).ceil();
    return sec.clamp(0, 5);
  }

  bool _canSell(ChartGameFlowState flow) {
    return !flow.isFinished && flow.hasPosition && _computeSellRemaining(flow) == 0;
  }

  void _buy() {
    ref.read(chartGameFlowControllerProvider.notifier).onBuy(_index);
    final int next = _computeSellRemaining(ref.read(chartGameFlowControllerProvider));
    setState(() => _sellRemainingSec = next);
  }

  void _sell() {
    final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);
    if (!_canSell(flow)) return;
    ref.read(chartGameFlowControllerProvider.notifier).onSell(_index);
    setState(() => _sellRemainingSec = 0);
  }

  Future<void> _finishAndShowResult() async {
    final ChartGameFlowController controller =
        ref.read(chartGameFlowControllerProvider.notifier);
    controller.finishGame();
    final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);

    if (!_settlementDone) {
      _settlementDone = true;
      final bool isWindowsGuest = _isWindowsGuest();
      final bool isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (isMobile && !isWindowsGuest && flow.finalValue != null) {
        try {
          await ref
              .read(gamePointControllerProvider.notifier)
              .earnGameResult(flow.finalValue!.round());
        } catch (_) {}
      }
    }

    if (_resultShown) return;
    _resultShown = true;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ChartGameResultDialog(
          flow: flow,
          isWindowsGuest: _isWindowsGuest(),
          onRetry: () {
            Navigator.of(context).pop();
            Navigator.of(this.context)
                .popUntil((Route<dynamic> route) => route.settings.name == 'game_bet');
          },
          onClose: () {
            Navigator.of(context).pop();
            Navigator.of(this.context)
                .popUntil((Route<dynamic> route) => route.settings.name == null);
          },
        );
      },
    );
  }

  bool _isWindowsGuest() {
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final bool isLoggedIn = (ref.read(authControllerProvider).user?.uid ?? '').isNotEmpty;
    return isWindows && !isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    final ChartGameFlowState flow = ref.watch(chartGameFlowControllerProvider);
    final List<SimulationPoint> points = flow.segment
        .map((e) => SimulationPoint(ymd: e.ymd, close: e.close, value: e.close))
        .toList(growable: false);

    final double pnl = flow.equityPoints - flow.initialBetPoints;
    final double returnPercent =
        flow.initialBetPoints <= 0 ? 0 : ((flow.equityPoints / flow.initialBetPoints) - 1) * 100;
    final double progress = points.isEmpty ? 0 : (_index / max(1, points.length - 1));

    final String status = flow.isFinished
        ? '게임 종료'
        : (flow.hasPosition ? '이쯤에서 털까?' : '지금 들어갈까?');

    return Scaffold(
      appBar: AppBar(title: Text(flow.assetName ?? '차트 게임')),
      backgroundColor: AppColors.background,
      body: points.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  flow.assetName ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${AppNumberFormat.formatInt(flow.equityPoints)}P',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '손익 ${pnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(pnl)}P  ·  수익률 ${returnPercent >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%',
                            style: const TextStyle(
                                color: AppColors.helperText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              const Text('게임 진행률',
                                  style: TextStyle(
                                      color: AppColors.helperText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      color: AppColors.helperText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 7,
                              value: progress.clamp(0, 1),
                              backgroundColor: AppColors.helperText.withOpacity(0.16),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.action),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: StockChartPlayer(
                      points: points,
                      currentIndex: _index,
                      playbackPosition: _playbackPosition,
                      pulse: 0.5 + sin(_pulse) * 0.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(status, style: const TextStyle(color: AppColors.helperText)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (!flow.isFinished && !flow.hasPosition && flow.cashPoints > 0)
                              ? _buy
                              : null,
                          child: const Text('매수'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _canSell(flow) ? _sell : null,
                          child: Text(_sellRemainingSec > 0 ? '매도 (${_sellRemainingSec})' : '매도'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
