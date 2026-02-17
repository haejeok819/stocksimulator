import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/investment_input_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
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
  int _startIndex = 0;
  int _endIndex = 0;

  @override
  void initState() {
    super.initState();
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

      int start = _findFirstOnOrAfter(days, _toYmd(widget.flowState.startDate));
      int end = _findLastOnOrBefore(days, _toYmd(widget.flowState.endDate));
      if (start > end) {
        start = 0;
        end = days.length - 1;
      }

      final ({int start, int end}) normalized = _normalizeRange(
        start: start,
        end: end,
        changedStart: false,
        total: days.length,
      );

      setState(() {
        _tradingDaysYmd = days;
        _startIndex = normalized.start;
        _endIndex = normalized.end;
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

  int _findFirstOnOrAfter(List<int> days, int targetYmd) {
    for (int i = 0; i < days.length; i++) {
      if (days[i] >= targetYmd) {
        return i;
      }
    }
    return days.length - 1;
  }

  int _findLastOnOrBefore(List<int> days, int targetYmd) {
    for (int i = days.length - 1; i >= 0; i--) {
      if (days[i] <= targetYmd) {
        return i;
      }
    }
    return 0;
  }

  ({int start, int end}) _normalizeRange({
    required int start,
    required int end,
    required bool changedStart,
    required int total,
  }) {
    int normalizedStart = start.clamp(0, total - 1);
    int normalizedEnd = end.clamp(0, total - 1);

    if (normalizedStart > normalizedEnd) {
      if (changedStart) {
        normalizedEnd = normalizedStart;
      } else {
        normalizedStart = normalizedEnd;
      }
    }

    final int minGap = _minTradingDays - 1;
    if (normalizedEnd - normalizedStart < minGap && total >= _minTradingDays) {
      if (changedStart) {
        normalizedEnd = (normalizedStart + minGap).clamp(0, total - 1);
        if (normalizedEnd - normalizedStart < minGap) {
          normalizedStart = (normalizedEnd - minGap).clamp(0, total - 1);
        }
      } else {
        normalizedStart = (normalizedEnd - minGap).clamp(0, total - 1);
        if (normalizedEnd - normalizedStart < minGap) {
          normalizedEnd = (normalizedStart + minGap).clamp(0, total - 1);
        }
      }
    }

    return (start: normalizedStart, end: normalizedEnd);
  }

  Future<void> _pickDate({required bool isStart}) async {
    if (_tradingDaysYmd.isEmpty) {
      return;
    }

    final int initialIndex = isStart ? _startIndex : _endIndex;
    int tempIndex = initialIndex;
    final FixedExtentScrollController controller = FixedExtentScrollController(initialItem: initialIndex);

    final int? pickedIndex = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      Text(isStart ? '시작일 선택' : '종료일 선택'),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(tempIndex),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 40,
                    onSelectedItemChanged: (int value) {
                      tempIndex = value;
                    },
                    children: _tradingDaysYmd
                        .map((int ymd) => Center(child: Text(_formatYmdWithWeekday(ymd))))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedIndex == null) {
      return;
    }

    setState(() {
      final int nextStart = isStart ? pickedIndex : _startIndex;
      final int nextEnd = isStart ? _endIndex : pickedIndex;
      final ({int start, int end}) normalized = _normalizeRange(
        start: nextStart,
        end: nextEnd,
        changedStart: isStart,
        total: _tradingDaysYmd.length,
      );
      _startIndex = normalized.start;
      _endIndex = normalized.end;
    });
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatYmdWithWeekday(int ymd) {
    final DateTime date = _fromYmd(ymd);
    const List<String> weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
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
    final bool hasDays = _tradingDaysYmd.isNotEmpty;
    final int selectedDays = hasDays ? (_endIndex - _startIndex + 1) : 0;

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
                          subtitle: Text(_formatYmdWithWeekday(_tradingDaysYmd[_startIndex])),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickDate(isStart: true),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          tileColor: Theme.of(context).colorScheme.surfaceVariant,
                          title: const Text('종료일'),
                          subtitle: Text(_formatYmdWithWeekday(_tradingDaysYmd[_endIndex])),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickDate(isStart: false),
                        ),
                        const SizedBox(height: 12),
                        Text('선택 구간: $selectedDays 거래일'),
                        Text(
                          '데이터 범위: ${_formatYmd(_tradingDaysYmd.first)} ~ ${_formatYmd(_tradingDaysYmd.last)}',
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: selectedDays < _minTradingDays
                              ? null
                              : () {
                                  widget.flowState.setDateRange(
                                    _fromYmd(_tradingDaysYmd[_startIndex]),
                                    _fromYmd(_tradingDaysYmd[_endIndex]),
                                  );
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
