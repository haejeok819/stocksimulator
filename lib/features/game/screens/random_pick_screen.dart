import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/screens/game_play_screen.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';

class RandomPickScreen extends ConsumerStatefulWidget {
  const RandomPickScreen({super.key});

  @override
  ConsumerState<RandomPickScreen> createState() => _RandomPickScreenState();
}

class _RandomPickScreenState extends ConsumerState<RandomPickScreen> {
  final Random _random = Random();
  String _rollingText = '선택 중...';
  int _countdown = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runFlow();
  }

  Future<void> _runFlow() async {
    try {
      await ref.read(chartGameFlowControllerProvider.notifier).startGame();
      final String finalText = ref.read(chartGameFlowControllerProvider).assetName ?? '선택됨';
      await _rollingAnimation(finalText);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _countdown = 3;
      });

      while (_countdown > 0 && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 850));
        if (!mounted) return;
        setState(() => _countdown -= 1);
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'game_play'),
          builder: (_) => const GamePlayScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '랜덤 선택에 실패했어요';
        _loading = false;
      });
    }
  }

  Future<void> _rollingAnimation(String finalText) async {
    final List<String> candidates = <String>['삼성전자', 'SK하이닉스', '금(KRX)', 'USD/KRW', 'NAVER', '현대차'];
    const int frameCount = 16;
    for (int i = 0; i < frameCount; i++) {
      await Future<void>.delayed(Duration(milliseconds: 45 + i * 12));
      if (!mounted) return;
      setState(() => _rollingText = candidates[_random.nextInt(candidates.length)]);
    }
    if (!mounted) return;
    setState(() => _rollingText = finalText);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final ChartGameFlowState flow = ref.watch(chartGameFlowControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('랜덤 선택 중…', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        _rollingText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      flow.assetName == null ? '종목을 고르고 있어요' : '오늘의 종목: ${flow.assetName}',
                      style: const TextStyle(color: AppColors.helperText),
                    ),
                    const SizedBox(height: 4),
                    const Text('기간: 1년', style: TextStyle(color: AppColors.helperText)),
                    const SizedBox(height: 20),
                    if (_loading)
                      const CircularProgressIndicator()
                    else if (_countdown > 0)
                      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
      ),
    );
  }
}
