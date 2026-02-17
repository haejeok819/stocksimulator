import 'package:flutter/material.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';

class ChartPlaybackScreen extends StatefulWidget {
  const ChartPlaybackScreen({
    super.key,
    required this.prices,
    required this.flowState,
  });

  final List<double> prices;
  final SimulationFlowState flowState;

  @override
  State<ChartPlaybackScreen> createState() => _ChartPlaybackScreenState();
}

class _ChartPlaybackScreenState extends State<ChartPlaybackScreen> {
  bool _resultShown = false;

  void _showResult() {
    if (_resultShown) return;
    _resultShown = true;

    final double first = widget.prices[widget.flowState.startIndex];
    final double last = widget.prices[widget.flowState.endIndex];
    final double ratio = last / first;
    final int resultAmount = (widget.flowState.investment * ratio).round();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.flowState.selectedStock?.name ?? '차트'} 재생')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF24242D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: StockChartPlayer(
                    series: widget.prices,
                    onFinished: _showResult,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('최근 30거래일 슬라이딩 윈도우 차트'),
          ],
        ),
      ),
    );
  }
}
