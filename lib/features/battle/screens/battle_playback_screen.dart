import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/features/battle/state/battle_playback_controller.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/features/battle/widgets/battle_chart.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';
import 'package:stocksimulator/shared/utils/error_message.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BattlePlaybackScreen extends ConsumerStatefulWidget {
  const BattlePlaybackScreen({super.key});

  @override
  ConsumerState<BattlePlaybackScreen> createState() => _BattlePlaybackScreenState();
}

class _BattlePlaybackScreenState extends ConsumerState<BattlePlaybackScreen> {
  bool _resultDialogShown = false;
  String _previousLeader = 'A';
  bool _flash = false;
  bool _isProcessingResultAd = false;

  Timer? _speedUnlockTimer;
  static const Duration _unlockDuration = Duration(minutes: 5);
  @override
  void initState() {
    super.initState();
    AppSettings.speed8xUnlockedUntil.addListener(_on8xUnlockChanged);
    _schedule8xUnlockExpiryCheck();
    AdService.instance.preloadInterstitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ref.read(battlePlaybackControllerProvider.notifier).start();
    });
  }


  @override
  void dispose() {
    _speedUnlockTimer?.cancel();
    AppSettings.speed8xUnlockedUntil.removeListener(_on8xUnlockChanged);
    super.dispose();
  }

  void _on8xUnlockChanged() {
    _schedule8xUnlockExpiryCheck();
    if (!mounted) return;

    final BattlePlaybackState playback = ref.read(battlePlaybackControllerProvider);
    if (!AppSettings.is8xSpeedUnlocked && playback.speed == 8) {
      ref.read(battlePlaybackControllerProvider.notifier).setSpeed(4);
    }

    setState(() {});
  }

  void _schedule8xUnlockExpiryCheck() {
    _speedUnlockTimer?.cancel();
    final DateTime? unlockUntil = AppSettings.speed8xUnlockedUntil.value;
    if (unlockUntil == null) {
      return;
    }

    final Duration remaining = unlockUntil.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      if (AppSettings.speed8xUnlockedUntil.value != null) {
        AppSettings.speed8xUnlockedUntil.value = null;
      }
      return;
    }

    _speedUnlockTimer = Timer(remaining, () {
      if (AppSettings.speed8xUnlockedUntil.value == unlockUntil) {
        AppSettings.speed8xUnlockedUntil.value = null;
      }
    });
  }

  Future<bool> _showInterstitialAdGate() async {
    final InterstitialAd? ad = await AdService.instance.takeOrLoadInterstitial();
    if (!mounted || ad == null) {
      return false;
    }

    final Completer<bool> completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      if (!completer.isCompleted) completer.complete(false);
    }

    final bool watched = await completer.future;
    AdService.instance.preloadInterstitial();
    return watched;
  }

  Future<void> _onResultViewPressed(BattleSeriesData data, BattleSetupState setup) async {
    if (_isProcessingResultAd || !mounted) return;

    setState(() {
      _isProcessingResultAd = true;
    });

    final BattlePlaybackStatus previousStatus = ref.read(battlePlaybackControllerProvider).status;
    ref.read(battlePlaybackControllerProvider.notifier).pause();
    final bool watched = await _showInterstitialAdGate();

    if (!mounted) return;

    if (!watched) {
      setState(() {
        _isProcessingResultAd = false;
      });
      if (previousStatus == BattlePlaybackStatus.running) {
        ref.read(battlePlaybackControllerProvider.notifier).resume();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고 시청이 완료되지 않아 결과를 볼 수 없어요.')),
      );
      return;
    }

    ref.read(battlePlaybackControllerProvider.notifier).skipToEnd();
    final BattleTick tick = data.tickAt(data.length - 1);
    ref.read(battleResultProvider.notifier).state = BattleResultState(
      finalValueA: tick.valueA,
      finalValueB: tick.valueB,
      finalReturnA: tick.returnA,
      finalReturnB: tick.returnB,
      winner: tick.returnA >= tick.returnB ? 'A' : 'B',
    );

    setState(() {
      _isProcessingResultAd = false;
    });
    await _showResultDialog(tick: tick, setup: setup);
  }

  Future<void> _onSpeedSelected(double selectedSpeed) async {
    if (selectedSpeed != 8) {
      ref.read(battlePlaybackControllerProvider.notifier).setSpeed(selectedSpeed);
      return;
    }

    if (AppSettings.is8xSpeedUnlocked) {
      ref.read(battlePlaybackControllerProvider.notifier).setSpeed(8);
      return;
    }

    final bool? shouldWatchAd = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('8x 스피드 잠금'),
          content: const Text('광고를 보고 나면 8x 스피드를 사용할 수 있어요.\n5분 동안은 광고가 다시 나오지 않아요.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('광고 보고 사용하기')),
          ],
        );
      },
    );

    if (shouldWatchAd != true || !mounted) return;

    final bool unlocked = await _showInterstitialAdGate();
    if (!mounted) return;

    if (!unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고 시청이 완료되지 않아 8x 잠금이 해제되지 않았어요.')),
      );
      return;
    }

    AppSettings.unlock8xSpeedFor(_unlockDuration);
    ref.read(battlePlaybackControllerProvider.notifier).setSpeed(8);
  }

  String _koreanName(StockModel? stock) {
    if (stock == null) return '-';
    if (stock.nameKo.trim().isNotEmpty) return stock.nameKo.trim();
    return stock.displayName;
  }

  String _fmt(double value) => AppNumberFormat.formatInt(value);

  String _formatYmd(int ymd) {
    final String s = ymd.toString().padLeft(8, '0');
    return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
  }


  Future<void> _showResultDialog({required BattleTick tick, required BattleSetupState setup}) async {
    if (_resultDialogShown || !mounted) return;
    _resultDialogShown = true;

    final bool aWins = tick.returnA >= tick.returnB;
    final String winner = aWins ? _koreanName(setup.stockA) : _koreanName(setup.stockB);
    final double winnerRate = aWins ? tick.returnA : tick.returnB;
    final double loserRate = aWins ? tick.returnB : tick.returnA;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF24242D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('🏁 대결 종료', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('$winner 승리', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF9AD3FF))),
                const SizedBox(height: 8),
                Text('승자 수익률 ${AppNumberFormat.formatPercent(winnerRate)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('상대 수익률 ${AppNumberFormat.formatPercent(loserRate)}', style: const TextStyle(color: Color(0xFFA1A1A8))),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('종료'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }


  @override
  Widget build(BuildContext context) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);
    final AsyncValue<BattleSeriesData> dataAsync = ref.watch(battleDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Battle Playback')),
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, __) => KeyEventResult.handled,
        child: dataAsync.when(
          data: (BattleSeriesData data) {
            final BattlePlaybackState playback = ref.watch(battlePlaybackControllerProvider);
            final BattlePlaybackController playbackController = ref.read(battlePlaybackControllerProvider.notifier);
            final double renderPosition = playbackController.easedPositionForRender();
            final BattleTick tick = data.tickAtPosition(renderPosition);
            final bool aLeading = tick.returnA >= tick.returnB;
            final String leader = aLeading ? 'A' : 'B';

            if (_previousLeader != leader) {
            _previousLeader = leader;
            if (!setup.safeMode) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _flash = true);
                Future<void>.delayed(const Duration(milliseconds: 260), () {
                  if (mounted) {
                    setState(() => _flash = false);
                  }
                });
              });
            }
          }

            final double leadGap = (tick.returnA - tick.returnB).abs();
            final double gauge = (50 + ((tick.returnA - tick.returnB).clamp(-20, 20) * 2.5)).clamp(0, 100) / 100;

            return Stack(
            children: <Widget>[
              if (_flash && !setup.safeMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _flash ? 0.16 : 0,
                      child: Container(color: Colors.white),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: <Widget>[
                    _ScoreBoard(
                      safeMode: setup.safeMode,
                      nameA: _koreanName(setup.stockA),
                      tickerA: setup.stockA?.ticker ?? '-',
                      valueA: tick.valueA,
                      returnA: tick.returnA,
                      nameB: _koreanName(setup.stockB),
                      tickerB: setup.stockB?.ticker ?? '-',
                      valueB: tick.valueB,
                      returnB: tick.returnB,
                      aLeading: aLeading,
                    ),
                    const SizedBox(height: 12),
                    _LeadGauge(gauge: gauge, aLeading: aLeading, gap: leadGap),
                    const SizedBox(height: 12),
                    if (data.shouldShowCoverageNotice)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A33),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x553A3A42)),
                        ),
                        child: Text(
                          '공통 거래일 구간으로 비교합니다 (${_formatYmd(data.normalized.dates.first)} ~ ${_formatYmd(data.normalized.dates.last)})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8)),
                        ),
                      ),
                    Expanded(
                      child: IgnorePointer(
                        ignoring: setup.safeMode,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[Color(0xFF272734), Color(0xFF1D1D25)],
                            ),
                          ),
                          child: Stack(
                            children: <Widget>[
                              const Positioned.fill(child: _GridPattern()),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: BattleChart(
                                  seriesA: data.returnsA,
                                  seriesB: data.returnsB,
                                  dates: data.normalized.dates,
                                  playbackIndex: playback.index,
                                  playbackPosition: renderPosition,
                                  basePriceA: data.normalized.closeA.first,
                                  basePriceB: data.normalized.closeB.first,
                                  marketCodeA: setup.stockA?.market ?? 'KR',
                                  marketCodeB: setup.stockB?.market ?? 'KR',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: setup.safeMode ? Duration.zero : const Duration(milliseconds: 150),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        if (setup.safeMode) return child;
                        return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(animation), child: child));
                      },
                      child: Text(
                        '📅 ${_formatYmd(tick.ymd)}',
                        key: ValueKey<int>(tick.ymd),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 136, maxWidth: 210),
                        child: OutlinedButton(
                          onPressed: _isProcessingResultAd ? null : () => _onResultViewPressed(data, setup),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F3E5F),
                            foregroundColor: const Color(0xFFEAF0FF),
                            side: const BorderSide(color: Color(0xC26E8BFF), width: 1),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
                          ),
                          child: _isProcessingResultAd
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('결과 보기', textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _PlayPauseButton(
                          playing: playback.status == BattlePlaybackStatus.running,
                          safeMode: setup.safeMode,
                          onPressed: playback.status == BattlePlaybackStatus.running
                              ? () => ref.read(battlePlaybackControllerProvider.notifier).pause()
                              : () => ref.read(battlePlaybackControllerProvider.notifier).resume(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: AppSettings.speed8xUnlockedUntil,
                      builder: (BuildContext context, DateTime? unlockUntil, _) {
                        final bool is8xUnlocked = unlockUntil != null && DateTime.now().isBefore(unlockUntil);

                        return SegmentedButton<double>(
                          segments: <ButtonSegment<double>>[
                            const ButtonSegment<double>(value: 0.5, label: Text('0.5x')),
                            const ButtonSegment<double>(value: 1, label: Text('1x')),
                            const ButtonSegment<double>(value: 2, label: Text('2x')),
                            const ButtonSegment<double>(value: 4, label: Text('4x')),
                            ButtonSegment<double>(
                              value: 8,
                              icon: Icon(
                                is8xUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                size: 16,
                                color: is8xUnlocked ? null : const Color(0xFF8B8B96),
                              ),
                              label: Text(
                                '8x',
                                style: TextStyle(color: is8xUnlocked ? null : const Color(0xFF8B8B96)),
                              ),
                            ),
                          ],
                          selected: <double>{playback.speed},
                          onSelectionChanged: (Set<double> value) {
                            _onSpeedSelected(value.first);
                          },
                        );
                      },
                    ),
                    if (playback.showCountdown)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${playback.countdown}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace s) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(toUserMessage(e), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({
    required this.safeMode,
    required this.nameA,
    required this.tickerA,
    required this.valueA,
    required this.returnA,
    required this.nameB,
    required this.tickerB,
    required this.valueB,
    required this.returnB,
    required this.aLeading,
  });

  final bool safeMode;
  final String nameA;
  final String tickerA;
  final double valueA;
  final double returnA;
  final String nameB;
  final String tickerB;
  final double valueB;
  final double returnB;
  final bool aLeading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _LeaderCard(
            label: 'A',
            name: nameA,
            ticker: tickerA,
            value: valueA,
            rate: returnA,
            leader: aLeading,
            safeMode: safeMode,
            leaderTint: const Color(0x22E54B4B),
            leaderBorder: const Color(0x77E54B4B),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF5677E7),
            boxShadow: <BoxShadow>[BoxShadow(color: const Color(0xFF5677E7).withOpacity(0.32), blurRadius: 12)],
          ),
          child: const Text('VS', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LeaderCard(
            label: 'B',
            name: nameB,
            ticker: tickerB,
            value: valueB,
            rate: returnB,
            leader: !aLeading,
            safeMode: safeMode,
            leaderTint: const Color(0x22266DD3),
            leaderBorder: const Color(0x77266DD3),
          ),
        ),
      ],
    );
  }
}

