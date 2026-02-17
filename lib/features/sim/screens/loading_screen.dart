import 'package:flutter/material.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
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
    final List<PricePoint> prices = await widget.repository.loadRange(
      market: widget.flowState.marketCode,
      ticker: widget.flowState.selectedStock?.ticker ?? '',
      start: widget.flowState.startDate,
      end: widget.flowState.endDate,
    );
    final List<SimulationPoint> series = widget.repository.toSimulationSeries(
      prices: prices,
      investment: widget.flowState.investment,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      buildRightSlideRoute(
        ChartPlaybackScreen(
          points: series,
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
