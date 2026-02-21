import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/storage/ads_removed_storage.dart';

final AsyncNotifierProvider<AdsRemovedNotifier, bool> adsRemovedProvider =
    AsyncNotifierProvider<AdsRemovedNotifier, bool>(AdsRemovedNotifier.new);

class AdsRemovedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final bool adsRemoved = await AdsRemovedStorage.getAdsRemoved();
    AdService.instance.setAdsRemoved(adsRemoved);
    return adsRemoved;
  }

  Future<void> setAdsRemoved(bool value) async {
    state = AsyncData<bool>(value);
    AdService.instance.setAdsRemoved(value);
    await AdsRemovedStorage.setAdsRemoved(value);
  }
}
