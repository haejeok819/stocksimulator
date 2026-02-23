import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/screens/bet_points_input_screen.dart';
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
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final bool canGuestPlay = isWindows && !isLoggedIn;

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

    final AsyncValue<void> actionState = ref.watch(gamePointControllerProvider);
    final bool isActionLoading = actionState.isLoading;
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
          _WalletCard(isLoggedIn: isLoggedIn, isWindowsGuest: canGuestPlay, wallet: wallet),
          if (canGuestPlay) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Windows 게스트 모드에서는 포인트/내역 기능 없이 차트 게임만 이용할 수 있어요.',
              style: TextStyle(color: AppColors.helperText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  isPrimary: true,
                  title: isCheckingInToday ? '오늘 출석 완료' : '출석체크',
                  subtitle: '+${GamePointService.checkInReward}P',
                  icon: Icons.check_rounded,
                  enabledVisual: isLoggedIn,
                  disabledKeepPrimaryTone: isCheckingInToday,
                  showLock: !isLoggedIn,
                  isLoading: isActionLoading,
                  onTap: () => _onCheckInTap(isLoggedIn: isLoggedIn, isCheckingInToday: isCheckingInToday),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  isPrimary: false,
                  title: '포인트 받기',
                  subtitle: isWindows && !isLoggedIn ? '모바일 로그인 후 이용' : '광고 시청 +${GamePointService.adRewardPoints}P',
                  icon: Icons.play_circle_outline_rounded,
                  enabledVisual: isLoggedIn,
                  showLock: !isLoggedIn,
                  isLoading: isActionLoading,
                  onTap: () => _onAdRewardTap(isLoggedIn: isLoggedIn, isWindows: isWindows),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GameEntryCard(
            canUsePoints: isLoggedIn,
            isWindowsGuest: canGuestPlay,
            isLoading: isActionLoading,
            onTap: () => _onGameEntryTap(isLoggedIn: isLoggedIn, isWindowsGuest: canGuestPlay),
          ),
          const SizedBox(height: 20),
          const Text('최근 내역', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          if (!isLoggedIn)
            _buildCompactPlaceholder(
              isWindows ? '모바일 로그인 후 내역을 볼 수 있어요\n게스트 모드에서는 내역이 저장되지 않아요' : '로그인 후 내역을 볼 수 있어요',
            )
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

  Future<void> _onAdRewardTap({required bool isLoggedIn, required bool isWindows}) async {
    if (!isLoggedIn) {
      _showMessage(isWindows ? '모바일 로그인 후 이용할 수 있어요' : '로그인 후 이용할 수 있어요');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).claimAdReward();
      _showMessage('+${GamePointService.adRewardPoints}P 지급됐어요');
    } catch (_) {
      _showMessage('네트워크 오류가 발생했어요');
    }
  }

  Future<void> _onGameEntryTap({required bool isLoggedIn, required bool isWindowsGuest}) async {
    if (!isLoggedIn && !isWindowsGuest) {
      _showMessage('로그인 후 이용할 수 있어요');
      return;
    }

    final int currentBalance = ref.read(gameWalletProvider).valueOrNull?.gamePoints ?? 0;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'game_bet'),
        builder: (_) => BetPointsInputScreen(
          isWindowsGuest: isWindowsGuest,
          currentBalance: currentBalance,
        ),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.isLoggedIn, required this.isWindowsGuest, required this.wallet});

  final bool isLoggedIn;
  final bool isWindowsGuest;
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
            isWindowsGuest
                ? '게스트 모드에서는 포인트 적립/소모 없이 무료로 차트 게임을 시작할 수 있어요.'
                : isLoggedIn
                    ? '출석체크/광고 보상으로 포인트를 모아 게임에 입장해보세요.'
                    : '로그인 후 포인트 기능을 이용할 수 있어요.',
            style: const TextStyle(color: AppColors.helperText),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isPrimary,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabledVisual,
    required this.onTap,
    this.showLock = false,
    this.isLoading = false,
    this.disabledKeepPrimaryTone = false,
  });

  final bool isPrimary;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabledVisual;
  final bool showLock;
  final bool isLoading;
  final bool disabledKeepPrimaryTone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool visuallyEnabled = enabledVisual && !isLoading;
    final Color background = isPrimary
        ? (visuallyEnabled
            ? AppColors.action
            : (disabledKeepPrimaryTone ? AppColors.action.withOpacity(0.65) : AppColors.surface))
        : AppColors.surface;

    final BorderSide borderSide = isPrimary
        ? BorderSide.none
        : BorderSide(color: AppColors.helperText.withOpacity(visuallyEnabled ? 0.35 : 0.22));

    return SizedBox(
      height: 54,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(15),
            border: Border.fromBorderSide(borderSide),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                else
                  Icon(showLock ? Icons.lock_outline_rounded : icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.helperText.withOpacity(0.92), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameEntryCard extends StatelessWidget {
  const _GameEntryCard({
    required this.canUsePoints,
    required this.isWindowsGuest,
    required this.onTap,
    required this.isLoading,
  });

  final bool canUsePoints;
  final bool isWindowsGuest;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String chipText = isWindowsGuest ? '게스트 모드 무료' : '입장료 ${GamePointService.gameEntryCost}P';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.helperText.withOpacity(0.18)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text('차트 게임 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (!canUsePoints && !isWindowsGuest) ...<Widget>[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.helperText),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.helperText.withOpacity(0.25)),
                    ),
                    child: Text(chipText, style: const TextStyle(color: AppColors.helperText, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isWindowsGuest ? '게스트 플레이는 결과가 저장되지 않아요' : '베팅 게임 포인트를 입력하고 시작해요',
                    style: const TextStyle(color: AppColors.helperText, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.helperText),
          ],
        ),
      ),
    );
  }
}
