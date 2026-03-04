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
  double _entryPulse = 0;
  String? _executionLabel;
  bool _showExecutionOverlay = false;
  double? _latestBuyReferencePrice;

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
    _playbackPosition = (_playbackPosition + (4.4 * dt)).clamp(0, maxIndex.toDouble());
    _index = _playbackPosition.floor();
    _pulse += dt * 4.4;
    _entryPulse = min(1, _entryPulse + (dt * 1.8));

    ref.read(chartGameFlowControllerProvider.notifier).updateCurrentIndex(_index);
    if (mounted) {
      final ChartGameFlowState updatedFlow = ref.read(chartGameFlowControllerProvider);
      final int next = _computeSellRemaining(updatedFlow);
      setState(() {
        _sellRemainingSec = next;
        _latestBuyReferencePrice = updatedFlow.entryPrice;
      });
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
    if (_showExecutionOverlay) return;
    _showTradeExecution('매수 체결', () {
      final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);
      if (flow.segment.isEmpty) {
        return;
      }
      final int liveIndex = flow.currentIndex.clamp(0, flow.segment.length - 1);
      final double executedBuyPrice = flow.segment[liveIndex].close;
      ref.read(chartGameFlowControllerProvider.notifier).onBuy(liveIndex);
      final int next = _computeSellRemaining(ref.read(chartGameFlowControllerProvider));
      setState(() {
        _sellRemainingSec = next;
        _latestBuyReferencePrice = executedBuyPrice;
      });
    });
  }

  void _sell() {
    final ChartGameFlowState flow = ref.read(chartGameFlowControllerProvider);
    if (!_canSell(flow) || _showExecutionOverlay) return;
    _showTradeExecution('매도 체결', () {
      final int liveIndex = ref.read(chartGameFlowControllerProvider).currentIndex;
      ref.read(chartGameFlowControllerProvider.notifier).onSell(liveIndex);
      setState(() {
        _sellRemainingSec = 0;
        _latestBuyReferencePrice = null;
      });
    });
  }

  Future<void> _showTradeExecution(String label, VoidCallback action) async {
    setState(() {
      _executionLabel = label;
      _showExecutionOverlay = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    action();
    setState(() => _showExecutionOverlay = false);
  }

  Color _pnlColor(double pnl) {
    if (pnl > 0) return AppColors.upSegment;
    if (pnl < 0) return AppColors.downSegment;
    return AppColors.helperText;
  }

  double? _buyReferencePrice(ChartGameFlowState flow) {
    if (!flow.hasPosition || flow.positionUnits <= 0) return null;
    return _latestBuyReferencePrice ?? flow.entryPrice;
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
      if (isMobile && !isWindowsGuest) {
        final int deltaPoints = flow.settlementDeltaPoints ?? 0;
        if (deltaPoints != 0) {
          try {
            await ref
                .read(gamePointControllerProvider.notifier)
                .earnGameResult(deltaPoints);
          } catch (_) {}
        }
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
    final bool buyEnabled = !flow.isFinished && !flow.hasPosition && flow.cashPoints > 0;
    final bool sellEnabled = _canSell(flow);
    final Color pnlColor = _pnlColor(pnl);
    final double entryPulseWeight = Curves.easeOut.transform((_entryPulse / 0.55).clamp(0, 1));
    final String status = flow.isFinished
        ? '게임 종료'
        : (flow.hasPosition ? '존버해야하나?' : '매수 드갈까?');

    return Scaffold(
      appBar: AppBar(title: Text(flow.assetName ?? '차트 게임')),
      backgroundColor: AppColors.background,
      body: points.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: <Widget>[
                Column(
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
                                  const Text(
                                    '현재 평가금액',
                                    style: TextStyle(
                                      color: AppColors.helperText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppNumberFormat.formatInt(flow.equityPoints)}P',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 29,
                                    height: 1.0),
                              ),
                              const SizedBox(height: 6),
                              TweenAnimationBuilder<double>(
                                key: ValueKey<String>(
                                  '${pnl.toStringAsFixed(0)}_${returnPercent.toStringAsFixed(2)}',
                                ),
                                tween: Tween<double>(begin: 1, end: 1.05),
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                builder: (BuildContext context, double value, Widget? child) {
                                  final double downScale = value > 1 ? 2 - value : 1;
                                  return Transform.scale(
                                    scale: downScale,
                                    alignment: Alignment.centerLeft,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  '손익 ${pnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(pnl)}P (${returnPercent >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%)',
                                  style: TextStyle(
                                    color: pnlColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  height: 8,
                                  child: LayoutBuilder(
                                    builder: (BuildContext context, BoxConstraints constraints) {
                                      final double ratio = progress.clamp(0, 1);
                                      return Stack(
                                        children: <Widget>[
                                          Container(color: AppColors.helperText.withOpacity(0.14)),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            curve: Curves.easeOut,
                                            width: constraints.maxWidth * ratio,
                                            decoration: BoxDecoration(
                                              color: ratio >= 0.5
                                                  ? AppColors.action.withOpacity(0.96)
                                                  : AppColors.action.withOpacity(0.84),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
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
                          pulse: (0.5 + sin(_pulse) * 0.5) * (0.55 + entryPulseWeight * 0.45),
                          referencePrice: _buyReferencePrice(flow),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: AppColors.helperText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ActionDecisionButton(
                              text: '매수',
                              enabled: buyEnabled,
                              onPressed: _buy,
                              backgroundColor: buyEnabled ? AppColors.upSegment : AppColors.surface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ActionDecisionButton(
                              text: _sellRemainingSec > 0 ? '매도 (${_sellRemainingSec})' : '매도',
                              enabled: sellEnabled,
                              onPressed: _sell,
                              backgroundColor:
                                  sellEnabled ? AppColors.downSegment : AppColors.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: !_showExecutionOverlay,
                  child: AnimatedOpacity(
                    opacity: _showExecutionOverlay ? 0.8 : 0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
                        _executionLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ActionDecisionButton extends StatefulWidget {
  const ActionDecisionButton({
    super.key,
    required this.text,
    required this.enabled,
    required this.onPressed,
    required this.backgroundColor,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;
  final Color backgroundColor;

  @override
  State<ActionDecisionButton> createState() => _ActionDecisionButtonState();
}

class _ActionDecisionButtonState extends State<ActionDecisionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed && widget.enabled ? 0.97 : 1,
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: widget.enabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: widget.backgroundColor,
              disabledBackgroundColor: AppColors.surface,
              disabledForegroundColor: AppColors.helperText.withOpacity(0.42),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child:
                Text(widget.text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
