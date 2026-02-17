import 'package:flutter/material.dart';
import 'package:stocksimulator/app/router/app_router.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';

class StockSimulatorApp extends StatelessWidget {
  const StockSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Simulator',
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.main,
      debugShowCheckedModeBanner: false,
    );
  }
}
