import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/battle/screens/battle_playback_screen.dart';
import 'package:stocksimulator/features/battle/state/battle_playback_controller.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BattleSetupScreen extends ConsumerStatefulWidget {
  const BattleSetupScreen({super.key});

  @override
  ConsumerState<BattleSetupScreen> createState() => _BattleSetupScreenState();
}

class _BattleSetupScreenState extends ConsumerState<BattleSetupScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctaPulseController;

  @override
  void initState() {
    super.initState();
    _ctaPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctaPulseController.dispose();
    super.dispose();
  }

  int _dayCount(DateTime start, DateTime end) {
    return end.difference(start).inDays.abs() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '대결 준비',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            _BattleTickerCompareSection(setup: setup),
            const SizedBox(height: 24),
            BattleRangeSelector(setup: setup, dayCount: _dayCount(setup.startDate, setup.endDate)),
            const SizedBox(height: 16),
            BattleAmountInput(setup: setup),
            const SizedBox(height: 16),
            _BattleAutoSafeModeInfo(enabled: setup.safeMode),
            const SizedBox(height: 24),
            BattleStartButtons(setup: setup, pulse: _ctaPulseController),
          ],
        ),
      ),
    );
  }
}

class _BattleTickerCompareSection extends StatelessWidget {
  const _BattleTickerCompareSection({required this.setup});

  final BattleSetupState setup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('종목 A VS 종목 B', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14, color: const Color(0xFFA1A1A8))),
        const SizedBox(height: 12),
        BattleTickerCard(
          stock: setup.stockA,
          label: 'A',
          tint: const Color(0x22E54B4B),
          borderColor: const Color(0x66E54B4B),
          labelColor: const Color(0xFFE54B4B),
          market: StockMarket.kr,
        ),
        const SizedBox(height: 12),
        const _VsBadge(),
        const SizedBox(height: 12),
        BattleTickerCard(
          stock: setup.stockB,
          label: 'B',
          tint: const Color(0x22266DD3),
          borderColor: const Color(0x66266DD3),
          labelColor: const Color(0xFF266DD3),
          market: StockMarket.kr,
        ),
      ],
    );
  }
}

class _VsBadge extends StatefulWidget {
  const _VsBadge();

  @override
  State<_VsBadge> createState() => _VsBadgeState();
}

class _VsBadgeState extends State<_VsBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final double scale = 1 + (_controller.value * 0.04);
        return Transform.scale(
          scale: scale,
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: <Color>[Color(0xFF5677E7), Color(0xFF6F8FFF)]),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: const Color(0xFF5677E7).withOpacity(0.45), blurRadius: 18, spreadRadius: 1),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
        );
      },
    );
  }
}

class BattleTickerCard extends ConsumerStatefulWidget {
  const BattleTickerCard({
    super.key,
    required this.stock,
    required this.label,
    required this.tint,
    required this.borderColor,
    required this.labelColor,
    required this.market,
  });

  final StockModel? stock;
  final String label;
  final Color tint;
  final Color borderColor;
  final Color labelColor;
  final StockMarket market;

  @override
  ConsumerState<BattleTickerCard> createState() => _BattleTickerCardState();
}

class _BattleTickerCardState extends ConsumerState<BattleTickerCard> {
  bool _pressed = false;

