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
    try {
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('시뮬레이션 실패'),
            content: Text(error.toString()),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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
