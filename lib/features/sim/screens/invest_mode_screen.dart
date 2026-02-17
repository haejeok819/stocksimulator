import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool get _isSafeMode {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };
  }

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
      DcaInterval.tradingDaily => '매일',
    };
  }

  String _formatDate(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}.$mm.$dd';
  }

  void _selectMode(InvestMode mode) {
    if (!_isSafeMode) {
      HapticFeedback.selectionClick();
    }
    setState(() => widget.flowState.setInvestMode(mode));
  }

  void _selectInterval(DcaInterval interval) {
    if (!_isSafeMode) {
      HapticFeedback.selectionClick();
    }
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
                    safeMode: _isSafeMode,
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
                    safeMode: _isSafeMode,
                    onTap: () => _selectMode(InvestMode.dca),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: _isSafeMode ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: isDca
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20202A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x22FFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('적립 주기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _IntervalPillSelector(
                              selected: widget.flowState.dcaInterval,
                              safeMode: _isSafeMode,
                              onChanged: _selectInterval,
                            ),
                            const SizedBox(height: 9),
                            const Row(
                              children: <Widget>[
                                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFA1A1A8)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '월은 매월 첫 거래일로 자동 보정됩니다.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFA1A1A8), height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              stockName: widget.flowState.selectedStock?.displayName ?? '-',
              ticker: widget.flowState.selectedStock?.ticker ?? '-',
              period: '${_formatDate(widget.flowState.startDate)} ~ ${_formatDate(widget.flowState.endDate)}',
              modePillText: isDca ? '적립식 · ${_intervalLabel(widget.flowState.dcaInterval)}' : '거치식',
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
    required this.safeMode,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool safeMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: safeMode ? Duration.zero : const Duration(milliseconds: 180),
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
        boxShadow: selected && !safeMode
            ? <BoxShadow>[BoxShadow(color: const Color(0xAA5865EA).withOpacity(0.28), blurRadius: 16, spreadRadius: 1)]
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
                    duration: safeMode ? Duration.zero : const Duration(milliseconds: 140),
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

class _IntervalPillSelector extends StatelessWidget {
  const _IntervalPillSelector({
    required this.selected,
    required this.safeMode,
    required this.onChanged,
  });

  final DcaInterval selected;
  final bool safeMode;
  final ValueChanged<DcaInterval> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<DcaInterval> options = <DcaInterval>[
      DcaInterval.monthly,
      DcaInterval.weekly,
      DcaInterval.tradingDaily,
    ];
    final int selectedIndex = options.indexOf(selected).clamp(0, options.length - 1);

    String labelOf(DcaInterval interval) {
      return switch (interval) {
        DcaInterval.monthly => '월',
        DcaInterval.weekly => '주',
        DcaInterval.tradingDaily => '매일',
      };
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemWidth = constraints.maxWidth / options.length;

          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: safeMode ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: itemWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6A8BFF), Color(0xFF4969D9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: safeMode
                          ? const <BoxShadow>[]
                          : <BoxShadow>[BoxShadow(color: const Color(0xCC4E6EE0).withOpacity(0.28), blurRadius: 12)],
                    ),
                  ),
                ),
              ),
              Row(
                children: options.map((DcaInterval interval) {
                  final bool isSelected = interval == selected;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onChanged(interval),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (isSelected) ...<Widget>[
                              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            AnimatedDefaultTextStyle(
                              duration: safeMode ? Duration.zero : const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFB5B5BE),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              ),
                              child: Text(labelOf(interval)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stockName,
    required this.ticker,
    required this.period,
    required this.modePillText,
    required this.eventCount,
    required this.emphasizeCount,
  });

  final String stockName;
  final String ticker;
  final String period;
  final String modePillText;
  final int eventCount;
  final bool emphasizeCount;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: <Widget>[
              const Text('요약', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x334F74E6),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x555678E7)),
                ),
                child: Text(modePillText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDCE5FF))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 10),
          _SummaryRow(
            label: '종목',
            valueWidget: Text.rich(
              TextSpan(
                text: stockName,
                style: const TextStyle(fontSize: 14, color: Color(0xFFE6FFFFFF), fontWeight: FontWeight.w700),
                children: <InlineSpan>[
                  TextSpan(text: ' ($ticker)', style: const TextStyle(color: Color(0xFFB5B5BE), fontWeight: FontWeight.w500)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: '기간',
            valueWidget: const SizedBox.shrink(),
            valueText: period,
          ),
          const SizedBox(height: 10),
          if (emphasizeCount) ...<Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
              decoration: BoxDecoration(
                color: const Color(0x172A6BDE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x335678E7)),
              ),
              child: Row(
                children: <Widget>[
                  const Text('예상 회차 수', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
                  const Spacer(),
                  Text('$eventCount회', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFE9F0FF))),
                ],
              ),
            ),
          ] else ...<Widget>[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('총 1회 투자', style: TextStyle(fontSize: 12, color: Color(0xFF7E7E87))),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.valueWidget,
    this.valueText,
  });

  final String label;
  final Widget valueWidget;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 56, child: Text(label, style: const TextStyle(color: Color(0xFFA1A1A8), fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(
          child: valueText != null
              ? Text(
                  valueText!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE6FFFFFF)),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : valueWidget,
        ),
      ],
    );
  }
}
