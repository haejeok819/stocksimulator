import 'package:flutter/material.dart';
import 'package:stocksimulator/app/router/app_router.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: mainTabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.show_chart), label: '시뮬'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: '인기'),
          NavigationDestination(icon: Icon(Icons.history), label: '기록'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
