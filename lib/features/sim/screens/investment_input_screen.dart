import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/loading_screen.dart';
import 'package:stocksimulator/features/sim/state/investment_amount_provider.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

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

  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int initialAmount = widget.flowState.investMode == InvestMode.dca
          ? widget.flowState.dcaAmountPerTrade
          : widget.flowState.investment;
      ref.read(investmentAmountProvider.notifier).setAmount(initialAmount);
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  String _formatWon(int value) => AppNumberFormat.formatKoreanSpokenWon(value);

  String _presetLabel(int value) => _formatWon(value);

  String _approxKorean(int value) => AppNumberFormat.formatApproxKoreanSpokenWon(value);

  String _deltaLabel(int delta) {
    final String sign = delta >= 0 ? '+' : '-';
    return '$sign${AppNumberFormat.formatKoreanSpokenWon(delta.abs())}';
  }

  void _onFineTuneTap(int delta) {
    ref.read(investmentAmountProvider.notifier).addAmount(delta);
  }

  void _startRepeat(int delta) {
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 6),
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
                    const Text('빠른 선택', style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _presetAmounts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 3.0,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final int preset = _presetAmounts[index];
                        final bool selected = amount == preset;
                        return _PresetChip(
                          label: _presetLabel(preset),
                          selected: selected,
                          onTap: () => ref.read(investmentAmountProvider.notifier).setAmount(preset),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text('미세 조정', style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: <int>[-100000, -10000, 10000, 100000].map((int delta) {
                        final String label = _deltaLabel(delta);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _FineTuneButton(
                              label: label,
                              onTap: () => _onFineTuneTap(delta),
                              onRepeatStart: () => _startRepeat(delta),
                              onRepeatStop: _stopRepeat,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _showDirectInput(amount),
                      child: const Text('직접 입력', style: TextStyle(color: Color(0xFFA1A1A8), fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5677E7),
                  disabledBackgroundColor: const Color(0xFF3A3A42),
                ),
                onPressed: canStart
                    ? () {
                        if (widget.flowState.investMode == InvestMode.dca) {
                          widget.flowState.setDcaAmountPerTrade(amount);
                        } else {
                          widget.flowState.setInvestment(amount);
                        }
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
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF5677E7) : const Color(0xFF2A2A32),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFF3A3A42), width: 1),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double adaptiveFontSize = (constraints.maxWidth * 0.16).clamp(10.5, 14.0);
              return SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: adaptiveFontSize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FineTuneButton extends StatelessWidget {
  const _FineTuneButton({
    required this.label,
    required this.onTap,
    required this.onRepeatStart,
    required this.onRepeatStop,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRepeatStart;
  final VoidCallback onRepeatStop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Material(
        color: const Color(0xFF2A2A32),
        borderRadius: BorderRadius.circular(16),
        child: Listener(
          onPointerUp: (_) => onRepeatStop(),
          onPointerCancel: (_) => onRepeatStop(),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onRepeatStart,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3A3A42)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
