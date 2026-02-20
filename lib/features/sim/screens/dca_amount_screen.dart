import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/loading_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class DcaAmountScreen extends StatefulWidget {
  const DcaAmountScreen({
    super.key,
    required this.repository,
    required this.flowState,
    required this.eventCount,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;
  final int eventCount;

  @override
  State<DcaAmountScreen> createState() => _DcaAmountScreenState();
}

class _DcaAmountScreenState extends State<DcaAmountScreen> {
  static const List<int> _presets = <int>[10000, 30000, 50000, 100000, 300000, 500000, 1000000];

  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.flowState.dcaAmountPerTrade;
  }

  @override
  Widget build(BuildContext context) {
    final int total = _amount * widget.eventCount;

    return Scaffold(
      appBar: AppBar(title: const Text('회차당 투자금')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(AppNumberFormat.formatKoreanSpokenWon(_amount), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('선택한 주기마다 같은 금액으로 자동 매수돼요.', style: TextStyle(color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map(
                    (int amount) => ChoiceChip(
                      label: Text(AppNumberFormat.formatKoreanSpokenWon(amount)),
                      selected: _amount == amount,
                      onSelected: (_) => setState(() => _amount = amount),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _amount = (_amount - 10000).clamp(100, 100000000)),
                    child: const Text('- 만원'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _amount = (_amount + 10000).clamp(100, 100000000)),
                    child: const Text('+ 만원'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('회차 수: ${widget.eventCount}회'),
                    const SizedBox(height: 6),
                    Text('총 투자금: ${AppNumberFormat.formatKoreanSpokenWon(total)}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: widget.eventCount <= 0
                  ? null
                  : () {
                      widget.flowState.setDcaAmountPerTrade(_amount);
                      Navigator.of(context).push(
                        buildRightSlideRoute(
                          LoadingScreen(repository: widget.repository, flowState: widget.flowState),
                        ),
                      );
                    },
              child: const Text('시뮬레이션 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
