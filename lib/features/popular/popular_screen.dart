import 'package:flutter/material.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/date_range_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class PopularScreen extends StatefulWidget {
  const PopularScreen({super.key});

  @override
  State<PopularScreen> createState() => _PopularScreenState();
}

class _PopularScreenState extends State<PopularScreen> {
  final StockRepository _repository = StockRepository();
  StockMarket _market = StockMarket.us;

  @override
  Widget build(BuildContext context) {
    final List<StockModel> stocks = _repository.getTopStocks(market: _market);

    return Scaffold(
      appBar: AppBar(title: const Text('인기 Top100')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SegmentedButton<StockMarket>(
              segments: const <ButtonSegment<StockMarket>>[
                ButtonSegment<StockMarket>(value: StockMarket.us, label: Text('US')),
                ButtonSegment<StockMarket>(value: StockMarket.kr, label: Text('KR')),
              ],
              selected: <StockMarket>{_market},
              onSelectionChanged: (Set<StockMarket> value) {
                setState(() {
                  _market = value.first;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: stocks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final StockModel stock = stocks[index];
                  return ListTile(
                    tileColor: const Color(0xFF2A2A33),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Text('${stock.rank}'),
                    title: Text(stock.name),
                    subtitle: Text(stock.symbol),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () {
                      final SimulationFlowState flow = SimulationFlowState();
                      flow.selectStock(stock);
                      Navigator.of(context).push(
                        buildRightSlideRoute(
                          DateRangeScreen(repository: _repository, flowState: flow),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
