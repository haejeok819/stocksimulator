import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/screens/bet_points_input_screen.dart';
import 'package:stocksimulator/features/game/state/game_point_providers.dart';
import 'package:stocksimulator/features/game/widgets/chart_game_rule_dialog.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
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
    final bool isWindowsGuest = isWindows && !isLoggedIn;

    if (isLoggedIn && !_initTriggered) {
      _initTriggered = true;
      Future<void>.microtask(() async {
        try {
          await ref.read(gamePointControllerProvider.notifier).initIfNeeded();
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_resolveActionErrorMessage(error))));
        }
      });
    }
    if (!isLoggedIn) _initTriggered = false;

    final AsyncValue<void> actionState = ref.watch(gamePointControllerProvider);
    final bool isActionLoading = actionState.isLoading;
    final GameWallet? wallet = ref.watch(gameWalletProvider).valueOrNull;
    final bool isCheckingInToday = wallet?.lastCheckInDate == DateKey.kstYmd();
    final bool hasPermissionIssue = actionState.hasError &&
        actionState.error.toString().contains('permission-denied');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: <Widget>[
            _HeaderRow(
              pointsText: isLoggedIn ? '${AppNumberFormat.formatInt(wallet?.gamePoints ?? 0)}P' : '—',
              isWindowsGuest: isWindowsGuest,
            ),
            const SizedBox(height: 20),
            _PointSummaryCard(
              pointsText: isLoggedIn ? '${AppNumberFormat.formatInt(wallet?.gamePoints ?? 0)}P' : '—',
              isLoggedIn: isLoggedIn,
              isWindowsGuest: isWindowsGuest,
              isActionLoading: isActionLoading,
              isCheckingInToday: isCheckingInToday,
              onCheckInTap: () => _onCheckInTap(
                isLoggedIn: isLoggedIn,
                isCheckingInToday: isCheckingInToday,
              ),
              onAdTap: () => _onAdRewardTap(isLoggedIn: isLoggedIn, isWindows: isWindows),
            ),
            if (hasPermissionIssue)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.upSegment.withOpacity(0.45)),
                ),
                child: const Text(
                  '권한 오류가 감지됐어요. docs/firebase_google_login_setup.md 의 Firestore Rules 3) 항목을 적용해주세요.',
                  style: TextStyle(color: AppColors.helperText, fontSize: 12, height: 1.35),
                ),
              ),
            const SizedBox(height: 18),
            _ChartGameCtaCard(
              isWindowsGuest: isWindowsGuest,
              isLoggedIn: isLoggedIn,
              onTap: () => _onGameEntryTap(isLoggedIn: isLoggedIn, isWindowsGuest: isWindowsGuest),
            ),
            const SizedBox(height: 18),
            GameRuleSummaryCard(onTap: _showRuleDialog),
          ],
        ),
      ),
    );
  }

  Future<void> _onCheckInTap({required bool isLoggedIn, required bool isCheckingInToday}) async {
    if (!isLoggedIn) {
      _showMessage('로그인 후 이용할 수 있어요');
      return;
    }
    if (isCheckingInToday) {
      _showMessage('출석체크 완료 !');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).checkIn();
      _showMessage('+${GamePointService.checkInReward}P 출석체크 완료!');
    } on AlreadyCheckedInException {
      _showMessage('출석체크 완료 !');
    } catch (error) {
      _showMessage(_resolveActionErrorMessage(error));
    }
  }

  Future<void> _onAdRewardTap({required bool isLoggedIn, required bool isWindows}) async {
    if (!isLoggedIn) {
      _showMessage(isWindows ? '모바일 로그인 후 이용할 수 있어요' : '로그인 후 이용할 수 있어요');
      return;
    }
    try {
      await ref.read(gamePointControllerProvider.notifier).claimAdReward();
      _showMessage('+${GamePointService.adRewardPoints}P가 지급됐어요');
    } catch (error) {
      _showMessage(_resolveActionErrorMessage(error));
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


  Future<void> _showRuleDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ChartGameRuleDialog(),
    );
  }

  String _resolveActionErrorMessage(Object error) {
    if (error is AlreadyCheckedInException) return '출석체크 완료 !';
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return '권한 오류: Firestore Rules에서 users/{uid} 및 game_point_ledger 쓰기 권한을 허용해주세요';
      }
      if (error.code == 'unauthenticated') return '로그인이 만료됐어요. 다시 로그인해주세요';
      if (error.code == 'unavailable') return '네트워크 상태를 확인해주세요';
    }
    final String text = error.toString();
    if (text.contains('permission-denied')) {
      return '권한 오류: Firestore Rules에서 users/{uid} 및 game_point_ledger 쓰기 권한을 허용해주세요';
    }
    if (text.contains('로그인 후 이용할 수 있어요')) return '로그인 후 이용할 수 있어요';
    return '네트워크 오류가 발생했어요';
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.pointsText, required this.isWindowsGuest});

  final String pointsText;
  final bool isWindowsGuest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            '게임',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 30),
          ),
        ),
        if (isWindowsGuest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.helperText.withOpacity(0.35)),
            ),
            child: const Text('게스트 모드', style: TextStyle(color: AppColors.helperText, fontSize: 11)),
          ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.helperText.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.monetization_on_rounded, color: AppColors.action.withOpacity(0.95), size: 16),
              const SizedBox(width: 4),
              Text(pointsText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointSummaryCard extends StatelessWidget {
  const _PointSummaryCard({
    required this.pointsText,
    required this.isLoggedIn,
    required this.isWindowsGuest,
    required this.isActionLoading,
    required this.isCheckingInToday,
    required this.onCheckInTap,
    required this.onAdTap,
  });

  final String pointsText;
  final bool isLoggedIn;
  final bool isWindowsGuest;
  final bool isActionLoading;
  final bool isCheckingInToday;
  final VoidCallback onCheckInTap;
  final VoidCallback onAdTap;

  @override
  Widget build(BuildContext context) {
    final String helper = isWindowsGuest
        ? '게스트 모드는 포인트 적립/저장이 되지 않습니다.'
        : '차트 게임에서 사용되는 포인트입니다.';

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('게임 포인트', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(pointsText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 27)),
            ],
          ),
          const SizedBox(height: 8),
          Text(helper, style: const TextStyle(color: AppColors.helperText, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniOutlineButton(
                  icon: Icons.check_rounded,
                  label: isCheckingInToday ? '오늘 출석 완료' : '출석체크',
                  enabled: isLoggedIn && !isCheckingInToday,
                  loading: isActionLoading,
                  onTap: onCheckInTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniOutlineButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: '포인트 받기',
                  enabled: isLoggedIn,
                  loading: isActionLoading,
                  onTap: onAdTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniOutlineButton extends StatelessWidget {
  const _MiniOutlineButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(enabled ? icon : Icons.lock_outline_rounded, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: AppColors.helperText.withOpacity(enabled ? 0.35 : 0.2)),
          backgroundColor: enabled ? AppColors.background.withOpacity(0.35) : AppColors.background.withOpacity(0.2),
        ),
      ),
    );
  }
}

class _ChartGameCtaCard extends StatelessWidget {
  const _ChartGameCtaCard({
    required this.isWindowsGuest,
    required this.isLoggedIn,
    required this.onTap,
  });

  final bool isWindowsGuest;
  final bool isLoggedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: <Color>[AppColors.action.withOpacity(0.35), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: AppColors.action.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Text('차트 게임', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
            const SizedBox(height: 10),
            const Text('차트 게임 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19)),
            const SizedBox(height: 12),
            if (isWindowsGuest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.helperText.withOpacity(0.28)),
                ),
                child: const Text('게스트 무료', style: TextStyle(color: AppColors.helperText, fontSize: 12)),
              )
            else
              Text(
                isLoggedIn ? '베팅 후 시작' : '로그인 후 이용 가능',
                style: const TextStyle(color: AppColors.helperText, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}


class GameRuleSummaryCard extends StatelessWidget {
  const GameRuleSummaryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '게임 규칙',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.helperText.withOpacity(0.95)),
            ],
          ),
        ),
      ),
    );
  }
}
