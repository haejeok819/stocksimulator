import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/loading_screen.dart';
import 'package:stocksimulator/features/sim/state/investment_amount_provider.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class InvestmentInputScreen extends ConsumerStatefulWidget {
  const InvestmentInputScreen({
    super.key,
    required this.repository,
    required this.flowState,
  });

  final StockRepository repository;
  final SimulationFlowState flowState;

  @override
  ConsumerState<InvestmentInputScreen> createState() => _InvestmentInputScreenState();
}

class _InvestmentInputScreenState extends ConsumerState<InvestmentInputScreen> {
  static const List<int> _presetAmounts = <int>[
    100,
    1000,
    10000,
    100000,
    1000000,
    5000000,
    10000000,
    50000000,
    100000000,
  ];

  final NumberFormat _formatter = NumberFormat('#,###');
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(investmentAmountProvider.notifier).setAmount(widget.flowState.investment);
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  String _formatWon(int value) => '${_formatter.format(value)}원';

  String _approxKorean(int value) {
    if (value >= 100000000) {
      return '약 ${(value / 100000000).toStringAsFixed(1)}억원';
    }
    if (value >= 10000) {
      return '약 ${(value / 10000).toStringAsFixed(0)}만원';
    }
    return '약 ${_formatter.format(value)}원';
  }

  void _onFineTuneTap(int delta) {
    ref.read(investmentAmountProvider.notifier).addAmount(delta);
  }

  void _startRepeat(int delta) {
    _onFineTuneTap(delta);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      ref.read(investmentAmountProvider.notifier).addAmount(delta);
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
  }

  Future<void> _showDirectInput(int currentAmount) async {
    final TextEditingController controller = TextEditingController(text: currentAmount.toString());
    final int? value = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF2A2A32),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('직접 입력', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '100 ~ 100,000,000',
                  hintStyle: TextStyle(color: Color(0x99FFFFFF)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text)),
                child: const Text('적용'),
              ),
            ],
          ),
        );
      },
    );

    if (value != null) {
      ref.read(investmentAmountProvider.notifier).setAmount(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int amount = ref.watch(investmentAmountProvider);
    final bool canStart = amount >= kMinInvestmentAmount && amount <= kMaxInvestmentAmount;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      appBar: AppBar(
        title: const Text('투자금 입력'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('초기 투자금을 입력하세요.', style: TextStyle(color: Color(0xFFA1A1A8))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A32),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatWon(amount),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _approxKorean(amount),
                    style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetAmounts.map((int preset) {
                final bool selected = amount == preset;
                return ChoiceChip(
                  label: Text(_formatWon(preset)),
                  selected: selected,
                  onSelected: (_) => ref.read(investmentAmountProvider.notifier).setAmount(preset),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFE5E5E7),
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: const Color(0xFF5677E7),
                  backgroundColor: const Color(0xFF2A2A32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: <int>[-100000, -10000, 10000, 100000].map((int delta) {
                final String label = delta > 0 ? '+${_formatter.format(delta)}' : '-${_formatter.format(delta.abs())}';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onLongPressStart: (_) => _startRepeat(delta),
                      onLongPressEnd: (_) => _stopRepeat(),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A32),
                          side: const BorderSide(color: Color(0xFF3A3A42)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _onFineTuneTap(delta),
                        child: Text(label, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            TextButton(
              onPressed: () => _showDirectInput(amount),
              child: const Text('직접 입력', style: TextStyle(color: Color(0xFFA1A1A8))),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5677E7),
                disabledBackgroundColor: const Color(0xFF3A3A42),
              ),
              onPressed: canStart
                  ? () {
                      widget.flowState.setInvestment(amount);
                      Navigator.of(context).push(
                        buildRightSlideRoute(
                          LoadingScreen(
                            repository: widget.repository,
                            flowState: widget.flowState,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('재생 시작', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
