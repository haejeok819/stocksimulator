import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/screens/random_pick_screen.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';
import 'package:stocksimulator/features/game/state/game_point_providers.dart';
import 'package:stocksimulator/shared/services/game_point_service.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BetPointsInputScreen extends ConsumerStatefulWidget {
  const BetPointsInputScreen({
    super.key,
    required this.isWindowsGuest,
    required this.currentBalance,
  });

  final bool isWindowsGuest;
  final int currentBalance;

  @override
  ConsumerState<BetPointsInputScreen> createState() => _BetPointsInputScreenState();
}

class _BetPointsInputScreenState extends ConsumerState<BetPointsInputScreen> {
  static const List<int> _presets = <int>[100, 500, 1000, 3000, 5000, 10000];
  int _bet = 1000;
  bool _starting = false;

  bool get _insufficient => !widget.isWindowsGuest && _bet > widget.currentBalance;

  @override
  Widget build(BuildContext context) {
    final String balanceText = widget.isWindowsGuest
        ? '게스트 모드'
        : '${AppNumberFormat.formatInt(widget.currentBalance)}P';

    return Scaffold(
      appBar: AppBar(title: const Text('베팅')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  children: <Widget>[
                    BetBalanceCard(balanceText: balanceText),
                    const SizedBox(height: 14),
                    BetHeroCard(
                      betPoints: _bet,
                      isWindowsGuest: widget.isWindowsGuest,
                    ),
                    const SizedBox(height: 14),
                    BetPresetGrid(
                      presets: _presets,
                      selected: _bet,
                      onSelect: (int value) => _setBet(value),
                    ),
                    const SizedBox(height: 12),
                    BetStepper(
                      currentBet: _bet,
                      onAdd: () => _adjustBet(100),
                      onSub: () => _adjustBet(-100),
                    ),
                    const SizedBox(height: 12),
                    GuestModeNotice(
                      isWindowsGuest: widget.isWindowsGuest,
                      insufficient: _insufficient,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: PrimaryCTAButton(
                  loading: _starting,
                  enabled: !_insufficient,
                  onPressed: _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _adjustBet(int delta) {
    final int next = (_bet + delta).clamp(100, 1000000);
    _setBet(next);
  }

  void _setBet(int value) {
    if (value == _bet) return;
    setState(() => _bet = value);
  }

  Future<void> _start() async {
    if (_insufficient || _starting) return;
    setState(() => _starting = true);
    try {
      ref.read(chartGameFlowControllerProvider.notifier).setBetPoints(_bet);
      final bool isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (isMobile && !widget.isWindowsGuest) {
        await ref.read(gamePointControllerProvider.notifier).spendForBet(_bet);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'game_random_pick'),
          builder: (_) => const RandomPickScreen(),
        ),
      );
    } on InsufficientGamePointsException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('게임 포인트가 부족해요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했어요')));
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }
}

class BetBalanceCard extends StatelessWidget {
  const BetBalanceCard({super.key, required this.balanceText});

  final String balanceText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text('보유 포인트',
                style: TextStyle(color: AppColors.helperText, fontWeight: FontWeight.w600)),
          ),
          Text(balanceText,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
  }
}

class BetHeroCard extends StatelessWidget {
  const BetHeroCard({
    super.key,
    required this.betPoints,
    required this.isWindowsGuest,
  });

