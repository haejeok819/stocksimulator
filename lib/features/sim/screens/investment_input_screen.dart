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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.flowState.investment.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('투자금 입력')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('초기 투자금을 입력하세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '예) 1000000',
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                widget.flowState.setInvestment(int.tryParse(_controller.text) ?? 0);
                Navigator.of(context).push(
                  buildRightSlideRoute(
                    LoadingScreen(
                      repository: widget.repository,
                      flowState: widget.flowState,
                    ),
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
