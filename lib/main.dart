import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_bootstrap.dart';
import 'package:stocksimulator/app/app.dart';
import 'package:stocksimulator/shared/config/ad_runtime_config.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/storage/ads_removed_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrapFirebase(); // 모바일만 Firebase init, Windows는 noop

  final bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  final bool adsRemoved = await AdsRemovedStorage.getAdsRemoved();
  final bool effectiveAdsRemoved = adsRemoved || AdRuntimeConfig.forceDisableAllAds;
  AdService.instance.setAdsRemoved(effectiveAdsRemoved);

  if (!effectiveAdsRemoved && isMobile) {
    await MobileAds.instance.initialize();
  }

  runApp(const ProviderScope(child: StockSimulatorApp()));
}
