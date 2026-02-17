import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('시뮬레이션 기록', style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
