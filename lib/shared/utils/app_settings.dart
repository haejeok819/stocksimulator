import 'package:flutter/foundation.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<bool> chartMotionEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<DateTime?> speed8xUnlockedUntil = ValueNotifier<DateTime?>(null);

  static const String dataSource = '공공데이터포탈\nhttps://www.data.go.kr/';
  static const String dataVersion = 'v2';

  static bool get is8xSpeedUnlocked {
    final DateTime? unlockUntil = speed8xUnlockedUntil.value;
    if (unlockUntil == null) return false;
    return DateTime.now().isBefore(unlockUntil);
  }

  static void unlock8xSpeedFor(Duration duration) {
    speed8xUnlockedUntil.value = DateTime.now().add(duration);
  }
}
