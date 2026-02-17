import 'package:flutter/material.dart';

class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScreen(title: '인기 종목');
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
