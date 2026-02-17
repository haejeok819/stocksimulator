import 'package:flutter/material.dart';
import 'package:stocksimulator/features/history/history_screen.dart';
import 'package:stocksimulator/features/battle/screens/battle_screen.dart';
import 'package:stocksimulator/features/settings/settings_screen.dart';
import 'package:stocksimulator/features/sim/screens/sim_home_screen.dart';
import 'package:stocksimulator/shared/widgets/main_scaffold.dart';

class AppRouter {
  static const String main = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(builder: (_) => const MainScaffold());
  }
}

final List<Widget> mainTabs = <Widget>[
  const SimHomeScreen(),
  const BattleScreen(),
  const HistoryScreen(),
  const SettingsScreen(),
];
