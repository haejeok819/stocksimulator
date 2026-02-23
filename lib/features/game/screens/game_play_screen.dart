import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key});

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _playbackPosition = 0;
  Duration? _last;
  int _index = 0;
  double _pulse = 0;
  double _speed = 1;
  bool _resultShown = false;

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
    if (flow.segment.isEmpty || flow.phase == ChartGamePhase.done) return;

    final Duration previous = _last ?? elapsed;
    _last = elapsed;
    final double dt = max(0, (elapsed - previous).inMicroseconds) / 1000000;
    if (dt <= 0) return;

    final int maxIndex = flow.segment.length - 1;
    _playbackPosition = (_playbackPosition + (2.2 * _speed * dt)).clamp(0, maxIndex.toDouble());
    _index = _playbackPosition.floor();
    _pulse += dt * 4.4;
    if (mounted) setState(() {});

    if (_index >= maxIndex && flow.phase != ChartGamePhase.done) {
      ref.read(chartGameFlowControllerProvider.notifier).onSell(_index);
      _showResult();
    }
  }

  void _buy() {
    ref.read(chartGameFlowControllerProvider.notifier).onBuy(_index);
    setState(() {});
  }

  void _sell() {
    ref.read(chartGameFlowControllerProvider.notifier).onSell(_index);
    setState(() {});
    _showResult();
  }

  Future<void> _showResult() async {
    if (_resultShown) return;
    final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);
    final ChartGameResult? result = flow.result;
    if (result == null) return;
    _resultShown = true;

    final bool isWindowsGuest = _isWindowsGuest();
    final int virtualPnl = (flow.betPoints * result.returnPercent / 100).round();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(flow.assetName ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              const Text('기간: 1년', style: TextStyle(color: AppColors.helperText)),
              const SizedBox(height: 6),
              Text('베팅 포인트: ${AppNumberFormat.formatInt(flow.betPoints)}P', style: const TextStyle(color: AppColors.helperText)),
              Text('매수일: ${_formatYmd(result.buyDate)}', style: const TextStyle(color: AppColors.helperText)),
              Text('매도일: ${_formatYmd(result.sellDate)}', style: const TextStyle(color: AppColors.helperText)),
              Text('수익률: ${result.returnPercent >= 0 ? '+' : ''}${result.returnPercent.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.white)),
              Text('결과: ${virtualPnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(virtualPnl)}P', style: const TextStyle(color: Colors.white)),
              if (isWindowsGuest)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('게스트 모드는 보상/기록 저장이 없어요', style: TextStyle(color: AppColors.helperText, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).popUntil((Route<dynamic> route) => route.settings.name == 'game_bet');
                      },
                      child: const Text('한판 더'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).popUntil((Route<dynamic> route) => route.settings.name == null);
                      },
                      child: const Text('닫기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isWindowsGuest() {
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final bool isLoggedIn = (ref.read(authControllerProvider).user?.uid ?? '').isNotEmpty;
    return isWindows && !isLoggedIn;
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final ChartGameFlowState flow = ref.watch(chartGameFlowControllerProvider);
    final List<SimulationPoint> points = flow.segment
        .map((e) => SimulationPoint(ymd: e.ymd, close: e.close, value: e.close))
        .toList(growable: false);

    String status = '매수 타이밍을 잡아봐';
    if (flow.phase == ChartGamePhase.canSell) status = '이제 매도 타이밍이야';
    if (flow.phase == ChartGamePhase.done) status = '결과 계산 중…';

    return Scaffold(
      appBar: AppBar(title: Text(flow.assetName ?? '차트 게임')),
      backgroundColor: AppColors.background,
      body: points.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: StockChartPlayer(
                      points: points,
                      currentIndex: _index,
                      playbackPosition: _playbackPosition,
                      pulse: 0.5 + sin(_pulse) * 0.5,
                      buyIndex: flow.buyIndex,
                      sellIndex: flow.sellIndex,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(status, style: const TextStyle(color: AppColors.helperText)),
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
                          onPressed: flow.phase == ChartGamePhase.canBuy ? _buy : null,
                          child: const Text('BUY'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: flow.phase == ChartGamePhase.canSell ? _sell : null,
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
