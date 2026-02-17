import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/investment_input_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class DateRangeScreen extends StatefulWidget {
  const DateRangeScreen({
    super.key,
    required this.repository,
    required this.flowState,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  State<DateRangeScreen> createState() => _DateRangeScreenState();
}

class _DateRangeScreenState extends State<DateRangeScreen> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = RangeValues(
      widget.flowState.startIndex.toDouble(),
      widget.flowState.endIndex.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('날짜 선택')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('백테스트 기간을 선택하세요.'),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: RangeSlider(
                  values: _values,
                  min: 0,
                  max: 89,
                  divisions: 89,
                  labels: RangeLabels(
                    _values.start.toInt().toString(),
                    _values.end.toInt().toString(),
                  ),
                  onChanged: (RangeValues values) {
                    setState(() {
                      _values = values;
                    });
                  },
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.flowState
                    .setRange(_values.start.toInt(), _values.end.toInt());
                Navigator.of(context).push(
                  buildRightSlideRoute(
                    InvestmentInputScreen(
                      repository: widget.repository,
                      flowState: widget.flowState,
                    ),
                  ),
                );
              },
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}
