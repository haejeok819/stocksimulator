import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _ResultDialog(
          initialAmount: widget.flowState.investment,
          finalAmount: finalAmount,
          profit: profit,
          profitRate: profitRate,
          onRetry: () {
            AdService.instance.showOnClose(
              onDone: () => Navigator.of(this.context).popUntil((Route<dynamic> route) => route.isFirst),
            );
          },
          onViewHistory: () {
            Navigator.of(this.context).popUntil((Route<dynamic> route) => route.isFirst);
            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('기록 탭에서 결과를 확인하세요.')));
          },
        );
      },
    );
  }


  String _formatPriceByMarket(double price, String marketCode) {
    if (marketCode == 'US') {
      return '\$${AppNumberFormat.formatPrice(price, decimals: 2)}';
    }
    return '${AppNumberFormat.formatInt(price)}원';
  }

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = widget.points.isNotEmpty;
    final SimulationPoint current = hasData ? widget.points[_index] : const SimulationPoint(ymd: 0, close: 0, value: 0);
    final String marketCode = widget.flowState.marketCode;

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
              Text(_formatPriceByMarket(current.close, marketCode), style: PlaybackDesignTokens.headlineNumber),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('시작 ${_formatPriceByMarket(widget.points.first.close, marketCode)}', style: PlaybackDesignTokens.secondary),
                  Text('종료 ${_formatPriceByMarket(widget.points.last.close, marketCode)}', style: PlaybackDesignTokens.secondary),
                ],
              ),
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
                              marketCode: marketCode,
                            );
                          },
                        ),
                      ),
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
              Text('전체 기간 주가 차트', style: PlaybackDesignTokens.secondary, textAlign: TextAlign.center),
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
    required this.onRetry,
    required this.onViewHistory,
  });

  final int initialAmount;
  final int finalAmount;
  final int profit;
  final double profitRate;
  final VoidCallback onRetry;
  final VoidCallback onViewHistory;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _impactController;

  bool get _isSafeMode {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  bool get _isPositive => widget.profitRate >= 0;

  @override
  void initState() {
    super.initState();
    _impactController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..forward();
  }

  @override
  void dispose() {
    _impactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _isPositive ? const Color(0xFF22C55E) : const Color(0xFFE54B4B);
    final Color tint = _isPositive ? const Color(0x1A22C55E) : const Color(0x1AE54B4B);
    final String badgeTitle = _isPositive ? '성공적인 투자!' : '아쉬운 결과';
    final String badgeIcon = _isPositive ? '🎉' : '📉';
    final String ctaLabel = _isPositive ? '더 높은 수익 노리기' : '전략 다시 세우기';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          if (!_isSafeMode)
            AnimatedBuilder(
              animation: _impactController,
              builder: (_, __) {
                final double burst = Curves.easeOut.transform(_impactController.value);
                return Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.15 + (burst * 1.3),
                          colors: <Color>[
                            Colors.white.withOpacity((1 - burst) * 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          AnimatedBuilder(
            animation: _impactController,
            builder: (_, __) {
              final double flash = _isSafeMode ? 0 : (1 - Curves.easeOut.transform((_impactController.value * 2).clamp(0, 1))) * 0.22;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF22222B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20),
                    if (_isPositive && widget.profitRate >= 30 && !_isSafeMode)
                      BoxShadow(color: const Color(0x6622C55E), blurRadius: 24, spreadRadius: 1),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    if (flash > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withOpacity(flash),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topRight,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 20, color: Color(0xFFA1A1A8)),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: <Widget>[
                                Text(badgeIcon, style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 4),
                                Text(badgeTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(AppNumberFormat.formatPercent(widget.profitRate), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _impactController,
                            builder: (_, __) {
                              final double t = Curves.easeOutBack.transform(_impactController.value.clamp(0, 1));
                              final double y = (!_isPositive && widget.profitRate <= -20 && !_isSafeMode) ? (1 - t) * 12 : 0;
                              return Opacity(
                                opacity: _isSafeMode ? 1 : t.clamp(0, 1),
                                child: Transform.translate(
                                  offset: Offset(0, y),
                                  child: Transform.scale(
                                    scale: _isSafeMode ? 1 : (0.8 + (t * 0.3)).clamp(0.8, 1.1),
                                    child: Text(
                                      AppNumberFormat.formatPercent(widget.profitRate),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: accent),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A33),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x1FFFFFFF)),
                            ),
                            child: Column(
                              children: <Widget>[
                                _MetricRow(label: '초기 투자금', value: AppNumberFormat.formatMoney(widget.initialAmount)),
                                const SizedBox(height: 8),
                                _MetricRow(label: '최종 평가금', value: AppNumberFormat.formatMoney(widget.finalAmount)),
                                const SizedBox(height: 8),
                                _MetricRow(label: '수익금', value: AppNumberFormat.formatMoney(widget.profit), valueColor: accent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: widget.onRetry,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                            child: Text(ctaLabel),
                          ),
                          const SizedBox(height: 4),
                          TextButton(onPressed: widget.onViewHistory, child: const Text('기록 보기')),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Color(0xFFA1A1A8), fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: valueColor ?? Colors.white)),
      ],
    );
  }
}
