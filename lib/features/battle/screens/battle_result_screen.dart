import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BattleResultScreen extends ConsumerWidget {
  const BattleResultScreen({super.key});

  String _fmt(double value) => AppNumberFormat.formatInt(value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);
    final BattleResultState? result = ref.watch(battleResultProvider);

    if (result == null) {
      return const Scaffold(body: Center(child: Text('결과가 없습니다.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Battle Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: <Widget>[
                  Text('🏆 ${result.winner} 승리', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _resultRow('A', _koreanName(setup.stockA), result.finalValueA, result.finalReturnA),
                  const SizedBox(height: 8),
                  _resultRow('B', _koreanName(setup.stockB), result.finalValueB, result.finalReturnB),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(battleDataProvider);
                Navigator.of(context).pop();
              },
              child: const Text('다시하기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
              child: const Text('설정으로'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록 저장은 추후 연동 예정입니다.')));
              },
              child: const Text('기록 저장'),
            ),
          ],
        ),
      ),
    );
  }

  String _koreanName(StockModel? stock) {
    if (stock == null) return '-';
    if (stock.nameKo.trim().isNotEmpty) return stock.nameKo.trim();
    return stock.displayName;
  }

  Widget _resultRow(String label, String ticker, double finalValue, double finalRate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('$label · $ticker'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('${_fmt(finalValue)}원'),
            Text('수익률 ${AppNumberFormat.formatPercent(finalRate)}'),
          ],
        ),
      ],
    );
  }
}
