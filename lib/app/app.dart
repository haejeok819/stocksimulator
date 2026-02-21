import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/router/app_router.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/state/ads_removed_provider.dart';

class StockSimulatorApp extends ConsumerWidget {
  const StockSimulatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adsRemovedProvider);
    ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Stock Simulator',
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.main,
      debugShowCheckedModeBanner: false,
    );
  }
}
