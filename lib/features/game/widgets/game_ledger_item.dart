import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/shared/models/game_point_ledger_entry.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class GameLedgerItem extends StatelessWidget {
  const GameLedgerItem({super.key, required this.entry});

  final GamePointLedgerEntry entry;

  static const Map<String, String> _reasonToKorean = <String, String>{
    'WELCOME': '첫 로그인 보너스',
    'CHECKIN': '출석체크',
    'AD_REWARD': '광고 보상',
    'GAME_ENTRY': '게임 입장',
    'RETRY': '재도전',
    'BONUS': '보너스',
    'BET': '베팅',
  };

  @override
  Widget build(BuildContext context) {
    final String reasonLabel = _reasonToKorean[entry.reason] ?? entry.reason;
    final String deltaPrefix = entry.delta >= 0 ? '+' : '';
    final String deltaText = '$deltaPrefix${AppNumberFormat.formatInt(entry.delta)}P';
    final String dateText = entry.createdAt == null ? '-' : DateFormat('yyyy.MM.dd HH:mm').format(entry.createdAt!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(reasonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(dateText, style: const TextStyle(color: AppColors.helperText, fontSize: 12)),
              ],
            ),
          ),
          Text(deltaText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
