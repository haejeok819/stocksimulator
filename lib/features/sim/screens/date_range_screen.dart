import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/investment_input_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/date_card.dart';
import 'package:stocksimulator/features/sim/widgets/date_picker_modal.dart';
import 'package:stocksimulator/features/sim/widgets/date_range_header.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class DateRangeScreen extends StatefulWidget {
  const DateRangeScreen({
    super.key,
    required this.repository,
    required this.flowState,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  State<DateRangeScreen> createState() => _DateRangeScreenState();
}

class _DateRangeScreenState extends State<DateRangeScreen> with SingleTickerProviderStateMixin {
  static const int _minTradingDays = 30;

  bool _loading = true;
  String? _error;
  List<int> _tradingDaysYmd = <int>[];
  Set<int> _tradingDaySet = <int>{};
  late DateTime _startDate;
  late DateTime _endDate;
  int _minYear = 2005;
  int _maxYear = DateTime.now().year;
  late final AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _startDate = widget.flowState.startDate;
    _endDate = widget.flowState.endDate;
    _arrowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _loadTradingDays();
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  Future<void> _loadTradingDays() async {
    final String ticker = widget.flowState.selectedStock?.ticker ?? '';
    if (ticker.isEmpty) {
      setState(() {
        _loading = false;
        _error = '종목이 선택되지 않았습니다.';
      });
      return;
    }

    try {
      final List<int> days = await widget.repository.loadTradingDaysYmd(
        market: widget.flowState.marketCode,
        ticker: ticker,
      );
      if (!mounted) {
        return;
      }
      if (days.isEmpty) {
        setState(() {
          _loading = false;
          _error = '거래일 데이터를 찾을 수 없습니다.';
        });
        return;
      }

      final Set<int> daySet = days.toSet();
      final int firstYear = days.first ~/ 10000;
      final int lastYear = days.last ~/ 10000;
      final bool has2005 = days.any((int ymd) => (ymd ~/ 10000) == 2005);

      DateTime start = _adjustToTradingDayOrFirst(widget.flowState.startDate, daySet, days.first);
      DateTime end = _adjustToTradingDayOrFirst(widget.flowState.endDate, daySet, days.first);
      if (start.isAfter(end)) {
        start = end;
      }

      setState(() {
        _tradingDaysYmd = days;
        _tradingDaySet = daySet;
        _minYear = has2005 ? 2005 : firstYear;
        _maxYear = lastYear;
        _startDate = start;
        _endDate = end;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    if (_tradingDaysYmd.isEmpty) {
      return;
    }

    final DateTime initial = isStart ? _startDate : _endDate;
    final DateTime? selected = await showDatePickerModal(
      context: context,
      initialDate: initial,
      minYear: _minYear,
      maxYear: _maxYear,
      title: isStart ? '매수 시점' : '매도 시점',
    );
    if (selected == null) {
      return;
    }

    final DateTime adjusted = _adjustToTradingDayOrFirst(selected, _tradingDaySet, _tradingDaysYmd.first);

    setState(() {
      if (isStart) {
        _startDate = adjusted;
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = adjusted;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
  }

  DateTime _adjustToTradingDayOrFirst(DateTime selected, Set<int> tradingSet, int firstYmd) {
    DateTime cursor = DateTime(selected.year, selected.month, selected.day);
    final DateTime lowerBound = _fromYmd(firstYmd);

    while (cursor.isAfter(lowerBound) || cursor.isAtSameMomentAs(lowerBound)) {
      if (tradingSet.contains(_toYmd(cursor))) {
        return cursor;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return lowerBound;
  }

  int _selectedTradingDaysCount() {
    if (_tradingDaysYmd.isEmpty) {
      return 0;
    }
    final int startYmd = _toYmd(_startDate);
    final int endYmd = _toYmd(_endDate);
    return _tradingDaysYmd.where((int ymd) => ymd >= startYmd && ymd <= endYmd).length;
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatDate(DateTime date) {
    const List<String> weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
    return '${_formatYmd(_toYmd(date))} (${weekdays[date.weekday - 1]})';
  }

  DateTime _fromYmd(int ymd) {
    final int year = ymd ~/ 10000;
    final int month = (ymd % 10000) ~/ 100;
    final int day = ymd % 100;
    return DateTime(year, month, day);
  }

  int _toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  @override
  Widget build(BuildContext context) {
    final int selectedDays = _selectedTradingDaysCount();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('투자 기간 선택'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: 18),
                        DateRangeHeader(
                          start: _formatYmd(_toYmd(_startDate)),
                          end: _formatYmd(_toYmd(_endDate)),
                          tradingDayCount: selectedDays,
                          animation: CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
                        ),
                        const SizedBox(height: 26),
                        DateCard(label: '매수 시점', value: _formatDate(_startDate), onTap: () => _pickDate(isStart: true)),
                        const SizedBox(height: 12),
                        DateCard(label: '매도 시점', value: _formatDate(_endDate), onTap: () => _pickDate(isStart: false)),
                        const Spacer(),
                        const Text(
                          '데이터 보유 기간',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatYmd(_tradingDaysYmd.first)} ~ ${_formatYmd(_tradingDaysYmd.last)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5677E7)),
                          onPressed: selectedDays < _minTradingDays
                              ? null
                              : () {
                                  widget.flowState.setDateRange(_startDate, _endDate);
                                  Navigator.of(context).push(
                                    buildRightSlideRoute(
                                      InvestmentInputScreen(
                                        repository: widget.repository,
                                        flowState: widget.flowState,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('다음', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
