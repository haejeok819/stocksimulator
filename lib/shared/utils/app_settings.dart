import 'package:flutter/foundation.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<bool> chartMotionEnabled = ValueNotifier<bool>(true);

  static const String dataSource = '국내 주식/금/환율 로컬 데이터';
  static const String dataVersion = 'v1';
}
