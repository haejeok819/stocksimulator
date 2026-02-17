import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/battle/screens/battle_playback_screen.dart';
import 'package:stocksimulator/features/battle/state/battle_playback_controller.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';

class BattleSetupScreen extends ConsumerWidget {
  const BattleSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('대결')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _StockTile(label: '종목 A 선택', stock: setup.stockA, onPick: (StockModel stock) => ref.read(battleSetupProvider.notifier).setStockA(stock)),
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircleAvatar(radius: 18, child: Text('VS')),
            ),
            _StockTile(label: '종목 B 선택', stock: setup.stockB, onPick: (StockModel stock) => ref.read(battleSetupProvider.notifier).setStockB(stock)),
            const SizedBox(height: 14),
            _DateRangeSelector(setup: setup),
            const SizedBox(height: 14),
            _InvestmentSelector(setup: setup),
            SwitchListTile(
              title: const Text('Desktop/Web 안전모드'),
              value: setup.safeMode,
              onChanged: (bool enabled) => ref.read(battleSetupProvider.notifier).setSafeMode(enabled),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final StockRepository repository = ref.read(battleStockRepositoryProvider);
                      final List<StockModel> usStocks = await repository.getTopStocks(market: StockMarket.us);
                      final List<StockModel> krStocks = await repository.getTopStocks(market: StockMarket.kr);
                      final List<StockModel> stocks = <StockModel>[...usStocks, ...krStocks];
                      if (stocks.length < 2) return;
                      final Random random = Random();
                      final StockModel a = stocks[random.nextInt(stocks.length)];
                      StockModel b = stocks[random.nextInt(stocks.length)];
                      while (a.ticker == b.ticker) {
                        b = stocks[random.nextInt(stocks.length)];
                      }
                      ref.read(battleSetupProvider.notifier).setStockA(a);
                      ref.read(battleSetupProvider.notifier).setStockB(b);
                    },
                    child: const Text('랜덤 매칭'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (setup.stockA == null || setup.stockB == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('종목 A/B를 선택하세요.')));
                        return;
                      }
                      if (setup.stockA!.ticker == setup.stockB!.ticker) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('동일 종목은 선택할 수 없습니다.')));
                        return;
                      }
                      ref.invalidate(battleDataProvider);
                      ref.read(battlePlaybackControllerProvider.notifier).reset();
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const BattlePlaybackScreen()),
                      );
                    },
                    child: const Text('Start Battle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeSelector extends ConsumerWidget {
  const _DateRangeSelector({required this.setup});

  final BattleSetupState setup;

  String _formatYmd(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime base = DateTime.now().subtract(const Duration(days: 3649));
    final double startIndex = setup.startDate.difference(base).inDays.clamp(0, 3649).toDouble();
    final double endIndex = setup.endDate.difference(base).inDays.clamp(0, 3649).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${_formatYmd(setup.startDate)} ~ ${_formatYmd(setup.endDate)}'),
            RangeSlider(
              min: 0,
              max: 3649,
              values: RangeValues(startIndex, endIndex),
              onChanged: (RangeValues value) {
                final DateTime start = base.add(Duration(days: value.start.round()));
                final DateTime end = base.add(Duration(days: value.end.round()));
                ref.read(battleSetupProvider.notifier).setDateRange(start, end);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentSelector extends ConsumerWidget {
  const _InvestmentSelector({required this.setup});

  final BattleSetupState setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: const Text('투자금'),
        subtitle: Text('${NumberFormat('#,###').format(setup.investAmount)}원'),
        trailing: SizedBox(
          width: 180,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount - 10000).clamp(100, 100000000)),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                onPressed: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount + 10000).clamp(100, 100000000)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockTile extends ConsumerStatefulWidget {
  const _StockTile({required this.label, required this.stock, required this.onPick});

  final String label;
  final StockModel? stock;
  final ValueChanged<StockModel> onPick;

  @override
  ConsumerState<_StockTile> createState() => _StockTileState();
}

class _StockTileState extends ConsumerState<_StockTile> {
  Future<void> _pickStock() async {
    final TextEditingController controller = TextEditingController();
    String query = '';
    StockMarket selectedMarket = widget.stock?.market == 'KR' ? StockMarket.kr : StockMarket.us;

    final StockModel? stock = await showModalBottomSheet<StockModel>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                height: 520,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SegmentedButton<StockMarket>(
                        segments: const <ButtonSegment<StockMarket>>[
                          ButtonSegment<StockMarket>(value: StockMarket.us, label: Text('US')),
                          ButtonSegment<StockMarket>(value: StockMarket.kr, label: Text('KR')),
                        ],
                        selected: <StockMarket>{selectedMarket},
                        onSelectionChanged: (Set<StockMarket> value) {
                          setState(() {
                            selectedMarket = value.first;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        onChanged: (String value) {
                          setState(() {
                            query = value;
                          });
                        },
                        decoration: const InputDecoration(hintText: '종목 검색'),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<StockModel>>(
                        future: ref.read(battleStockRepositoryProvider).getTopStocks(market: selectedMarket, query: query),
                        builder: (BuildContext context, AsyncSnapshot<List<StockModel>> snapshot) {
                          final List<StockModel> stocks = snapshot.data ?? <StockModel>[];
                          return ListView.builder(
                            itemCount: stocks.length,
                            itemBuilder: (BuildContext context, int index) {
                              final StockModel stock = stocks[index];
                              return ListTile(
                                title: Text(stock.displayName),
                                subtitle: Text('${stock.ticker} · ${stock.market}'),
                                onTap: () => Navigator.of(context).pop(stock),
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
          },
        );
      },
    );

    if (stock != null) {
      widget.onPick(stock);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.label),
        subtitle: Text(widget.stock == null ? '미선택' : '${widget.stock!.displayName} (${widget.stock!.ticker})'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickStock,
      ),
    );
  }
}
