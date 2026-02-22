import 'package:stocksimulator/shared/share/share_payload.dart';

class ShareTextTemplates {
  const ShareTextTemplates._();

  static String simulation({
    required String assetName,
    required String percentReturn,
    required String initialValue,
    required String finalValue,
    required String dateRange,
  }) {
    return ShareTextComposer.simulation(
      assetName: assetName,
      percentReturn: percentReturn,
      initialValue: initialValue,
      finalValue: finalValue,
      dateRange: dateRange,
    );
  }

  static String battle({
    required String assetAName,
    required String assetBName,
    required String assetAReturn,
    required String assetBReturn,
    required String winnerLabel,
  }) {
    return ShareTextComposer.battle(
      assetAName: assetAName,
      assetBName: assetBName,
      assetAReturn: assetAReturn,
      assetBReturn: assetBReturn,
      winnerLabel: winnerLabel,
    );
  }
}
