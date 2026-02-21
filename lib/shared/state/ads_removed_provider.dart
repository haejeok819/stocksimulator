import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';
import 'package:stocksimulator/shared/storage/ads_removed_storage.dart';

final AsyncNotifierProvider<AdsRemovedNotifier, bool> adsRemovedProvider =
    AsyncNotifierProvider<AdsRemovedNotifier, bool>(AdsRemovedNotifier.new);

class AdsRemovedNotifier extends AsyncNotifier<bool> {
  static const Duration _autoUnlockDuration = Duration(days: 36500);

  @override
  Future<bool> build() async {
    final bool adsRemoved = await AdsRemovedStorage.getAdsRemoved();
    AdService.instance.setAdsRemoved(adsRemoved);
    if (adsRemoved) {
      AppSettings.unlock8xSpeedFor(_autoUnlockDuration);
    }
    return adsRemoved;
  }

  Future<void> setAdsRemoved(bool value) async {
    state = AsyncData<bool>(value);
    AdService.instance.setAdsRemoved(value);
    if (value) {
      AppSettings.unlock8xSpeedFor(_autoUnlockDuration);
    }
    await AdsRemovedStorage.setAdsRemoved(value);
  }
}
