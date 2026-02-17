import 'package:flutter/foundation.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<bool> chartMotionEnabled = ValueNotifier<bool>(true);

  static const String dataSource = 'Local static yearly gzip files';
  static const String dataVersion = 'v1';
}
