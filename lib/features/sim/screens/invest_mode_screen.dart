import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/investment_input_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/utils/dca_schedule.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class InvestModeScreen extends StatefulWidget {
  const InvestModeScreen({super.key, required this.repository, required this.flowState});

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  State<InvestModeScreen> createState() => _InvestModeScreenState();
}

class _InvestModeScreenState extends State<InvestModeScreen> {
  List<int> _tradingDays = <int>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTradingDays();
  }

  Future<void> _loadTradingDays() async {
    final List<int> days = await widget.repository.loadTradingDaysYmd(
      market: widget.flowState.marketCode,
      ticker: widget.flowState.selectedStock?.ticker ?? '',
    );
    if (!mounted) return;
    setState(() {
      _tradingDays = days;
      _loading = false;
    });
  }

  int get _eventCount {
    if (widget.flowState.investMode == InvestMode.lumpSum) return _tradingDays.isEmpty ? 0 : 1;
    return buildDcaEventYmds(
      tradingDaysSorted: _tradingDays,
      start: widget.flowState.startDate,
      end: widget.flowState.endDate,
      interval: widget.flowState.dcaInterval,
    ).length;
  }

  String _intervalLabel(DcaInterval interval) {
    return switch (interval) {
      DcaInterval.monthly => '월',
      DcaInterval.weekly => '주',
      DcaInterval.tradingDaily => '매일(거래일)',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('투자 방식')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('투자 방식 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<InvestMode>(
              segments: const <ButtonSegment<InvestMode>>[
                ButtonSegment<InvestMode>(value: InvestMode.lumpSum, label: Text('거치식')),
                ButtonSegment<InvestMode>(value: InvestMode.dca, label: Text('적립식')),
              ],
              selected: <InvestMode>{widget.flowState.investMode},
              onSelectionChanged: (Set<InvestMode> value) {
                setState(() => widget.flowState.setInvestMode(value.first));
              },
            ),
            const SizedBox(height: 12),
            if (widget.flowState.investMode == InvestMode.dca) ...<Widget>[
              const Text('적립 주기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SegmentedButton<DcaInterval>(
                segments: const <ButtonSegment<DcaInterval>>[
                  ButtonSegment<DcaInterval>(value: DcaInterval.monthly, label: Text('월')),
                  ButtonSegment<DcaInterval>(value: DcaInterval.weekly, label: Text('주')),
                  ButtonSegment<DcaInterval>(value: DcaInterval.tradingDaily, label: Text('매일(거래일)')),
                ],
                selected: <DcaInterval>{widget.flowState.dcaInterval},
                onSelectionChanged: (Set<DcaInterval> value) {
                  setState(() => widget.flowState.setDcaInterval(value.first));
                },
              ),
              const SizedBox(height: 8),
              const Text('월은 매월 첫 거래일 보정 / 주·매일도 거래일 기준', style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12)),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${widget.flowState.selectedStock?.displayName ?? '-'} (${widget.flowState.selectedStock?.ticker ?? '-'})'),
                    const SizedBox(height: 6),
                    Text('${toYmd(widget.flowState.startDate)} ~ ${toYmd(widget.flowState.endDate)}'),
                    const SizedBox(height: 6),
                    Text(
                      widget.flowState.investMode == InvestMode.lumpSum
                          ? '방식: 거치식'
                          : '방식: 적립식 (${_intervalLabel(widget.flowState.dcaInterval)})',
                    ),
                    const SizedBox(height: 6),
                    Text('예상 회차 수: $_eventCount회'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  buildRightSlideRoute(
                    InvestmentInputScreen(repository: widget.repository, flowState: widget.flowState),
                  ),
                );
              },
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}
