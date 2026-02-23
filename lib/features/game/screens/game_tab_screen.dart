import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/state/game_point_providers.dart';
import 'package:stocksimulator/features/game/widgets/game_ledger_item.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/models/game_point_ledger_entry.dart';
import 'package:stocksimulator/shared/models/game_wallet.dart';
import 'package:stocksimulator/shared/services/game_point_service.dart';
import 'package:stocksimulator/shared/utils/date_key.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class GameTabScreen extends ConsumerStatefulWidget {
  const GameTabScreen({super.key});

  @override
  ConsumerState<GameTabScreen> createState() => _GameTabScreenState();
}

class _GameTabScreenState extends ConsumerState<GameTabScreen> {
  bool _initTriggered = false;

  @override
  Widget build(BuildContext context) {
    final String? uid = ref.watch(authControllerProvider).user?.uid;
    final bool isLoggedIn = uid != null && uid.isNotEmpty;

    if (isLoggedIn && !_initTriggered) {
      _initTriggered = true;
      Future<void>.microtask(() async {
        try {
          await ref.read(gamePointControllerProvider.notifier).initIfNeeded();
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('네트워크 오류가 발생했어요')),
          );
        }
      });
    }

    if (!isLoggedIn) {
      _initTriggered = false;
    }

    final AsyncValue<GameWallet?> walletAsync = ref.watch(gameWalletProvider);
    final AsyncValue<List<GamePointLedgerEntry>> ledgerAsync = ref.watch(gameLedgerProvider);

    final GameWallet? wallet = walletAsync.valueOrNull;
    final bool isCheckingInToday = wallet?.lastCheckInDate == DateKey.kstYmd();

    return Scaffold(
      appBar: AppBar(title: const Text('게임')),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _WalletCard(isLoggedIn: isLoggedIn, wallet: wallet),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  label: isCheckingInToday ? '오늘 출석 완료' : '출석체크',
                  enabledVisual: isLoggedIn && !isCheckingInToday,
                  onTap: () => _onCheckInTap(isLoggedIn: isLoggedIn, isCheckingInToday: isCheckingInToday),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: '포인트 받기\n(광고)',
                  enabledVisual: isLoggedIn,
                  onTap: () => _onAdRewardTap(isLoggedIn: isLoggedIn),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onGameEntryTap(isLoggedIn: isLoggedIn),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('차트 게임 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('입장료 20P', style: TextStyle(color: AppColors.helperText)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('최근 내역', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          if (!isLoggedIn)
            _buildCompactPlaceholder('로그인 후 내역을 볼 수 있어요')
          else
            ledgerAsync.when(
              data: (List<GamePointLedgerEntry> entries) {
                if (entries.isEmpty) {
                  return _buildCompactPlaceholder('아직 내역이 없어요');
                }
                return Column(
                  children: entries
                      .map((GamePointLedgerEntry e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GameLedgerItem(entry: e),
                          ))
                      .toList(growable: false),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, __) => _buildCompactPlaceholder('네트워크 오류가 발생했어요'),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactPlaceholder(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.helperText)),
    );
  }

  Future<void> _onCheckInTap({required bool isLoggedIn, required bool isCheckingInToday}) async {
    if (!isLoggedIn) {
      _showMessage('로그인 후 이용할 수 있어요');
      return;
    }
    if (isCheckingInToday) {
      _showMessage('오늘은 이미 출석체크 했어요');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).checkIn();
      _showMessage('+${GamePointService.checkInReward}P 출석체크 완료!');
    } on AlreadyCheckedInException {
      _showMessage('오늘은 이미 출석체크 했어요');
    } catch (_) {
      _showMessage('네트워크 오류가 발생했어요');
    }
  }

  Future<void> _onAdRewardTap({required bool isLoggedIn}) async {
    if (!isLoggedIn) {
      _showMessage('로그인 후 이용할 수 있어요');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).claimAdReward();
      _showMessage('+${GamePointService.adRewardPoints}P 지급됐어요');
    } catch (_) {
      _showMessage('네트워크 오류가 발생했어요');
    }
  }

  Future<void> _onGameEntryTap({required bool isLoggedIn}) async {
    if (!isLoggedIn) {
      _showMessage('로그인 후 이용할 수 있어요');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).spendForGameEntry();
      _showMessage('차트 게임 준비중입니다');
    } on InsufficientGamePointsException {
      _showMessage('게임 포인트가 부족해요');
    } catch (_) {
      _showMessage('네트워크 오류가 발생했어요');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.isLoggedIn, required this.wallet});

  final bool isLoggedIn;
  final GameWallet? wallet;

  @override
  Widget build(BuildContext context) {
    final String balanceText = isLoggedIn ? '${AppNumberFormat.formatInt(wallet?.gamePoints ?? 0)}P' : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const Text('게임 포인트', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
              Text(balanceText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isLoggedIn ? '출석체크/광고 보상으로 포인트를 모아 게임에 입장해보세요.' : '로그인 후 포인트 기능을 이용할 수 있어요.',
            style: const TextStyle(color: AppColors.helperText),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.enabledVisual, required this.onTap});

  final String label;
  final bool enabledVisual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabledVisual ? AppColors.action : AppColors.surface,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
