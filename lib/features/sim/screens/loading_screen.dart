import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/chart_playback_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.repository,
    required this.flowState,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _prepareDataAndMove();
  }

  Future<void> _prepareDataAndMove() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final List<double> prices = widget.repository.getChartPrices();
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      buildRightSlideRoute(
        ChartPlaybackScreen(
          prices: prices,
          flowState: widget.flowState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(width: 44, height: 44, child: CircularProgressIndicator()),
            SizedBox(height: 18),
            Text('데이터 불러오는 중…'),
          ],
        ),
      ),
    );
  }
}
