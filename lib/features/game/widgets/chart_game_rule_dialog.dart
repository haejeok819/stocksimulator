import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';

class ChartGameRuleDialog extends StatelessWidget {
  const ChartGameRuleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.helperText.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '🎮 ️게임 규칙',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              '시장 수익률은 1년 기간 시작가→종가 수익률입니다.\n\n'
                  '내 수익률과 시장 수익률을 비교해\n'
                  '차이(상대 수익률)만큼 정산합니다.\n\n'
                  '✔ 시장보다 더 벌면 → 그 초과분만큼 획득\n'
                  '✖ 시장보다 못 벌면 → 그 부족분만큼 차감\n\n'
                  '예) 시장 +8% / 플레이어 +12%\n'
                  '→ +4% 차이 → 40P 획득 (베팅 1,000P 기준)',
              style: TextStyle(
                color: AppColors.helperText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
