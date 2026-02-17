import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/app/theme/playback_design_tokens.dart';
import 'package:stocksimulator/data/models/simulation_point.dart';
import 'package:stocksimulator/data/models/simulation_result.dart';
import 'package:stocksimulator/data/repositories/history_repository.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/features/sim/widgets/stock_chart_player.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class ChartPlaybackScreen extends StatefulWidget {
  const ChartPlaybackScreen({
    super.key,
    required this.points,
    required this.flowState,
  });

  final List<SimulationPoint> points;
  final SimulationFlowState flowState;

  @override
  State<ChartPlaybackScreen> createState() => _ChartPlaybackScreenState();
}

class _ChartPlaybackScreenState extends State<ChartPlaybackScreen> {
  final HistoryRepository _historyRepository = HistoryRepository();

  Timer? _ticker;
  Timer? _skipTimer;
  bool _resultShown = false;
  bool _showSkip = false;

  int _index = 0;
  double _accumulated = 0;
  double _pulseTime = 0;
  bool _playing = true;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    AdService.instance.preloadInterstitial();
    _startPlayback();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _skipTimer?.cancel();
    super.dispose();
  }

  double get _stepPerTick {
    final double years = widget.flowState.endDate.difference(widget.flowState.startDate).inDays / 365;
    if (years < 1) return 0.016 / 0.2;
    if (years < 5) return 0.016 / 0.05;
    return 0.016 / 0.01;
  }

  void _startPlayback() {
    if (widget.points.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
      return;
    }

    _skipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSkip = true);
      }
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_playing) return;

      setState(() {
        _pulseTime += 0.16;
        if (AppSettings.chartMotionEnabled.value) {
          _accumulated += (_stepPerTick * _speed);
          final int step = _accumulated.floor();
          if (step > 0) {
            _accumulated -= step;
            _index = min(_index + step, widget.points.length - 1);
          }
        } else {
          _index = min(_index + _speed.round().clamp(1, 3), widget.points.length - 1);
        }
      });

      if (_index >= widget.points.length - 1) {
        _ticker?.cancel();
        _showResult();
      }
    });
  }

  Future<void> _onSkipPressed() async {
    _ticker?.cancel();

    final InterstitialAd? ad = await AdHelper.loadInterstitial();
    if (ad == null) {
      _showResult();
      return;
    }

    final Completer<void> completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
    );

    ad.show();
    await completer.future;

    _showResult();
  }

  Future<void> _showResult() async {
    if (_resultShown) return;
    _resultShown = true;
    _skipTimer?.cancel();

    if (widget.points.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('데이터 없음'),
            content: const Text('선택한 기간에 대한 데이터를 찾을 수 없습니다.'),
            actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
          );
        },
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final int finalAmount = widget.points.last.value.round();
    final int profit = finalAmount - widget.flowState.investment;
    final double profitRate = (profit / widget.flowState.investment) * 100;

    await _historyRepository.append(
      SimulationResult(
        ticker: widget.flowState.selectedStock?.ticker ?? '',
        startYmd: widget.points.first.ymd,
        endYmd: widget.points.last.ymd,
        amount: finalAmount,
        profitRate: profitRate,
      ),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ResultDialog(
          initialAmount: widget.flowState.investment,
          finalAmount: finalAmount,
          profit: profit,
          profitRate: profitRate,
          onClose: () {
            AdService.instance.showOnClose(
              onDone: () => Navigator.of(this.context).popUntil((Route<dynamic> route) => route.isFirst),
            );
          },
        );
      },
    );
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = widget.points.isNotEmpty;
    final SimulationPoint current = hasData ? widget.points[_index] : const SimulationPoint(ymd: 0, close: 0, value: 0);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.flowState.selectedStock?.displayName ?? '차트'} 재생', style: PlaybackDesignTokens.title)),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: PlaybackDesignTokens.screenBackground),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_formatYmd(current.ymd), style: PlaybackDesignTokens.secondary),
              const SizedBox(height: 4),
              Text(AppNumberFormat.formatMoney(current.value), style: PlaybackDesignTokens.headlineNumber),
              const SizedBox(height: 2),
              Text('종가 ${AppNumberFormat.formatPrice(current.close, decimals: 2)}', style: PlaybackDesignTokens.secondary),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: PlaybackDesignTokens.chartStageDecoration,
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(child: _SimGridPattern()),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: AppSettings.chartMotionEnabled,
                          builder: (BuildContext context, bool motionOn, _) {
                            return StockChartPlayer(
                              points: widget.points,
                              currentIndex: _index,
                              pulse: motionOn ? (sin(_pulseTime) + 1) / 2 : 0,
                            );
                          },
                        ),
                      ),
                      const _CenterFocusMarker(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _PlayButton(
                    playing: _playing,
                    onPressed: () => setState(() => _playing = !_playing),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<double>(
                segments: const <ButtonSegment<double>>[
                  ButtonSegment<double>(value: 1, label: Text('1x')),
                  ButtonSegment<double>(value: 2, label: Text('2x')),
                  ButtonSegment<double>(value: 3, label: Text('3x')),
                ],
                selected: <double>{_speed},
                onSelectionChanged: (Set<double> value) => setState(() => _speed = value.first),
              ),
              const SizedBox(height: 10),
              Text('최근 30거래일 슬라이딩 윈도우 차트', style: PlaybackDesignTokens.secondary, textAlign: TextAlign.center),
              if (_showSkip)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _onSkipPressed,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                    child: const Text('스킵'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterFocusMarker extends StatelessWidget {
  const _CenterFocusMarker();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        final double centerX = constraints.maxWidth / 2;
        return Stack(
          children: <Widget>[
            Positioned(
              left: centerX,
              top: 8,
              bottom: 8,
              child: Container(width: 1, color: const Color(0x66FFFFFF)),
            ),
            Positioned(
              left: centerX - 5,
              top: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: <BoxShadow>[BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SimGridPattern extends StatelessWidget {
  const _SimGridPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SimGridPainter());
  }
}

class _SimGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: PlaybackDesignTokens.playButtonDecoration(active: playing),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.initialAmount,
    required this.finalAmount,
    required this.profit,
    required this.profitRate,
    required this.onClose,
  });

  final int initialAmount;
  final int finalAmount;
  final int profit;
  final double profitRate;
  final VoidCallback onClose;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  BannerAd? _banner;
  bool _bannerReady = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.preloadInterstitial();
    _banner = AdHelper.createBannerAd(
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) setState(() => _bannerReady = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('시뮬레이션 결과'),
      content: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        builder: (BuildContext context, double t, _) {
          final int finalAmount = (widget.finalAmount * t).round();
          final int profit = (widget.profit * t).round();
          final double profitRate = widget.profitRate * t;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('초기 투자금: ${AppNumberFormat.formatInt(widget.initialAmount)} 원'),
              const SizedBox(height: 6),
              Text('최종 평가금: ${AppNumberFormat.formatInt(finalAmount)} 원'),
              const SizedBox(height: 6),
              Text('수익금: ${AppNumberFormat.formatInt(profit)} 원'),
              const SizedBox(height: 6),
              Text('수익률: ${AppNumberFormat.formatPercent(profitRate)}'),
              const SizedBox(height: 12),
              if (_bannerReady && _banner != null)
                SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
            ],
          );
        },
      ),
      actions: <Widget>[
        ElevatedButton(
          onPressed: _closing
              ? null
              : () {
                  setState(() => _closing = true);
                  widget.onClose();
                },
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
