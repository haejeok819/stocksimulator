import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/battle/state/battle_setup_state.dart';
import 'package:stocksimulator/features/battle/widgets/battle_line_chart.dart';
import 'package:stocksimulator/shared/utils/ad_helper.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

enum _BattleStage { setup, playback, result }

class _BattlePoint {
  const _BattlePoint({required this.ymd, required this.valueA, required this.valueB, required this.returnA, required this.returnB});

  final int ymd;
  final double valueA;
  final double valueB;
  final double returnA;
  final double returnB;
}

class _BattleScreenState extends ConsumerState<BattleScreen> with SingleTickerProviderStateMixin {
  final StockRepository _repository = StockRepository();
  final GlobalKey _resultKey = GlobalKey();

  _BattleStage _stage = _BattleStage.setup;
  List<_BattlePoint> _points = <_BattlePoint>[];
  Timer? _countdownTimer;
  Ticker? _playbackTicker;
  Duration? _lastTick;
  int _countdown = 0;
  double _speed = 1;
  bool _pendingFrameUpdate = false;
  bool _finishing = false;
  bool _isPlaying = false;
  BattleRunStatus _playStatus = BattleRunStatus.ready;
  final ValueNotifier<int> _progressIndex = ValueNotifier<int>(0);
  final ValueNotifier<_BattlePoint?> _currentPoint = ValueNotifier<_BattlePoint?>(null);
  List<double> _seriesA = <double>[];
  List<double> _seriesB = <double>[];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playbackTicker?.dispose();
    _progressIndex.dispose();
    _currentPoint.dispose();
    super.dispose();
  }

  Future<List<StockModel>> _loadStocks(StockMarket market, String query) {
    return _repository.getTopStocks(market: market, query: query);
  }

  void _scheduleFrameUpdate(VoidCallback fn) {
    if (_pendingFrameUpdate) {
      return;
    }
    _pendingFrameUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingFrameUpdate = false;
      if (!mounted) {
        return;
      }
      fn();
    });
  }

  Future<StockModel?> _pickStock({required StockMarket initialMarket}) async {
    final TextEditingController controller = TextEditingController();
    String query = '';
    StockMarket selectedMarket = initialMarket;
    return showModalBottomSheet<StockModel>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                height: 520,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SegmentedButton<StockMarket>(
                        segments: const <ButtonSegment<StockMarket>>[
                          ButtonSegment<StockMarket>(value: StockMarket.us, label: Text('US')),
                          ButtonSegment<StockMarket>(value: StockMarket.kr, label: Text('KR')),
                        ],
                        selected: <StockMarket>{selectedMarket},
                        onSelectionChanged: (Set<StockMarket> value) {
                          setState(() {
                            selectedMarket = value.first;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        onChanged: (String value) {
                          setState(() {
                            query = value;
                          });
                        },
                        decoration: const InputDecoration(hintText: '종목 검색'),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<StockModel>>(
                        future: _loadStocks(selectedMarket, query),
                        builder: (BuildContext context, AsyncSnapshot<List<StockModel>> snapshot) {
                          final List<StockModel> stocks = snapshot.data ?? <StockModel>[];
                          return ListView.builder(
                            itemCount: stocks.length,
                            itemBuilder: (BuildContext context, int index) {
                              final StockModel stock = stocks[index];
                              return ListTile(
                                title: Text(stock.displayName),
                                subtitle: Text('${stock.ticker} · ${stock.market}'),
                                onTap: () => Navigator.of(context).pop(stock),
                              );
                            },
                          );
                        },
                      ),
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

  Future<void> _randomMatching() async {
    final List<StockModel> usStocks = await _repository.getTopStocks(market: StockMarket.us);
    final List<StockModel> krStocks = await _repository.getTopStocks(market: StockMarket.kr);
    final List<StockModel> stocks = <StockModel>[...usStocks, ...krStocks];
    if (stocks.length < 2) {
      return;
    }
    final Random random = Random();
    final StockModel a = stocks[random.nextInt(stocks.length)];
    StockModel b = stocks[random.nextInt(stocks.length)];
    while (b.ticker == a.ticker) {
      b = stocks[random.nextInt(stocks.length)];
    }
    ref.read(battleSetupProvider.notifier).setStockA(a);
    ref.read(battleSetupProvider.notifier).setStockB(b);
  }

  Future<void> _startBattle() async {
    _countdownTimer?.cancel();
    _playbackTicker?.dispose();
    _playbackTicker = null;
    _isPlaying = false;
    _playStatus = BattleRunStatus.ready;
    final BattleSetupState setup = ref.read(battleSetupProvider);
    if (setup.stockA == null || setup.stockB == null) {
      _showMessage('종목 A/B를 선택하세요.');
      return;
    }
    if (setup.stockA!.ticker == setup.stockB!.ticker) {
      _showMessage('동일 종목으로는 대결할 수 없습니다.');
      return;
    }

    try {
      final List<PricePoint> aSeries = await _repository.loadRange(
        market: setup.stockA!.market,
        ticker: setup.stockA!.ticker,
        start: setup.startDate,
        end: setup.endDate,
      );
      final List<PricePoint> bSeries = await _repository.loadRange(
        market: setup.stockB!.market,
        ticker: setup.stockB!.ticker,
        start: setup.startDate,
        end: setup.endDate,
      );

      final Map<int, double> mapA = <int, double>{for (final PricePoint p in aSeries) p.ymd: p.close};
      final Map<int, double> mapB = <int, double>{for (final PricePoint p in bSeries) p.ymd: p.close};
      final List<int> commonDates = mapA.keys.where((int d) => mapB.containsKey(d)).toList()..sort();

      if (commonDates.length < 30) {
        _showMessage('교집합 거래일이 부족합니다(최소 30일).');
        return;
      }

      final double amount = setup.investAmount.toDouble();
      final double sharesA = amount / mapA[commonDates.first]!;
      final double sharesB = amount / mapB[commonDates.first]!;

      final List<_BattlePoint> points = commonDates
          .map(
            (int ymd) {
              final double valueA = sharesA * mapA[ymd]!;
              final double valueB = sharesB * mapB[ymd]!;
              return _BattlePoint(
                ymd: ymd,
                valueA: valueA,
                valueB: valueB,
                returnA: ((valueA - amount) / amount) * 100,
                returnB: ((valueB - amount) / amount) * 100,
              );
            },
          )
          .toList();

      _points = points;
      _seriesA = points.map((e) => e.valueA).toList(growable: false);
      _seriesB = points.map((e) => e.valueB).toList(growable: false);
      _playStatus = BattleRunStatus.ready;
      _isPlaying = false;
      _progressIndex.value = 0;
      _currentPoint.value = points.first;
      setState(() {
        _stage = _BattleStage.playback;
        _countdown = 3;
      });
      _runCountdown();
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _runCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        _startPlayback();
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  void _startPlayback() {
    _playStatus = BattleRunStatus.running;
    _isPlaying = true;
    _lastTick = null;
    _playbackTicker?.dispose();
    _playbackTicker = createTicker((Duration elapsed) {
      if (!_isPlaying || _playStatus != BattleRunStatus.running || !mounted) {
        return;
      }

      final Duration previous = _lastTick ?? elapsed;
      final int deltaMs = (elapsed - previous).inMilliseconds;
      _lastTick = elapsed;
      if (deltaMs <= 0) {
        return;
      }

      _scheduleFrameUpdate(() {
        if (!_isPlaying || _playStatus != BattleRunStatus.running) {
          return;
        }

        final int currentIndex = _progressIndex.value;
        final double baseSteps = deltaMs / 32.0;
        final int step = max(1, (baseSteps * _speed).round());
        final int next = min(currentIndex + step, _points.length - 1);
        if (next == currentIndex) {
          return;
        }

        _progressIndex.value = next;
        _currentPoint.value = _points[next];

        if (next >= _points.length - 1) {
          _isPlaying = false;
          _playStatus = BattleRunStatus.finished;
          _playbackTicker?.stop();
          _finishBattle();
        }
      });
    });
    _playbackTicker?.start();
  }

  Future<void> _finishBattle() async {
    if (_finishing) {
      return;
    }
    _finishing = true;
    final _BattlePoint finalPoint = _points.last;
    final String winner = finalPoint.valueA >= finalPoint.valueB ? 'A' : 'B';
    final BattleResultState result = BattleResultState(
          finalValueA: finalPoint.valueA,
          finalValueB: finalPoint.valueB,
          finalReturnA: finalPoint.returnA,
          finalReturnB: finalPoint.returnB,
          winner: winner,
        );
    ref.read(battleResultProvider.notifier).state = result;
    _playStatus = BattleRunStatus.finished;
    _isPlaying = false;

    final BattleSetupState setup = ref.read(battleSetupProvider);
    await _showWinnerBurstDialog(result: result, setup: setup);

    if (!mounted) {
      return;
    }
    setState(() => _stage = _BattleStage.result);
    _finishing = false;
  }

  Future<void> _showWinnerBurstDialog({required BattleResultState result, required BattleSetupState setup}) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'winner',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A33),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('💥', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(
                    '🏆 ${result.winner} 승리!',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text('A(${setup.stockA?.ticker ?? '-'}) ${result.finalReturnA.toStringAsFixed(2)}%'),
                  Text('B(${setup.stockB?.ticker ?? '-'}) ${result.finalReturnB.toStringAsFixed(2)}%'),
                  const SizedBox(height: 12),
                  const Text(
                    '결과를 확인해보세요',
                    style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        final Animation<double> curve = CurvedAnimation(parent: animation, curve: Curves.elasticOut);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.5, end: 1).animate(curve), child: child),
        );
      },
    );
  }

  Future<void> _skipToResult() async {
    _isPlaying = false;
    _playStatus = BattleRunStatus.finished;
    _countdownTimer?.cancel();
    _playbackTicker?.dispose();
    _playbackTicker = null;
    final InterstitialAd? ad = await AdHelper.loadInterstitial();
    if (ad == null) {
      _finishBattle();
      return;
    }
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
    _finishBattle();
  }

  Future<void> _shareResult() async {
    final RenderRepaintBoundary boundary = _resultKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final Uint8List bytes = data.buffer.asUint8List();
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/battle_result.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(<XFile>[XFile(file.path)], text: '주식 대결 결과를 확인해보세요!');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatYmd(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  String _fmt(double v) => NumberFormat('#,###').format(v.round());

  @override
  Widget build(BuildContext context) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);
    final BattleResultState? result = ref.watch(battleResultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('대결')),
      body: switch (_stage) {
        _BattleStage.setup => _buildSetup(setup),
        _BattleStage.playback => _buildPlayback(setup),
        _BattleStage.result => _buildResult(setup, result),
      },
    );
  }

  Widget _buildSetup(BattleSetupState setup) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          _stockCard('종목 A 선택', setup.stockA, () async {
            final StockModel? picked = await _pickStock(initialMarket: setup.stockA?.market == 'KR' ? StockMarket.kr : StockMarket.us);
            if (picked != null) ref.read(battleSetupProvider.notifier).setStockA(picked);
          }),
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircleAvatar(radius: 18, child: Text('VS')),
          ),
          _stockCard('종목 B 선택', setup.stockB, () async {
            final StockModel? picked = await _pickStock(initialMarket: setup.stockB?.market == 'KR' ? StockMarket.kr : StockMarket.us);
            if (picked != null) ref.read(battleSetupProvider.notifier).setStockB(picked);
          }),
          const SizedBox(height: 14),
          _dateRangeSelector(setup),
          const SizedBox(height: 14),
          _investmentSelector(setup),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(child: OutlinedButton(onPressed: _randomMatching, child: const Text('랜덤 매칭'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _startBattle, child: const Text('시작'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateRangeSelector(BattleSetupState setup) {
    DateTime start = setup.startDate;
    DateTime end = setup.endDate;
    final double total = 3650;
    final DateTime base = DateTime.now().subtract(const Duration(days: 3649));
    final double startIndex = start.difference(base).inDays.clamp(0, 3649).toDouble();
    final double endIndex = end.difference(base).inDays.clamp(0, 3649).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${_formatYmd(start)} ~ ${_formatYmd(end)}'),
            RangeSlider(
              min: 0,
              max: total - 1,
              values: RangeValues(startIndex, endIndex),
              onChanged: (RangeValues v) {
                final DateTime s = base.add(Duration(days: v.start.round()));
                final DateTime e = base.add(Duration(days: v.end.round()));
                ref.read(battleSetupProvider.notifier).setDateRange(s, e);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _investmentSelector(BattleSetupState setup) {
    return Card(
      child: ListTile(
        title: const Text('투자금'),
        subtitle: Text('${NumberFormat('#,###').format(setup.investAmount)}원'),
        trailing: SizedBox(
          width: 180,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount - 10000).clamp(100, 100000000)),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                onPressed: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount + 10000).clamp(100, 100000000)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockCard(String label, StockModel? stock, VoidCallback onTap) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(stock == null ? '미선택' : '${stock.displayName} (${stock.ticker})'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPlayback(BattleSetupState setup) {
    return IgnorePointer(
      ignoring: _isPlaying,
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          if (_countdown > 0) Text('$_countdown', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          Row(
            children: <Widget>[
              Expanded(
                child: ValueListenableBuilder<_BattlePoint?>(
                  valueListenable: _currentPoint,
                  builder: (_, _BattlePoint? point, __) {
                    final _BattlePoint current = point ?? _points.first;
                    final bool aLeading = current.valueA >= current.valueB;
                    return _statusCard('A', setup.stockA!, current.valueA, current.returnA, aLeading);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<_BattlePoint?>(
                  valueListenable: _currentPoint,
                  builder: (_, _BattlePoint? point, __) {
                    final _BattlePoint current = point ?? _points.first;
                    final bool aLeading = current.valueA >= current.valueB;
                    return _statusCard('B', setup.stockB!, current.valueB, current.returnB, !aLeading);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF24242D), borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(10),
                child: ValueListenableBuilder<int>(
                  valueListenable: _progressIndex,
                  builder: (_, int progress, __) {
                    return BattleLineChart(
                      seriesA: _seriesA,
                      seriesB: _seriesB,
                      progress: progress,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<_BattlePoint?>(
            valueListenable: _currentPoint,
            builder: (_, _BattlePoint? point, __) {
              return Text('날짜: ${point?.ymd ?? _points.first.ymd}');
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (!(Platform.isWindows && _isPlaying))
                DropdownButton<double>(
                  value: _speed,
                  items: const <DropdownMenuItem<double>>[
                    DropdownMenuItem(value: 1, child: Text('1x')),
                    DropdownMenuItem(value: 2, child: Text('2x')),
                    DropdownMenuItem(value: 4, child: Text('4x')),
                  ],
                  onChanged: (double? v) => setState(() => _speed = v ?? 1),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_playStatus == BattleRunStatus.running) {
                    setState(() {
                      _playStatus = BattleRunStatus.paused;
                    });
                  } else {
                    setState(() {
                      _playStatus = BattleRunStatus.running;
                    });
                  }
                },
                child: Text(_playStatus == BattleRunStatus.running ? '일시정지' : '재개'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _skipToResult, child: const Text('스킵 → 결과')),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _statusCard(String label, StockModel stock, double value, double rate, bool leading) {
    return AnimatedScale(
      scale: leading ? 1.03 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
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
      ),
    );
  }

  Widget _buildResult(BattleSetupState setup, BattleResultState? result) {
    if (result == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          RepaintBoundary(
            key: _resultKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: <Widget>[
                  Text('🏆 ${result.winner} 승리', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _resultRow('A', setup.stockA!, result.finalValueA, result.finalReturnA),
                  const SizedBox(height: 8),
                  _resultRow('B', setup.stockB!, result.finalValueB, result.finalReturnB),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => setState(() => _stage = _BattleStage.setup),
            child: const Text('다시 대결'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _stage = _BattleStage.setup),
            child: const Text('기간 바꿔 재대결'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _shareResult, child: const Text('공유하기')),
        ],
      ),
    );
  }

  Widget _resultRow(String label, StockModel stock, double finalValue, double finalRate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('$label · ${stock.ticker}'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('${_fmt(finalValue)}원'),
            Text('${finalRate.toStringAsFixed(2)}%'),
          ],
        ),
      ],
    );
  }
}
