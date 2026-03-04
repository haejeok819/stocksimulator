import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';

int toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

DateTime fromYmd(int ymd) {
  final int year = ymd ~/ 10000;
  final int month = (ymd % 10000) ~/ 100;
  final int day = ymd % 100;
  return DateTime(year, month, day);
}

int _weeklyAnchorKey(int ymd) {
  final int year = ymd ~/ 10000;
  final int month = (ymd % 10000) ~/ 100;
  final int day = ymd % 100;
  final DateTime date = DateTime(year, month, day);
  final DateTime monday = date.subtract(Duration(days: date.weekday - 1));
  return toYmd(monday);
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
  final List<int> inRange = tradingDaysSorted
      .where((int ymd) => ymd >= startYmd && ymd <= endYmd)
      .toList(growable: false);
  if (inRange.isEmpty) return <int>[];

  if (interval == DcaInterval.tradingDaily) {
    return inRange;
  }

  final Set<int> seenBuckets = <int>{};
  final List<int> events = <int>[];
  for (final int ymd in inRange) {
    final int bucketKey =
        interval == DcaInterval.monthly ? (ymd ~/ 100) : _weeklyAnchorKey(ymd);
    if (seenBuckets.add(bucketKey)) {
      events.add(ymd);
    }
  }
  return events;
}
