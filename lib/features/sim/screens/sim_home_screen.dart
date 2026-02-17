import 'package:flutter/material.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/date_range_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class SimHomeScreen extends StatefulWidget {
  const SimHomeScreen({super.key});

  @override
  State<SimHomeScreen> createState() => _SimHomeScreenState();
}

class _SimHomeScreenState extends State<SimHomeScreen> {
  final StockRepository _repository = StockRepository();
  final SimulationFlowState _flow = SimulationFlowState();
  final TextEditingController _searchController = TextEditingController();

  StockMarket _market = StockMarket.kr;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<StockModel> stocks = _repository.getTopStocks(
      market: _market,
      query: _query,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('종목 선택')),
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
            TextField(
              controller: _searchController,
              onChanged: (String value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: const InputDecoration(
                hintText: '종목명/심볼 검색',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Text('Top100', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemBuilder: (BuildContext context, int index) {
                  final StockModel stock = stocks[index];
                  return ListTile(
                    tileColor: const Color(0xFF2A2A33),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Text(
                      '${stock.rank}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    title: Text(stock.name),
                    subtitle: Text(stock.symbol),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _flow.selectStock(stock);
                      Navigator.of(context).push(
                        buildRightSlideRoute(
                          DateRangeScreen(
                            repository: _repository,
                            flowState: _flow,
                          ),
                        ),
                      );
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: stocks.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
