import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<DateTime?> showDatePickerModal({
  required BuildContext context,
  required DateTime initialDate,
  required int minYear,
  required int maxYear,
  required String title,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: const Color(0xFF2A2A32),
    builder: (BuildContext context) {
      return _DatePickerModal(
        initialDate: initialDate,
        minYear: minYear,
        maxYear: maxYear,
        title: title,
      );
    },
  );
}

class _DatePickerModal extends StatefulWidget {
  const _DatePickerModal({
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
  State<_DatePickerModal> createState() => _DatePickerModalState();
}

class _DatePickerModalState extends State<_DatePickerModal> {
  late int _year;
  late int _month;
  late int _day;
  bool _visible = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
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
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: SafeArea(
        child: SizedBox(
          height: 350,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
                    Text(widget.title, style: const TextStyle(color: Colors.white)),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(DateTime(_year, _month, _day));
                      },
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: <Widget>[
                    _buildPicker(
                      controller: _yearController,
                      count: widget.maxYear - widget.minYear + 1,
                      onChanged: (int i) => setState(() {
                        _year = widget.minYear + i;
                        _revalidateDay();
                      }),
                      labelBuilder: (int i) => '${widget.minYear + i}',
                    ),
                    _buildPicker(
                      controller: _monthController,
                      count: 12,
                      onChanged: (int i) => setState(() {
                        _month = i + 1;
                        _revalidateDay();
                      }),
                      labelBuilder: (int i) => '${i + 1}',
                    ),
                    _buildPicker(
                      key: ValueKey<String>('$_year-$_month-$days'),
                      controller: _dayController,
                      count: days,
                      onChanged: (int i) => _day = i + 1,
                      labelBuilder: (int i) => '${i + 1}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicker({
    Key? key,
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
    required String Function(int) labelBuilder,
  }) {
    return Expanded(
      child: CupertinoPicker(
        key: key,
        scrollController: controller,
        itemExtent: 44,
        useMagnifier: true,
        magnification: 1.05,
        diameterRatio: 1.4,
        onSelectedItemChanged: onChanged,
        children: List<Widget>.generate(
          count,
          (int i) => Center(
            child: Text(
              labelBuilder(i),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
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

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
}
