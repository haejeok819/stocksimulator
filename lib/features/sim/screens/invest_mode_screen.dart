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

class _InvestModeScreenState extends State<InvestModeScreen> with TickerProviderStateMixin {
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

  void _selectMode(InvestMode mode) {
    setState(() => widget.flowState.setInvestMode(mode));
  }

  void _selectInterval(DcaInterval interval) {
    setState(() => widget.flowState.setDcaInterval(interval));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDca = widget.flowState.investMode == InvestMode.dca;

    return Scaffold(
      appBar: AppBar(title: const Text('투자 방식')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('투자 전략 선택', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('방식에 따라 재생 흐름과 결과 요약이 달라집니다.', style: TextStyle(fontSize: 13, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ModeSelectCard(
                    title: '거치식',
                    subtitle: '처음 한 번 투자',
                    icon: Icons.bolt_rounded,
                    selected: !isDca,
                    onTap: () => _selectMode(InvestMode.lumpSum),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeSelectCard(
                    title: '적립식',
                    subtitle: '주기적으로 분할 투자',
                    icon: Icons.auto_graph_rounded,
                    selected: isDca,
                    onTap: () => _selectMode(InvestMode.dca),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: isDca
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22222B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x333A3A48)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('적립 주기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            SegmentedButton<DcaInterval>(
                              segments: const <ButtonSegment<DcaInterval>>[
                                ButtonSegment<DcaInterval>(value: DcaInterval.monthly, label: Text('월')),
                                ButtonSegment<DcaInterval>(value: DcaInterval.weekly, label: Text('주')),
                                ButtonSegment<DcaInterval>(value: DcaInterval.tradingDaily, label: Text('매일(거래일)')),
                              ],
                              selected: <DcaInterval>{widget.flowState.dcaInterval},
                              onSelectionChanged: (Set<DcaInterval> value) => _selectInterval(value.first),
                            ),
                            const SizedBox(height: 8),
                            const Text('월은 매월 첫 거래일로 자동 보정됩니다.', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              stock: '${widget.flowState.selectedStock?.displayName ?? '-'} (${widget.flowState.selectedStock?.ticker ?? '-'})',
              period: '${toYmd(widget.flowState.startDate)} ~ ${toYmd(widget.flowState.endDate)}',
              mode: isDca ? '적립식 (${_intervalLabel(widget.flowState.dcaInterval)})' : '거치식',
              eventCount: _eventCount,
              emphasizeCount: isDca,
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

class _ModeSelectCard extends StatelessWidget {
  const _ModeSelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? const LinearGradient(
                colors: <Color>[Color(0xFF2B2E42), Color(0xFF202335)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: <Color>[Color(0xFF23232B), Color(0xFF1D1D25)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: selected ? const Color(0xFF6F7AE8) : const Color(0x333A3A48), width: selected ? 1.4 : 1),
        boxShadow: selected
            ? <BoxShadow>[BoxShadow(color: const Color(0xAA5865EA).withOpacity(0.32), blurRadius: 18, spreadRadius: 1)]
            : <BoxShadow>[],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: selected ? const Color(0xFFB8C2FF) : const Color(0xFFA1A1A8)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF8EA1FF)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stock,
    required this.period,
    required this.mode,
    required this.eventCount,
    required this.emphasizeCount,
  });

  final String stock;
  final String period;
  final String mode;
  final int eventCount;
  final bool emphasizeCount;

  @override
  Widget build(BuildContext context) {
    final Color countColor = emphasizeCount ? const Color(0xFF9AD3FF) : const Color(0xFF7E7E87);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF23232C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x333A3A48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('요약', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFA1A1A8))),
          const SizedBox(height: 8),
          _SummaryRow(label: '종목', value: stock),
          _SummaryRow(label: '기간', value: period),
          _SummaryRow(label: '방식', value: mode),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: emphasizeCount ? 1 : 0.62,
            duration: const Duration(milliseconds: 180),
            child: _SummaryRow(
              label: '예상 회차 수',
              value: '${eventCount}회',
              valueColor: countColor,
              valueWeight: emphasizeCount ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: Color(0xFFA1A1A8), fontSize: 13))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: valueWeight ?? FontWeight.w600, color: valueColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
