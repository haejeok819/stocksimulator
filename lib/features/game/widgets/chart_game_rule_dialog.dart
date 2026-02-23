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
              '🏁 게임 규칙',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              '1) 시장 수익률 = 1년 구간의 시작가→끝가 수익률\n'
              '2) 내 수익률 = 매수/매도로 나온 최종 수익률\n'
              '3) 정산은 ‘상대 수익률’로 계산해요\n'
              '4) 상대 수익률 = 내 수익률 - 시장 수익률\n'
              '5) 상대 수익률만큼 포인트가 늘거나 줄어요\n'
              '6) 예: 시장 +8% / 내 +12% → 상대 +4% → +40P(베팅 1,000P 기준)',
              style: TextStyle(color: AppColors.helperText, fontSize: 13, height: 1.45),
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
