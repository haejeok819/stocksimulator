import 'package:flutter/material.dart';
import 'package:stocksimulator/data/models/simulation_result.dart';
import 'package:stocksimulator/data/repositories/history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryRepository _repository = HistoryRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시뮬레이션 기록')),
      body: FutureBuilder<List<SimulationResult>>(
        future: _repository.load(),
        builder: (BuildContext context, AsyncSnapshot<List<SimulationResult>> snapshot) {
          final List<SimulationResult> items = snapshot.data ?? <SimulationResult>[];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (items.isEmpty) {
            return const Center(child: Text('기록이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final SimulationResult item = items[index];
              return ListTile(
                tileColor: const Color(0xFF2A2A33),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(item.ticker),
                subtitle: Text('${_fmt(item.startYmd)} ~ ${_fmt(item.endYmd)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('금액 ${item.amount}'),
                    Text('수익률 ${item.profitRate.toStringAsFixed(2)}%'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(int ymd) {
    final String s = ymd.toString();
    if (s.length != 8) {
      return s;
    }
    return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
  }
}
