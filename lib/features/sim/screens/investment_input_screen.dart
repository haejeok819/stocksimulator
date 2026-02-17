import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/loading_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class InvestmentInputScreen extends StatefulWidget {
  const InvestmentInputScreen({
    super.key,
    required this.repository,
    required this.flowState,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  State<InvestmentInputScreen> createState() => _InvestmentInputScreenState();
}

class _InvestmentInputScreenState extends State<InvestmentInputScreen> {
  late String _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.flowState.investment.toString();
  }

  int get _amountValue => int.tryParse(_amount) ?? 0;

  void _append(String value) {
    setState(() {
      if (_amount == '0') {
        _amount = value;
      } else {
        _amount += value;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1);
      }
    });
  }

  String _formatWon(int value) {
    final String raw = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final int fromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${buffer.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    const List<String> keys = <String>[
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '00', '0', '←',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('투자금 입력')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('초기 투자금을 입력하세요.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF24242D),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formatWon(_amountValue),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: keys.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final String key = keys[index];
                  return ElevatedButton(
                    onPressed: () {
                      if (key == '←') {
                        _backspace();
                      } else {
                        _append(key);
                      }
                    },
                    child: Text(key, style: Theme.of(context).textTheme.titleLarge),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _amountValue > 0
                  ? () {
                      widget.flowState.setInvestment(_amountValue);
                      Navigator.of(context).push(
                        buildRightSlideRoute(
                          LoadingScreen(
                            repository: widget.repository,
                            flowState: widget.flowState,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('재생 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
