import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';
import 'package:stocksimulator/features/game/state/game_point_providers.dart';
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
  double _playbackPosition = 0;
  Duration? _last;
  int _index = 0;
  double _pulse = 0;
  double _speed = 1;
  bool _resultShown = false;
  bool _settlementDone = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
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
    _playbackPosition = (_playbackPosition + (2.2 * _speed * dt)).clamp(0, maxIndex.toDouble());
    _index = _playbackPosition.floor();
    _pulse += dt * 4.4;

    ref.read(chartGameFlowControllerProvider.notifier).updateCurrentIndex(_index);
    if (mounted) setState(() {});

    if (_index >= maxIndex) {
      _finishAndShowResult();
    }
  }

  void _buy() {
    ref.read(chartGameFlowControllerProvider.notifier).onBuy(_index);
  }

  void _sell() {
    ref.read(chartGameFlowControllerProvider.notifier).onSell(_index);
  }

  Future<void> _finishAndShowResult() async {
    final ChartGameFlowController controller = ref.read(chartGameFlowControllerProvider.notifier);
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) {
        return _ResultSheet(
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
    final double returnPercent = flow.initialBetPoints <= 0
        ? 0
        : ((flow.equityPoints / flow.initialBetPoints) - 1) * 100;

    return Scaffold(
      appBar: AppBar(title: Text(flow.assetName ?? '차트 게임')),
      backgroundColor: AppColors.background,
      body: points.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('평가금액: ${AppNumberFormat.formatInt(flow.equityPoints)}P',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          '손익: ${pnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(pnl)}P  /  '
                          '수익률: ${returnPercent >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%',
                          style: const TextStyle(color: AppColors.helperText, fontSize: 12),
                        ),
                      ],
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
                  child: Text(
                    flow.isFinished
                        ? '게임 종료'
                        : (flow.hasPosition ? '포지션 보유 중 - 원하는 타이밍에 SELL' : '현금 보유 중 - 원하는 타이밍에 BUY'),
                    style: const TextStyle(color: AppColors.helperText),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      _SpeedChip(label: '1x', selected: _speed == 1, onTap: () => setState(() => _speed = 1)),
                      const SizedBox(width: 8),
                      _SpeedChip(label: '2x', selected: _speed == 2, onTap: () => setState(() => _speed = 2)),
                      const SizedBox(width: 8),
                      _SpeedChip(label: '4x', selected: _speed == 4, onTap: () => setState(() => _speed = 4)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (!flow.isFinished && !flow.hasPosition && flow.cashPoints > 0) ? _buy : null,
                          child: const Text('BUY'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (!flow.isFinished && flow.hasPosition) ? _sell : null,
                          child: const Text('SELL'),
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

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.flow,
    required this.isWindowsGuest,
    required this.onRetry,
    required this.onClose,
  });

  final ChartGameFlowState flow;
  final bool isWindowsGuest;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final double finalValue = flow.finalValue ?? flow.equityPoints;
    final double finalReturn = flow.finalReturnPercent ?? 0;
    final int startYmd = flow.segment.isNotEmpty ? flow.segment.first.ymd : 0;
    final int endYmd = flow.segment.isNotEmpty ? flow.segment.last.ymd : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(flow.assetName ?? '-',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('기간: 1년', style: TextStyle(color: AppColors.helperText)),
          if (startYmd > 0 && endYmd > 0)
            Text('구간: ${_formatYmd(startYmd)} ~ ${_formatYmd(endYmd)}',
                style: const TextStyle(color: AppColors.helperText, fontSize: 12)),
          const SizedBox(height: 6),
          Text('베팅 포인트: ${AppNumberFormat.formatInt(flow.initialBetPoints)}P',
              style: const TextStyle(color: AppColors.helperText)),
          Text('최종 평가금액: ${AppNumberFormat.formatInt(finalValue)}P',
              style: const TextStyle(color: Colors.white)),
          Text('최종 수익률: ${finalReturn >= 0 ? '+' : ''}${finalReturn.toStringAsFixed(2)}%',
              style: const TextStyle(color: Colors.white)),
          if (isWindowsGuest)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('게스트 모드는 보상/기록 저장이 없어요',
                  style: TextStyle(color: AppColors.helperText, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(onPressed: onRetry, child: const Text('한판 더')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(onPressed: onClose, child: const Text('닫기')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