  final int betPoints;
  final bool isWindowsGuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[AppColors.action.withOpacity(0.25), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.action.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('이번 판 베팅',
              style: TextStyle(color: AppColors.helperText, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            key: ValueKey<int>(betPoints),
            tween: Tween<double>(begin: 0.96, end: 1),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            builder: (BuildContext context, double scale, Widget? child) {
              return Transform.scale(scale: scale, alignment: Alignment.centerLeft, child: child);
            },
            child: Text(
              '${AppNumberFormat.formatInt(betPoints)}P',
              style: const TextStyle(
                  color: Colors.white, fontSize: 38, height: 1.0, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isWindowsGuest ? '게스트 모드는 기록/보상 저장이 없어요.' : '승리 시 보상 +${AppNumberFormat.formatInt(betPoints)}P',
            style: const TextStyle(color: AppColors.helperText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class BetPresetGrid extends StatelessWidget {
  const BetPresetGrid({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelect,
  });

  final List<int> presets;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (BuildContext context, int index) {
        if (index >= presets.length) {
          return const SizedBox.shrink();
        }
        final int value = presets[index];
        final bool isSelected = selected == value;
        return _PresetCell(
          value: value,
          selected: isSelected,
          onTap: () {
            if (!kIsWeb) HapticFeedback.selectionClick();
            onSelect(value);
          },
        );
      },
    );
  }
}

class _PresetCell extends StatelessWidget {
  const _PresetCell({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: selected ? 1.03 : 1, end: selected ? 1.05 : 1),
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      builder: (BuildContext context, double scale, Widget? child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Material(
        color: selected ? AppColors.action : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.action : AppColors.helperText.withOpacity(0.35),
              ),
              boxShadow: selected
                  ? <BoxShadow>[BoxShadow(color: AppColors.action.withOpacity(0.32), blurRadius: 8)]
                  : null,
            ),
            child: Text(
              '${AppNumberFormat.formatInt(value)}P',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.helperText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BetStepper extends StatefulWidget {
  const BetStepper({
    super.key,
    required this.currentBet,
    required this.onAdd,
    required this.onSub,
  });

  final int currentBet;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  @override
  State<BetStepper> createState() => _BetStepperState();
}

class _BetStepperState extends State<BetStepper> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: widget.onSub,
            onLongStart: () => _startRepeat(widget.onSub),
            onLongEnd: _stopRepeat,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text('${AppNumberFormat.formatInt(widget.currentBet)}P',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 2),
                Text('100P 단위 조절',
                    style: TextStyle(
                        color: AppColors.helperText.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: widget.onAdd,
            onLongStart: () => _startRepeat(widget.onAdd),
            onLongEnd: _stopRepeat,
          ),
        ],
      ),
    );
  }

  void _startRepeat(VoidCallback action) {
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => action());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.onLongStart,
    required this.onLongEnd,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongStart;
  final VoidCallback onLongEnd;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onLongPressStart: (_) {
        setState(() => _pressed = true);
        widget.onLongStart();
      },
      onLongPressEnd: (_) {
        setState(() => _pressed = false);
        widget.onLongEnd();
      },
      child: Transform.scale(
        scale: _pressed ? 0.96 : 1,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton.filledTonal(
            onPressed: widget.onTap,
            icon: Icon(widget.icon, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background.withOpacity(0.6),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class GuestModeNotice extends StatelessWidget {
  const GuestModeNotice({
    super.key,
    required this.isWindowsGuest,
    required this.insufficient,
  });

  final bool isWindowsGuest;
  final bool insufficient;

  @override
  Widget build(BuildContext context) {
    if (isWindowsGuest) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.helperText.withOpacity(0.25)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: AppColors.helperText, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('게스트 모드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('포인트 기록/보상이 저장되지 않습니다.\n로그인하면 포인트를 누적할 수 있어요.', style: TextStyle(color: AppColors.helperText, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      insufficient ? '게임 포인트가 부족해요' : '베팅한 게임 포인트로 결과 보상을 계산해요',
      style: TextStyle(color: insufficient ? AppColors.upSegment : AppColors.helperText, fontSize: 12),
    );
  }
}

class PrimaryCTAButton extends StatefulWidget {
  const PrimaryCTAButton({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final bool loading;
  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  State<PrimaryCTAButton> createState() => _PrimaryCTAButtonState();
}

class _PrimaryCTAButtonState extends State<PrimaryCTAButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!widget.enabled || widget.loading) ? null : widget.onPressed,
            child: widget.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Text('⚡ 이 금액으로 시작하기', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
