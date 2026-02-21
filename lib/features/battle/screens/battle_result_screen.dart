import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';
import 'package:stocksimulator/features/records/models/attempt_record.dart';
import 'package:stocksimulator/features/records/state/records_providers.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/share/services/share_service.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';
import 'package:stocksimulator/shared/share/widgets/share_card.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class BattleResultScreen extends ConsumerStatefulWidget {
  const BattleResultScreen({super.key});

  @override
  ConsumerState<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends ConsumerState<BattleResultScreen> {
  bool _saved = false;

  static const double _tieEpsilonPct = 0.01;
  String _fmt(double value) => AppNumberFormat.formatInt(value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_saved) return;
    _saved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveRecordIfSignedIn();
    });
  }

  Future<void> _saveRecordIfSignedIn() async {
    final BattleSetupState setup = ref.read(battleSetupProvider);
    final BattleResultState? result = ref.read(battleResultProvider);
    if (result == null) return;

    final String? uid = ref.read(authControllerProvider).user?.uid;
    if (uid == null || uid.isEmpty) return;

    await ref.read(recordsControllerProvider).addRecord(
      AttemptRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        uid: uid,
        mode: 'BATTLE',
        tickerA: setup.stockA?.ticker ?? '',
        nameA: _koreanName(setup.stockA),
        tickerB: setup.stockB?.ticker ?? '',
        nameB: _koreanName(setup.stockB),
        startYmd: DateFormat('yyyyMMdd').format(setup.startDate),
        endYmd: DateFormat('yyyyMMdd').format(setup.endDate),
        returnPctA: result.finalReturnA,
        returnPctB: result.finalReturnB,
        createdAtIso: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BattleSetupState setup = ref.watch(battleSetupProvider);
    final BattleResultState? result = ref.watch(battleResultProvider);
    final AsyncValue<BattleSeriesData> dataAsync = ref.watch(battleDataProvider);
    final bool shareEnabled = result != null && dataAsync.hasValue && _canShare(dataAsync.value);

    if (result == null) {
      return const Scaffold(body: Center(child: Text('결과가 없습니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Result'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: shareEnabled ? () => _openShareBottomSheet(context: context, setup: setup, result: result, data: dataAsync.value!) : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: <Widget>[
                  Text('🏆 ${_winnerLabel(result)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _resultRow('A', _koreanName(setup.stockA), result.finalValueA, result.finalReturnA),
                  const SizedBox(height: 8),
                  _resultRow('B', _koreanName(setup.stockB), result.finalValueB, result.finalReturnB),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: shareEnabled
                    ? () => _openShareBottomSheet(context: context, setup: setup, result: result, data: dataAsync.value!)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유할 대결 데이터가 부족해요. 다시 시도해주세요.')),
                        );
                      },
                icon: const Icon(Icons.share),
                label: const Text('결과 공유하기'),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(battleDataProvider);
                Navigator.of(context).pop();
              },
              child: const Text('다시하기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
              child: const Text('설정으로'),
            ),
          ],
        ),
      ),
    );
  }

  bool _canShare(BattleSeriesData? data) {
    if (data == null) return false;
    return data.valuesA.length > 1 && data.valuesB.length > 1;
  }

  Future<void> _openShareBottomSheet({
    required BuildContext context,
    required BattleSetupState setup,
    required BattleResultState result,
    required BattleSeriesData data,
  }) async {
    if (!_canShare(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유할 대결 데이터가 부족해요.')),
      );
      return;
    }

    final GlobalKey boundaryKey = GlobalKey();
    final ShareService shareService = const ShareService();
    final BattleSharePayload payload = _buildBattleSharePayload(setup: setup, result: result, data: data);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B22),
      builder: (BuildContext sheetContext) {
        bool isSharing = false;
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            Future<void> onSharePressed() async {
              setModalState(() {
                isSharing = true;
              });
              try {
                await shareService.shareBattleCard(boundaryKey, payload);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유에 실패했습니다. 다시 시도해주세요.')));
                }
              } finally {
                if (context.mounted) {
                  setModalState(() {
                    isSharing = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BattleShareCard(boundaryKey: boundaryKey, payload: payload),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSharing ? null : onSharePressed,
                        icon: isSharing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.share),
                        label: const Text('공유하기'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  BattleSharePayload _buildBattleSharePayload({
    required BattleSetupState setup,
    required BattleResultState result,
    required BattleSeriesData data,
  }) {
    final String aName = _koreanName(setup.stockA);
    final String bName = _koreanName(setup.stockB);
    final double delta = result.finalReturnA - result.finalReturnB;
    final bool isTie = delta.abs() <= _tieEpsilonPct;
    final bool aWon = delta > _tieEpsilonPct;
    final String winnerLabel = isTie ? '무승부' : (aWon ? '$aName 승' : '$bName 승');
    final int startYmd = data.normalized.dates.first;
    final int endYmd = data.normalized.dates.last;
    final String periodText = '${_formatYmd(startYmd)} ~ ${_formatYmd(endYmd)}';
    final String deltaLabel = isTie ? '무승부 (차이 ${delta.abs().toStringAsFixed(2)}%p)' : '차이 ${delta.abs().toStringAsFixed(2)}%p';

    return BattleSharePayload(
      assetAName: aName,
      assetBName: bName,
      assetAReturnText: AppNumberFormat.formatPercent(result.finalReturnA),
      assetBReturnText: AppNumberFormat.formatPercent(result.finalReturnB),
      initialInvestmentText: '초기 ${AppNumberFormat.formatMoney(setup.investAmount)}',
      finalValueAText: '최종 ${AppNumberFormat.formatMoney(result.finalValueA.round())}',
      finalValueBText: '최종 ${AppNumberFormat.formatMoney(result.finalValueB.round())}',
      periodText: periodText,
      winnerLabel: winnerLabel,
      deltaText: deltaLabel,
      badgeText: 'BATTLE 결과',
      curiosityLine: ShareTextComposer.randomCuriosityLine(),
      seriesA: data.valuesA,
      seriesB: data.valuesB,
      aWon: aWon,
      isTie: isTie,
      shortIntersectionNotice: data.length < 45,
    );
  }

  String _winnerLabel(BattleResultState result) {
    final double delta = result.finalReturnA - result.finalReturnB;
    if (delta.abs() <= _tieEpsilonPct) {
      return '무승부';
    }
    return result.winner;
  }

  String _formatYmd(int ymd) {
    final String s = ymd.toString().padLeft(8, '0');
    return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
  }

  String _koreanName(StockModel? stock) {
    if (stock == null) return '-';
    if (stock.nameKo.trim().isNotEmpty) return stock.nameKo.trim();
    return stock.displayName;
  }

  Widget _resultRow(String label, String ticker, double finalValue, double finalRate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('$label · $ticker'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('${_fmt(finalValue)}원'),
            Text('수익률 ${AppNumberFormat.formatPercent(finalRate)}'),
          ],
        ),
      ],
    );
  }
}
