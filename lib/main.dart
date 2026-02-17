import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/app.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }
  runApp(const ProviderScope(child: StockSimulatorApp()));
}
