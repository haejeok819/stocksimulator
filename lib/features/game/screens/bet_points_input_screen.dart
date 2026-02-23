import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/screens/random_pick_screen.dart';
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
    final String balanceLabel = widget.isWindowsGuest ? '게스트 모드' : '보유 ${AppNumberFormat.formatInt(widget.currentBalance)}P';
    return Scaffold(
      appBar: AppBar(title: const Text('베팅')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('베팅 게임 포인트', style: TextStyle(color: AppColors.helperText)),
            const SizedBox(height: 6),
            Text(balanceLabel, style: const TextStyle(color: AppColors.helperText, fontSize: 12)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '${AppNumberFormat.formatInt(_bet)}P',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map(
                    (int value) => ChoiceChip(
                      selected: _bet == value,
                      label: Text('${AppNumberFormat.formatInt(value)}P'),
                      onSelected: (_) => setState(() => _bet = value),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _bet = (_bet - 100).clamp(100, 1000000)),
                    child: const Text('-100P'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _bet += 100),
                    child: const Text('+100P'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _insufficient ? '게임 포인트가 부족해요' : (widget.isWindowsGuest ? '게스트 모드는 기록/보상 저장이 없어요' : '베팅한 게임 포인트로 결과 보상을 계산해요'),
              style: TextStyle(color: _insufficient ? AppColors.upSegment : AppColors.helperText),
            ),
            const Spacer(),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_insufficient || _starting) ? null : _start,
                child: _starting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Text('게임 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      if (!widget.isWindowsGuest) {
        await ref.read(gamePointControllerProvider.notifier).spendForBet(_bet);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'game_random_pick'),
          builder: (_) => RandomPickScreen(betPoints: _bet, isWindowsGuest: widget.isWindowsGuest),
        ),
      );
    } on InsufficientGamePointsException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게임 포인트가 부족해요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했어요')));
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }
}
