import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/features/battle/state/battle_playback_controller.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/features/battle/widgets/battle_chart.dart';
import 'package:stocksimulator/shared/share/services/share_link_service.dart';
import 'package:stocksimulator/shared/share/services/share_service.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';
import 'package:stocksimulator/shared/share/widgets/share_card.dart';
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
  bool _isSpeedFlowInProgress = false;

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
    if (AdService.instance.adsRemoved) {
      return true;
    }

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

    final BattlePlaybackStatus previousStatus = _pauseBattlePlaybackForInteraction();
    final bool watched = await _showInterstitialAdGate();

    if (!mounted) return;

    if (!watched) {
      setState(() {
        _isProcessingResultAd = false;
      });
      _resumeBattlePlaybackIfNeeded(previousStatus);
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
    await _showResultDialog(tick: tick, setup: setup, data: data);
  }


  BattlePlaybackStatus _pauseBattlePlaybackForInteraction() {
    final BattlePlaybackStatus previousStatus = ref.read(battlePlaybackControllerProvider).status;
    ref.read(battlePlaybackControllerProvider.notifier).pause();
    return previousStatus;
  }

  void _resumeBattlePlaybackIfNeeded(BattlePlaybackStatus previousStatus) {
    if (!mounted) return;
    if (previousStatus == BattlePlaybackStatus.running) {
      ref.read(battlePlaybackControllerProvider.notifier).resume();
    }
  }

  Future<void> _onSpeedSelected(double selectedSpeed) async {
    if (_isSpeedFlowInProgress || !mounted) return;

    final BattlePlaybackStatus previousStatus = _pauseBattlePlaybackForInteraction();

    if (selectedSpeed != 8) {
      ref.read(battlePlaybackControllerProvider.notifier).setSpeed(selectedSpeed);
      _resumeBattlePlaybackIfNeeded(previousStatus);
      return;
    }

    if (AppSettings.is8xSpeedUnlocked) {
      ref.read(battlePlaybackControllerProvider.notifier).setSpeed(8);
      _resumeBattlePlaybackIfNeeded(previousStatus);
      return;
    }

    _isSpeedFlowInProgress = true;

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

    if (shouldWatchAd == true && mounted) {
      final bool unlocked = await _showInterstitialAdGate();
      if (mounted && unlocked) {
        AppSettings.unlock8xSpeedFor(_unlockDuration);
        ref.read(battlePlaybackControllerProvider.notifier).setSpeed(8);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('광고 시청이 완료되지 않아 8x 잠금이 해제되지 않았어요.')),
        );
      }
    }

    _isSpeedFlowInProgress = false;
    _resumeBattlePlaybackIfNeeded(previousStatus);
  }

  String _koreanName(StockModel? stock) {
    if (stock == null) return '-';
    if (stock.nameKo.trim().isNotEmpty) return stock.nameKo.trim();
    return stock.displayName;
  }

  String _fmt(double value) => AppNumberFormat.formatInt(value);


  double _speedLabelFontSize(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return (width * 0.028).clamp(11.0, 14.0).toDouble();
  }

  ButtonStyle _speedSegmentStyle(BuildContext context) {
    return ButtonStyle(
      minimumSize: MaterialStateProperty.all(const Size(54, 38)),
      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
      side: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const BorderSide(color: Color(0xFF6EA8FF), width: 1.25);
        }
        return const BorderSide(color: Color(0x3D7A8CC7), width: 1.0);
      }),
      foregroundColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.disabled)) {
          return const Color(0xFF7F8391);
        }
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFF2F7FF);
        }
        return const Color(0xFFD2D8E8);
      }),
      backgroundColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF243B66);
        }
        return const Color(0xFF1E2432);
      }),
      textStyle: MaterialStateProperty.all(
        TextStyle(
          fontSize: _speedLabelFontSize(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Text _speedTextLabel(BuildContext context, String value, {Color? color}) {
    return Text(
      value,
      style: TextStyle(
        fontSize: _speedLabelFontSize(context),
        fontWeight: FontWeight.w700,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.visible,
      textScaler: const TextScaler.linear(1.0),
    );
  }

  String _formatYmd(int ymd) {
    final String s = ymd.toString().padLeft(8, '0');
    return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
  }


  void _tryAutoShowResult({
    required BattlePlaybackState playback,
    required BattleSeriesData data,
    required BattleSetupState setup,
  }) {
    if (_resultDialogShown || playback.status != BattlePlaybackStatus.ended || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _resultDialogShown) return;
      final BattleTick finalTick = data.tickAt(data.length - 1);
      ref.read(battleResultProvider.notifier).state = BattleResultState(
        finalValueA: finalTick.valueA,
        finalValueB: finalTick.valueB,
        finalReturnA: finalTick.returnA,
        finalReturnB: finalTick.returnB,
        winner: finalTick.returnA >= finalTick.returnB ? 'A' : 'B',
      );
      _showResultDialog(tick: finalTick, setup: setup, data: data);
    });
  }

  BattleSharePayload _buildBattleSharePayload({
    required BattleSetupState setup,
    required BattleTick tick,
    required BattleSeriesData data,
  }) {
    final String nameA = _koreanName(setup.stockA);
    final String nameB = _koreanName(setup.stockB);
    final double delta = tick.returnA - tick.returnB;
    final bool isTie = delta.abs() <= 0.01;
    final bool aWon = delta > 0.01;

    final String winnerLabel = isTie ? '무승부' : (aWon ? '$nameA 승' : '$nameB 승');
    final String deltaLabel = isTie ? '무승부 (차이 ${delta.abs().toStringAsFixed(2)}%p)' : '차이 ${delta.abs().toStringAsFixed(2)}%p';
    final String periodText = '${_formatYmd(data.normalized.dates.first)} ~ ${_formatYmd(data.normalized.dates.last)}';

    return BattleSharePayload(
      assetAName: nameA,
      assetBName: nameB,
      assetAReturnText: AppNumberFormat.formatPercent(tick.returnA),
      assetBReturnText: AppNumberFormat.formatPercent(tick.returnB),
      initialInvestmentText: '초기 ${AppNumberFormat.formatMoney(setup.investAmount)}',
      finalValueAText: '최종 ${AppNumberFormat.formatMoney(tick.valueA.round())}',
      finalValueBText: '최종 ${AppNumberFormat.formatMoney(tick.valueB.round())}',
      periodText: periodText,
      winnerLabel: winnerLabel,
      deltaText: deltaLabel,
      badgeText: 'BATTLE 결과',
      curiosityLine: ShareTextComposer.randomCuriosityLine(),
      seriesA: data.valuesA,
      seriesB: data.valuesB,
      aWon: aWon,
      isTie: isTie,
      shortIntersectionNotice: data.length < 45,
    );
  }

  Future<void> _openShareBottomSheet({
    required BattleSetupState setup,
    required BattleTick tick,
    required BattleSeriesData data,
  }) async {
    if (data.valuesA.length < 2 || data.valuesB.length < 2 || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유할 데이터가 부족합니다.')));
      return;
    }

    final BattleSharePayload payload = _buildBattleSharePayload(setup: setup, tick: tick, data: data);
    final ShareService shareService = const ShareService();
    final GlobalKey boundaryKey = GlobalKey();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B22),
      builder: (BuildContext sheetContext) {
        bool isSharing = false;
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            Future<void> onSharePressed() async {
              setModalState(() => isSharing = true);
              try {
                await shareService.shareBattleCard(boundaryKey, payload, preferShortText: true);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유에 실패했습니다. 다시 시도해주세요.')));
                }
              } finally {
                if (context.mounted) {
                  setModalState(() => isSharing = false);
                }
              }
            }

            Future<void> onCopyLinkPressed() async {
              final String message = await ShareLinkService.copyAppLink();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BattleShareCard(boundaryKey: boundaryKey, payload: payload),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSharing ? null : onSharePressed,
                        icon: isSharing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.share),
                        label: const Text('이미지 공유하기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onCopyLinkPressed,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('한번 해봐 (링크 복사)'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '카톡은 링크가 같이 안 붙을 수 있어요. 아래 버튼으로 링크를 복사해 붙여넣어 주세요.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA1A1A8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showResultDialog({required BattleTick tick, required BattleSetupState setup, required BattleSeriesData data}) async {

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
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF6AA8FF).withOpacity(0.34),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: () => _openShareBottomSheet(setup: setup, tick: tick, data: data),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('이미지 공유하기'),
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
            _tryAutoShowResult(playback: playback, data: data, setup: setup);

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

                        return DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x3347A2FF),
                                blurRadius: 16,
                                spreadRadius: 0.7,
                                offset: Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Color(0x1F8CCBFF),
                                blurRadius: 24,
                                spreadRadius: 1.2,
                              ),
                            ],
                          ),
                          child: SegmentedButton<double>(
                            style: _speedSegmentStyle(context),
                            showSelectedIcon: false,
                            segments: <ButtonSegment<double>>[
                              ButtonSegment<double>(value: 0.5, label: _speedTextLabel(context, '0.5x')),
                              ButtonSegment<double>(value: 1, label: _speedTextLabel(context, '1x')),
                              ButtonSegment<double>(value: 2, label: _speedTextLabel(context, '2x')),
                              ButtonSegment<double>(value: 4, label: _speedTextLabel(context, '4x')),
                              ButtonSegment<double>(
                                value: 8,
                                icon: Icon(
                                  is8xUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  size: 15,
                                  color: is8xUnlocked ? const Color(0xFFDCE9FF) : const Color(0xFF8B8B96),
                                ),
                                label: _speedTextLabel(
                                  context,
                                  '8x',
                                  color: is8xUnlocked ? const Color(0xFFDCE9FF) : const Color(0xFF8B8B96),
                                ),
                              ),
                            ],
                            selected: <double>{playback.speed},
                            onSelectionChanged: (Set<double> value) {
                              _onSpeedSelected(value.first);
                            },
                          ),
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
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = constraints.maxWidth;
                    final double amountFontSize = (width * 0.105).clamp(16.0, 23.0);
                    final double rateFontSize = (width * 0.080).clamp(14.0, 17.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${widget.label} · ${widget.ticker}', style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
                        const SizedBox(height: 4),
                        Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(
                          '₩ ${_fmt(widget.value)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: amountFontSize, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          AppNumberFormat.formatPercent(widget.rate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: rateFontSize, fontWeight: FontWeight.w800),
                        ),
                      ],
                    );
                  },
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
