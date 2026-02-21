import 'package:shared_preferences/shared_preferences.dart';

class AdsRemovedStorage {
  AdsRemovedStorage._();

  static const String _adsRemovedKey = 'ads_removed';

  static Future<bool> getAdsRemoved() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adsRemovedKey) ?? false;
  }

  static Future<void> setAdsRemoved(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, value);
  }
}
