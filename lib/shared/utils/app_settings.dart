import 'package:flutter/foundation.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<bool> chartMotionEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<DateTime?> speed8xUnlockedUntil = ValueNotifier<DateTime?>(null);

  static const String dataSource = '국내 주식/금/환율 로컬 데이터';
  static const String dataVersion = 'v1';

  static bool get is8xSpeedUnlocked {
    final DateTime? unlockUntil = speed8xUnlockedUntil.value;
    if (unlockUntil == null) return false;
    return DateTime.now().isBefore(unlockUntil);
  }

  static void unlock8xSpeedFor(Duration duration) {
    speed8xUnlockedUntil.value = DateTime.now().add(duration);
  }
}
