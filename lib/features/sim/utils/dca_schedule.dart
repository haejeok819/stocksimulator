import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';

int toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

DateTime fromYmd(int ymd) {
  final int year = ymd ~/ 10000;
  final int month = (ymd % 10000) ~/ 100;
  final int day = ymd % 100;
  return DateTime(year, month, day);
}

List<int> buildDcaEventYmds({
  required List<int> tradingDaysSorted,
  required DateTime start,
  required DateTime end,
  required DcaInterval interval,
}) {
  if (tradingDaysSorted.isEmpty) return <int>[];

  final int startYmd = toYmd(start);
  final int endYmd = toYmd(end);
  final List<int> inRange = tradingDaysSorted.where((int ymd) => ymd >= startYmd && ymd <= endYmd).toList(growable: false);
  if (inRange.isEmpty) return <int>[];

  if (interval == DcaInterval.tradingDaily) {
    return inRange;
  }

  final Map<String, int> grouped = <String, int>{};
  for (final int ymd in inRange) {
    final DateTime day = fromYmd(ymd);
    final String key;
    if (interval == DcaInterval.monthly) {
      key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
    } else {
      final DateTime weekAnchor = day.subtract(Duration(days: day.weekday - 1));
      key = '${weekAnchor.year}-${weekAnchor.month.toString().padLeft(2, '0')}-${weekAnchor.day.toString().padLeft(2, '0')}';
    }
    grouped.putIfAbsent(key, () => ymd);
  }

  final List<int> events = grouped.values.toList()..sort();
  return events;
}
