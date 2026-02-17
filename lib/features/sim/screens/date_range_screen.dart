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
  static const int _totalDays = 3650;
  static const int _minRangeDays = 30;

  late final DateTime _baseDate;
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now().subtract(const Duration(days: _totalDays - 1));
    final int startIndex = widget.flowState.startDate.difference(_baseDate).inDays.clamp(0, _totalDays - 1);
    final int endIndex = widget.flowState.endDate.difference(_baseDate).inDays.clamp(0, _totalDays - 1);
    _values = RangeValues(startIndex.toDouble(), endIndex.toDouble());
  }

  DateTime _dateForIndex(int index) => _baseDate.add(Duration(days: index));

  String _labelForDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  RangeValues _applyMinRange(RangeValues incoming) {
    double start = incoming.start.roundToDouble();
    double end = incoming.end.roundToDouble();

    if (end - start < _minRangeDays) {
      if (start != _values.start) {
        end = (start + _minRangeDays).clamp(0, (_totalDays - 1).toDouble());
      } else {
        start = (end - _minRangeDays).clamp(0, (_totalDays - 1).toDouble());
      }
    }

    return RangeValues(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final int startIndex = _values.start.toInt();
    final int endIndex = _values.end.toInt();
    final DateTime startDate = _dateForIndex(startIndex);
    final DateTime endDate = _dateForIndex(endIndex);

    return Scaffold(
      appBar: AppBar(title: const Text('날짜 선택')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('백테스트 기간을 선택하세요 (최소 30거래일).'),
              const SizedBox(height: 20),
              Text('시작 날짜: ${_labelForDate(startDate)}'),
              const SizedBox(height: 6),
              Text('종료 날짜: ${_labelForDate(endDate)}'),
              const SizedBox(height: 8),
              Text('선택 구간: ${endIndex - startIndex + 1} 거래일'),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: RangeSlider(
                    values: _values,
                    min: 0,
                    max: (_totalDays - 1).toDouble(),
                    divisions: _totalDays - 1,
                    labels: RangeLabels(
                      _labelForDate(startDate),
                      _labelForDate(endDate),
                    ),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _values = _applyMinRange(values);
                      });
                    },
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.flowState.setDateRange(startDate, endDate);
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
