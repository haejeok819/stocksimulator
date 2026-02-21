import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/app/app.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/storage/ads_removed_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool adsRemoved = await AdsRemovedStorage.getAdsRemoved();
  AdService.instance.setAdsRemoved(adsRemoved);

  if (!adsRemoved && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  runApp(const ProviderScope(child: StockSimulatorApp()));
}
