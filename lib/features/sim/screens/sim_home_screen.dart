import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/date_range_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class SimHomeScreen extends StatelessWidget {
  const SimHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StockRepository repository = StockRepository();
    final SimulationFlowState flow = SimulationFlowState();
    final stocks = repository.getStocks();

    return Scaffold(
      appBar: AppBar(title: const Text('종목 선택')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext context, int index) {
          final stock = stocks[index];
          return ListTile(
            tileColor: const Color(0xFF2A2A33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(stock.name),
            subtitle: Text(stock.symbol),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              flow.selectStock(stock);
              Navigator.of(context).push(
                buildRightSlideRoute(
                  DateRangeScreen(repository: repository, flowState: flow),
                ),
              );
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: stocks.length,
      ),
    );
  }
}
