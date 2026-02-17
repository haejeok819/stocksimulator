import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/investment_input_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/date_wheel_picker.dart';
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

class _DateRangeScreenState extends State<DateRangeScreen> {
  static const int _minTradingDays = 30;

  bool _loading = true;
  String? _error;
  List<int> _tradingDaysYmd = <int>[];
  Set<int> _tradingDaySet = <int>{};
  late DateTime _startDate;
  late DateTime _endDate;
  int _minYear = 2005;
  int _maxYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _startDate = widget.flowState.startDate;
    _endDate = widget.flowState.endDate;
    _loadTradingDays();
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
    final DateTime? selected = await showDateWheelPicker(
      context: context,
      initialDate: initial,
      minYear: _minYear,
      maxYear: _maxYear,
      title: isStart ? '시작일 선택' : '종료일 선택',
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
    final int ymd = _toYmd(date);
    return '${_formatYmd(ymd)} (${weekdays[date.weekday - 1]})';
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
      appBar: AppBar(title: const Text('날짜 선택')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text('거래일 기준으로 기간을 선택하세요 (최소 30거래일).'),
                        const SizedBox(height: 16),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          tileColor: Theme.of(context).colorScheme.surfaceVariant,
                          title: const Text('시작일'),
                          subtitle: Text(_formatDate(_startDate)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickDate(isStart: true),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          tileColor: Theme.of(context).colorScheme.surfaceVariant,
                          title: const Text('종료일'),
                          subtitle: Text(_formatDate(_endDate)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickDate(isStart: false),
                        ),
                        const SizedBox(height: 12),
                        Text('선택 구간: $selectedDays 거래일'),
                        Text('연도 범위: $_minYear ~ $_maxYear'),
                        Text(
                          '데이터 범위: ${_formatYmd(_tradingDaysYmd.first)} ~ ${_formatYmd(_tradingDaysYmd.last)}',
                        ),
                        const Spacer(),
                        ElevatedButton(
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
                          child: const Text('다음'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
