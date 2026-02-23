class DateKey {
  DateKey._();

  static String kstYmd([DateTime? now]) {
    final DateTime utc = (now ?? DateTime.now()).toUtc();
    final DateTime kst = utc.add(const Duration(hours: 9));
    final String y = kst.year.toString().padLeft(4, '0');
    final String m = kst.month.toString().padLeft(2, '0');
    final String d = kst.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