class _LeaderCard extends StatefulWidget {
  const _LeaderCard({
    required this.label,
    required this.name,
    required this.ticker,
    required this.value,
    required this.rate,
    required this.leader,
    required this.safeMode,
    required this.leaderTint,
    required this.leaderBorder,
  });

  final String label;
  final String name;
  final String ticker;
  final double value;
  final double rate;
  final bool leader;
  final bool safeMode;
  final Color leaderTint;
  final Color leaderBorder;

  @override
  State<_LeaderCard> createState() => _LeaderCardState();
}

class _LeaderCardState extends State<_LeaderCard> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  bool _prevLeader = false;

  @override
  void initState() {
    super.initState();
    _prevLeader = widget.leader;
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void didUpdateWidget(covariant _LeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_prevLeader && widget.leader && !widget.safeMode) {
      _flipController.forward(from: 0);
    }
    _prevLeader = widget.leader;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  String _fmt(double value) => AppNumberFormat.formatInt(value);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (_, __) {
        final double t = _flipController.value;
        final double angle = t * pi;
        final bool isBackFace = angle > (pi / 2);
        final bool sparkle = t > 0 && t < 0.65;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(isBackFace ? pi : 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: widget.leader ? 1 : 0.85,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.leader ? widget.leaderTint : const Color(0xFF2A2A33),
                  border: Border.all(color: widget.leader ? widget.leaderBorder : Colors.transparent),
                  boxShadow: widget.leader
                      ? <BoxShadow>[
                          BoxShadow(color: widget.leaderBorder.withOpacity(0.35), blurRadius: 16, spreadRadius: 1),
                          if (sparkle) BoxShadow(color: Colors.white.withOpacity(0.55), blurRadius: 20, spreadRadius: 2),
                        ]
                      : <BoxShadow>[],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${widget.label} · ${widget.ticker}', style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
                    const SizedBox(height: 4),
                    Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text('₩ ${_fmt(widget.value)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(AppNumberFormat.formatPercent(widget.rate), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPattern extends StatelessWidget {
  const _GridPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint vPaint = Paint()..color = Colors.white.withOpacity(0.012)..strokeWidth = 1;
    final Paint hPaint = Paint()..color = Colors.white.withOpacity(0.022)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), vPaint);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeadGauge extends StatelessWidget {
  const _LeadGauge({required this.gauge, required this.aLeading, required this.gap});

  final double gauge;
  final bool aLeading;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 8,
          decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(99)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: gauge,
              child: Container(
                decoration: BoxDecoration(
                  color: aLeading ? const Color(0xFFE54B4B) : const Color(0xFF266DD3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('승부 게이지 · 격차 ${AppNumberFormat.formatPercentPoint(gap)}', style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.safeMode, required this.onPressed});

  final bool playing;
  final bool safeMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: <Color>[Color(0xFF5677E7), Color(0xFF7593F5)]),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0xFF5677E7).withOpacity(playing && !safeMode ? 0.5 : 0.25), blurRadius: 16, spreadRadius: 1),
        ],
      ),
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
