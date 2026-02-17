import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';

class ChartPlaybackScreen extends StatefulWidget {
  const ChartPlaybackScreen({
    super.key,
    required this.points,
    required this.flowState,
  });

  final List<SimulationPoint> points;
  final SimulationFlowState flowState;

  @override
  State<ChartPlaybackScreen> createState() => _ChartPlaybackScreenState();
}

class _ChartPlaybackScreenState extends State<ChartPlaybackScreen> {
  Timer? _ticker;
  Timer? _skipTimer;
  bool _resultShown = false;
  bool _showSkip = false;

  int _index = 0;
  double _accumulated = 0;
  double _pulseTime = 0;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _skipTimer?.cancel();
    super.dispose();
  }

  double get _stepPerTick {
    final double years = widget.flowState.endDate.difference(widget.flowState.startDate).inDays / 365;
    if (years < 1) {
      return 0.016 / 0.2;
    }
    if (years < 5) {
      return 0.016 / 0.05;
    }
    return 0.016 / 0.01;
  }

  void _startPlayback() {
    if (widget.points.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
      return;
    }

    _skipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSkip = true;
        });
      }
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pulseTime += 0.16;
        _accumulated += _stepPerTick;
        final int step = _accumulated.floor();
        if (step > 0) {
          _accumulated -= step;
          _index = min(_index + step, widget.points.length - 1);
        }
      });

      if (_index >= widget.points.length - 1) {
        _ticker?.cancel();
        _showResult();
      }
    });
  }

  Future<void> _onSkipPressed() async {
    _ticker?.cancel();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'ad',
      pageBuilder: (_, __, ___) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text(
            '전면 광고',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
          ),
        );
      },
    );

    _showResult();
  }

  void _showResult() {
    if (_resultShown) {
      return;
    }
    _resultShown = true;

    if (widget.points.isEmpty) {
      return;
    }

    final int resultAmount = widget.points.last.value.round();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('시뮬레이션 결과'),
          content: Text(
            '투자금: ${widget.flowState.investment}원\n'
            '결과금: ${resultAmount}원',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).popUntil((Route<dynamic> route) => route.isFirst);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString();
    if (raw.length != 8) {
      return raw;
    }
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = widget.points.isNotEmpty;
    final SimulationPoint current = hasData
        ? widget.points[_index]
        : const SimulationPoint(ymd: 0, close: 0, value: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.flowState.selectedStock?.name ?? '차트'} 재생'),
        actions: <Widget>[
          if (_showSkip)
            TextButton(
              onPressed: _onSkipPressed,
              child: const Text('스킵'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _formatYmd(current.ymd),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${current.value.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '종가 ${current.close.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF24242D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: StockChartPlayer(
                    points: widget.points,
                    currentIndex: _index,
                    pulse: (sin(_pulseTime) + 1) / 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('최근 30거래일 슬라이딩 윈도우 차트'),
          ],
        ),
      ),
    );
  }
}
