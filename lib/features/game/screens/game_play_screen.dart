import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

enum _TradePhase { canBuy, canSell, done }

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({
    super.key,
    required this.betPoints,
    required this.isWindowsGuest,
    required this.stockName,
    required this.points,
  });

  final int betPoints;
  final bool isWindowsGuest;
  final String stockName;
  final List<PricePoint> points;

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _playbackPosition = 0;
  Duration? _last;
  int _index = 0;
  double _pulse = 0;
  double _speed = 1;
  _TradePhase _phase = _TradePhase.canBuy;
  int? _buyIndex;
  int? _sellIndex;
  bool _resultShown = false;

  List<SimulationPoint> get _simPoints => widget.points
      .map((PricePoint e) => SimulationPoint(ymd: e.ymd, close: e.close, value: e.close))
      .toList(growable: false);

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
    final Duration previous = _last ?? elapsed;
    _last = elapsed;
    final double dt = max(0, (elapsed - previous).inMicroseconds) / 1000000;
    if (dt <= 0 || _phase == _TradePhase.done) return;

    final int maxIndex = widget.points.length - 1;
    _playbackPosition = (_playbackPosition + (2.2 * _speed * dt)).clamp(0, maxIndex.toDouble());
    _index = _playbackPosition.floor();
    _pulse += dt * 4.4;
    if (mounted) setState(() {});

    if (_index >= maxIndex && _phase != _TradePhase.done) {
      _phase = _TradePhase.done;
      _sellIndex ??= _index;
      _showResult();
    }
  }

  void _buy() {
    if (_phase != _TradePhase.canBuy) return;
    setState(() {
      _buyIndex = _index;
      _phase = _TradePhase.canSell;
    });
  }

  void _sell() {
    if (_phase != _TradePhase.canSell) return;
    setState(() {
      _sellIndex = _index;
      _phase = _TradePhase.done;
    });
    _showResult();
  }

  Future<void> _showResult() async {
    if (_resultShown || _buyIndex == null || _sellIndex == null) return;
    _resultShown = true;
    final PricePoint buy = widget.points[_buyIndex!];
    final PricePoint sell = widget.points[_sellIndex!];
    final double tradeReturn = ((sell.close / buy.close) - 1) * 100;
    final int virtualPnl = (widget.betPoints * tradeReturn / 100).round();

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
              Text(widget.stockName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              const Text('기간: 1년', style: TextStyle(color: AppColors.helperText)),
              const SizedBox(height: 6),
              Text('베팅 포인트: ${AppNumberFormat.formatInt(widget.betPoints)}P', style: const TextStyle(color: AppColors.helperText)),
              Text('수익률: ${tradeReturn >= 0 ? '+' : ''}${tradeReturn.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.white)),
              Text('결과: ${virtualPnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(virtualPnl)}P', style: const TextStyle(color: Colors.white)),
              if (widget.isWindowsGuest)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('게스트 모드는 결과가 저장되지 않아요', style: TextStyle(color: AppColors.helperText, fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    String status = '매수 타이밍을 잡아봐';
    if (_phase == _TradePhase.canSell) status = '이제 매도 타이밍이야';
    if (_phase == _TradePhase.done) status = '결과 계산 중…';

    return Scaffold(
      appBar: AppBar(title: Text(widget.stockName)),
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StockChartPlayer(
                points: _simPoints,
                currentIndex: _index,
                playbackPosition: _playbackPosition,
                pulse: 0.5 + sin(_pulse) * 0.5,
                buyIndex: _buyIndex,
                sellIndex: _sellIndex,
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
                  child: ElevatedButton(onPressed: _phase == _TradePhase.canBuy ? _buy : null, child: const Text('BUY')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: _phase == _TradePhase.canSell ? _sell : null, child: const Text('SELL')),
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
