import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/features/game/state/chart_game_flow_state.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class ChartGameResultDialog extends StatelessWidget {
  const ChartGameResultDialog({
    super.key,
    required this.flow,
    required this.isWindowsGuest,
    required this.onRetry,
    required this.onClose,
  });

  final ChartGameFlowState flow;
  final bool isWindowsGuest;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  String _formatYmd(int ymd) {
    final String raw = ymd.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatSignedPercent(double value) {
    final String sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  String _formatSignedPoints(int value) {
    final String sign = value >= 0 ? '+' : '';
    return '$sign${AppNumberFormat.formatInt(value)}P';
  }

  @override
  Widget build(BuildContext context) {
    final double finalValue = flow.finalValue ?? flow.equityPoints;
    final double finalPnl = finalValue - flow.initialBetPoints;
    final int startYmd = flow.segment.isNotEmpty ? flow.segment.first.ymd : 0;
    final int endYmd = flow.segment.isNotEmpty ? flow.segment.last.ymd : 0;
    final double myReturn = flow.finalReturnPercent ?? 0;
    final double marketReturn = flow.marketReturnPercent ?? 0;
    final double relativeReturn = flow.relativeReturnPercent ?? 0;
    final int settlementDelta = flow.settlementDeltaPoints ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.helperText.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              flow.assetName ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '기간: 1년',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.helperText, fontSize: 12),
            ),
            if (startYmd > 0 && endYmd > 0)
              Text(
                '${_formatYmd(startYmd)} ~ ${_formatYmd(endYmd)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.helperText, fontSize: 12),
              ),
            const SizedBox(height: 10),
            Text(
              '베팅 포인트 ${AppNumberFormat.formatInt(flow.initialBetPoints)}P',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.helperText, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              '${AppNumberFormat.formatInt(finalValue)}P',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 8),
            _MetricLine(label: '내 수익률', value: _formatSignedPercent(myReturn)),
            const SizedBox(height: 4),
            _MetricLine(label: '시장 수익률', value: _formatSignedPercent(marketReturn)),
            const SizedBox(height: 4),
            _MetricLine(
              label: '상대 수익률',
              value: '${_formatSignedPercent(relativeReturn)} (정산: ${_formatSignedPoints(settlementDelta)})',
              valueColor: relativeReturn >= 0 ? AppColors.action : AppColors.downSegment,
            ),
            const SizedBox(height: 8),
            Text(
              '최종 손익 ${finalPnl >= 0 ? '+' : ''}${AppNumberFormat.formatInt(finalPnl)}P',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.helperText, fontSize: 12),
            ),
            if (isWindowsGuest)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '게스트 모드는 보상/기록 저장이 없어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.helperText, fontSize: 11),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(onPressed: onRetry, child: const Text('한판 더')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: onClose, child: const Text('닫기')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$label:',
            style: const TextStyle(color: AppColors.helperText, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
