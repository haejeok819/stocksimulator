import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<DateTime?> showDateWheelPicker({
  required BuildContext context,
  required DateTime initialDate,
  required int minYear,
  required int maxYear,
  required String title,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (BuildContext context) {
      return _DateWheelPicker(
        initialDate: initialDate,
        minYear: minYear,
        maxYear: maxYear,
        title: title,
      );
    },
  );
}

class _DateWheelPicker extends StatefulWidget {
  const _DateWheelPicker({
    required this.initialDate,
    required this.minYear,
    required this.maxYear,
    required this.title,
  });

  final DateTime initialDate;
  final int minYear;
  final int maxYear;
  final String title;

  @override
  State<_DateWheelPicker> createState() => _DateWheelPickerState();
}

class _DateWheelPickerState extends State<_DateWheelPicker> {
  late int _year;
  late int _month;
  late int _day;

  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year.clamp(widget.minYear, widget.maxYear);
    _month = widget.initialDate.month;
    _day = widget.initialDate.day.clamp(1, _daysInMonth(_year, _month));

    _yearController = FixedExtentScrollController(initialItem: _year - widget.minYear);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int days = _daysInMonth(_year, _month);
    return SafeArea(
      child: SizedBox(
        height: 340,
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
                  Text(widget.title),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(DateTime(_year, _month, _day)),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _yearController,
                      itemExtent: 40,
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _year = widget.minYear + index;
                          _revalidateDay();
                        });
                      },
                      children: List<Widget>.generate(
                        widget.maxYear - widget.minYear + 1,
                        (int index) => Center(child: Text('${widget.minYear + index}년')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _monthController,
                      itemExtent: 40,
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _month = index + 1;
                          _revalidateDay();
                        });
                      },
                      children: List<Widget>.generate(
                        12,
                        (int index) => Center(child: Text('${index + 1}월')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      key: ValueKey<String>('$_year-$_month-$days'),
                      scrollController: _dayController,
                      itemExtent: 40,
                      onSelectedItemChanged: (int index) {
                        _day = index + 1;
                      },
                      children: List<Widget>.generate(
                        days,
                        (int index) => Center(child: Text('${index + 1}일')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _revalidateDay() {
    final int maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
    }
    _dayController.dispose();
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