  Future<void> _pickStock() async {
    final TextEditingController controller = TextEditingController();
    String query = '';
    StockMarket selectedMarket = widget.market;

    final StockModel? stock = await showModalBottomSheet<StockModel>(
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
                          ButtonSegment<StockMarket>(value: StockMarket.kr, label: Text('KR')),
                        ],
                        selected: <StockMarket>{selectedMarket},
                        onSelectionChanged: (Set<StockMarket> value) => setState(() => selectedMarket = value.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        onChanged: (String value) => setState(() => query = value),
                        decoration: const InputDecoration(hintText: '종목 검색'),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<StockModel>>(
                        future: ref.read(battleStockRepositoryProvider).getTopStocks(market: selectedMarket, query: query),
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

    if (stock == null) {
      return;
    }

    if (widget.label == 'A') {
      ref.read(battleSetupProvider.notifier).setStockA(stock);
    } else {
      ref.read(battleSetupProvider.notifier).setStockB(stock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String ticker = widget.stock?.ticker ?? '미선택';
    final String name = widget.stock?.displayName ?? '종목을 선택해주세요';
    final String logoText = widget.stock == null ? widget.label : ticker.substring(0, 1);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _pickStock,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 1.03 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.tint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(logoText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('종목 ${widget.label}', style: TextStyle(fontSize: 14, color: widget.labelColor, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class BattleRangeSelector extends ConsumerWidget {
  const BattleRangeSelector({super.key, required this.setup, required this.dayCount});

  final BattleSetupState setup;
  final int dayCount;

  int _toYmd(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  String _formatYmd(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String _formatDateWithWeekday(DateTime date) {
    const List<String> weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
    return '${_formatYmd(date)} (${weekdays[date.weekday - 1]})';
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, {required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? setup.startDate : setup.endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3649)),
      lastDate: DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    final DateTime currentStart = setup.startDate;
    final DateTime currentEnd = setup.endDate;

    if (isStart) {
      final DateTime nextStart = picked;
      final DateTime nextEnd = picked.isAfter(currentEnd) ? picked : currentEnd;
      ref.read(battleSetupProvider.notifier).setDateRange(nextStart, nextEnd);
      return;
    }

    final DateTime nextEnd = picked;
    final DateTime nextStart = picked.isBefore(currentStart) ? picked : currentStart;
    ref.read(battleSetupProvider.notifier).setDateRange(nextStart, nextEnd);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime base = DateTime.now().subtract(const Duration(days: 3649));
    final double startIndex = setup.startDate.difference(base).inDays.clamp(0, 3649).toDouble();
    final double endIndex = setup.endDate.difference(base).inDays.clamp(0, 3649).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('기간 선택', style: TextStyle(fontSize: 14, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 8),
            Text('${_formatYmd(setup.startDate)} → ${_formatYmd(setup.endDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('총 $dayCount 거래일', style: const TextStyle(fontSize: 14, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
                activeTrackColor: const Color(0xFF5677E7),
                inactiveTrackColor: const Color(0xFF3A3A44),
                thumbColor: const Color(0xFF6B89F0),
              ),
              child: RangeSlider(
                min: 0,
                max: 3649,
                values: RangeValues(startIndex, endIndex),
                onChanged: (RangeValues value) {
                  final DateTime start = base.add(Duration(days: value.start.round()));
                  final DateTime end = base.add(Duration(days: value.end.round()));
                  ref.read(battleSetupProvider.notifier).setDateRange(start, end);
                },
              ),
            ),
            const SizedBox(height: 8),
            _DateCard(
              label: '매수 시점',
              value: _formatDateWithWeekday(setup.startDate),
              onTap: () => _pickDate(context, ref, isStart: true),
              semanticValue: _toYmd(setup.startDate).toString(),
            ),
            const SizedBox(height: 8),
            _DateCard(
              label: '매도 시점',
              value: _formatDateWithWeekday(setup.endDate),
              onTap: () => _pickDate(context, ref, isStart: false),
              semanticValue: _toYmd(setup.endDate).toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.label, required this.value, required this.onTap, required this.semanticValue});

  final String label;
  final String value;
  final VoidCallback onTap;
  final String semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: semanticValue,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A44)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFFA1A1A8))),
              Flexible(child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class BattleAmountInput extends ConsumerWidget {
  const BattleAmountInput({super.key, required this.setup});

  final BattleSetupState setup;

  static const List<int> presets = <int>[100000, 500000, 1000000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('투자금', style: TextStyle(fontSize: 14, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 8),
            Text(AppNumberFormat.formatMoney(setup.investAmount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _AmountButton(
                    icon: Icons.remove,
                    onTap: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount - 10000).clamp(100, 100000000)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AmountButton(
                    icon: Icons.add,
                    onTap: () => ref.read(battleSetupProvider.notifier).setInvestAmount((setup.investAmount + 10000).clamp(100, 100000000)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: presets
                  .map(
                    (int amount) => ChoiceChip(
                      label: Text(_presetLabel(amount)),
                      selected: setup.investAmount == amount,
                      onSelected: (_) => ref.read(battleSetupProvider.notifier).setInvestAmount(amount),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  String _presetLabel(int amount) {
    return AppNumberFormat.formatMoney(amount, symbol: '₩');
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF31313B),
      elevation: 3,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _BattleAutoSafeModeInfo extends StatelessWidget {
  const _BattleAutoSafeModeInfo({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF24242D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A44)),
      ),
      child: Row(
        children: <Widget>[
          const Text('🛡️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '안전모드 (Desktop/Web): ${enabled ? '자동 활성화' : '비활성화'}',
              style: const TextStyle(fontSize: 14, color: Color(0xFFA1A1A8)),
            ),
          ),
        ],
      ),
    );
  }
}

class BattleStartButtons extends ConsumerWidget {
  bool _isSameAsset(StockModel a, StockModel b) {
    return a.assetType == b.assetType && a.assetKey == b.assetKey;
  }

  const BattleStartButtons({super.key, required this.setup, required this.pulse});

  final BattleSetupState setup;
  final Animation<double> pulse;

  Future<void> _randomMatching(WidgetRef ref) async {
    final StockRepository repository = ref.read(battleStockRepositoryProvider);
    final List<StockModel> stocks = await repository.getTopStocks(market: StockMarket.kr);

    if (stocks.length < 2) {
      return;
    }

    final Random random = Random();
    final StockModel a = stocks[random.nextInt(stocks.length)];
    StockModel b = stocks[random.nextInt(stocks.length)];

    while (_isSameAsset(a, b)) {
      b = stocks[random.nextInt(stocks.length)];
    }

    ref.read(battleSetupProvider.notifier).setStockA(a);
    ref.read(battleSetupProvider.notifier).setStockB(b);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedBuilder(
          animation: pulse,
          builder: (_, Widget? child) {
            final double scale = 1 + (pulse.value * 0.03);
            return Transform.scale(scale: scale, child: child);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: <Color>[Color(0xFF5677E7), Color(0xFF7F95F2)]),
              boxShadow: <BoxShadow>[BoxShadow(color: const Color(0xFF5677E7).withOpacity(0.45), blurRadius: 16, spreadRadius: 1)],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              onPressed: () async {
                if (setup.stockA == null || setup.stockB == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('종목 A/B를 선택하세요.')));
                  return;
                }
                if (_isSameAsset(setup.stockA!, setup.stockB!)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('동일 자산은 선택할 수 없습니다.')));
                  return;
                }
                ref.invalidate(battleDataProvider);
                ref.read(battlePlaybackControllerProvider.notifier).reset();
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BattlePlaybackScreen()));
              },
              child: const Text('Start Battle'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            side: const BorderSide(color: Color(0xFF5677E7)),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _randomMatching(ref),
          child: const Text('랜덤 매칭', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
