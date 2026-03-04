import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/date_range_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/error_message.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class PopularScreen extends StatefulWidget {
  const PopularScreen({super.key});

  @override
  State<PopularScreen> createState() => _PopularScreenState();
}

class _PopularScreenState extends State<PopularScreen> {
  final StockRepository _repository = StockRepository();
  StockMarket _market = StockMarket.kr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('인기 Top100')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.action,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('KR', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<StockModel>>(
                future: _repository.getTopStocks(market: _market),
                builder: (BuildContext context, AsyncSnapshot<List<StockModel>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        toUserMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final List<StockModel> stocks = snapshot.data ?? <StockModel>[];
                  if (stocks.isEmpty) {
                    return const Center(child: Text('표시할 종목이 없습니다.'));
                  }

                  return ListView.separated(
                    itemCount: stocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final StockModel stock = stocks[index];
                      return Card(
                        child: ListTile(
                          leading: Text(
                            '${stock.rank}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          title: Text(stock.displayName),
                          subtitle: Text(
                            '${stock.ticker} · ${stock.market}',
                            style: const TextStyle(color: AppColors.helperText),
                          ),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: () {
                            final SimulationFlowState flow = SimulationFlowState();
                            flow.selectStock(stock);
                            Navigator.of(context).push(
                              buildRightSlideRoute(
                                DateRangeScreen(repository: _repository, flowState: flow),
                              ),
                            );
                          },
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
