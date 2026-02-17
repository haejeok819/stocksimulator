import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/features/battle/screens/battle_result_screen.dart';
import 'package:stocksimulator/features/battle/state/battle_playback_controller.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/features/battle/widgets/battle_chart.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class BattlePlaybackScreen extends ConsumerStatefulWidget {
  const BattlePlaybackScreen({super.key});

  @override
  ConsumerState<BattlePlaybackScreen> createState() => _BattlePlaybackScreenState();
}

class _BattlePlaybackScreenState extends ConsumerState<BattlePlaybackScreen> {
  bool _navigated = false;

  bool get _isMobileRuntime {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(battlePlaybackControllerProvider.notifier).start());
  }

  void _moveToResult(BattleSeriesData data, BattlePlaybackState playback) {
    if (_navigated) return;
    _navigated = true;

    final BattleTick tick = data.tickAt(playback.index);
    final BattleResultState result = BattleResultState(
      finalValueA: tick.valueA,
      finalValueB: tick.valueB,
      finalReturnA: tick.returnA,
      finalReturnB: tick.returnB,
      winner: tick.valueA >= tick.valueB ? 'A' : 'B',
    );
    ref.read(battleResultProvider.notifier).state = result;

    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const BattleResultScreen()));
  }

  Future<void> _onSkip(BattleSeriesData data) async {
    ref.read(battlePlaybackControllerProvider.notifier).pause();
    final bool allowAds = _isMobileRuntime && !ref.read(battleSetupProvider).safeMode;

    if (allowAds) {
      try {
        final InterstitialAd? ad = await AdHelper.loadInterstitial();
        if (ad != null) {
          final Completer<void> completer = Completer<void>();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              completer.complete();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              completer.complete();
            },
          );
          ad.show();
          await completer.future;
        }
      } catch (_) {}
    }

    ref.read(battlePlaybackControllerProvider.notifier).skipToEnd();
    _moveToResult(data, ref.read(battlePlaybackControllerProvider));
  }

  String _fmt(double value) => NumberFormat('#,###').format(value.round());

  @override
  Widget build(BuildContext context) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);
    final AsyncValue<BattleSeriesData> dataAsync = ref.watch(battleDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Battle Playback')),
      body: dataAsync.when(
        data: (BattleSeriesData data) {
          final BattlePlaybackState playback = ref.watch(battlePlaybackControllerProvider);
          final BattleTick tick = data.tickAt(playback.index);

          if (playback.status == BattlePlaybackStatus.ended) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _moveToResult(data, playback));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                if (playback.showCountdown)
                  Text('${playback.countdown}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                Row(
                  children: <Widget>[
                    Expanded(child: _statusCard('A', setup.stockA!, tick.valueA, tick.returnA, tick.valueA >= tick.valueB, safeMode: setup.safeMode)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusCard('B', setup.stockB!, tick.valueB, tick.returnB, tick.valueB > tick.valueA, safeMode: setup.safeMode)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: IgnorePointer(
                    ignoring: setup.safeMode,
                    child: RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFF24242D), borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.all(10),
                        child: BattleChart(seriesA: data.valuesA, seriesB: data.valuesB, playbackIndex: playback.index),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('날짜: ${tick.ymd}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: playback.status == BattlePlaybackStatus.running
                          ? () => ref.read(battlePlaybackControllerProvider.notifier).pause()
                          : () => ref.read(battlePlaybackControllerProvider.notifier).resume(),
                      child: Text(playback.status == BattlePlaybackStatus.running ? '일시정지' : '재개'),
                    ),
                    OutlinedButton(onPressed: () => _onSkip(data), child: const Text('스킵 → 결과')),
                    SegmentedButton<double>(
                      segments: const <ButtonSegment<double>>[
                        ButtonSegment<double>(value: 1, label: Text('1x')),
                        ButtonSegment<double>(value: 2, label: Text('2x')),
                        ButtonSegment<double>(value: 3, label: Text('3x')),
                      ],
                      selected: <double>{playback.speed},
                      onSelectionChanged: (Set<double> value) => ref.read(battlePlaybackControllerProvider.notifier).setSpeed(value.first),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _statusCard(String label, StockModel stock, double value, double rate, bool leading, {required bool safeMode}) {
    final Widget content = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: leading ? const Color(0x3322C55E) : const Color(0xFF2A2A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: leading ? const Color(0xFF22C55E) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$label · ${stock.ticker}'),
          Text('${_fmt(value)}원', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${rate.toStringAsFixed(2)}%'),
        ],
      ),
    );

    if (safeMode) {
      return content;
    }

    return AnimatedScale(
      scale: leading ? 1.03 : 1,
      duration: const Duration(milliseconds: 200),
      child: content,
    );
  }
}
