import 'dart:math';

class SimulationSharePayload {
  const SimulationSharePayload({
    required this.title,
    required this.periodText,
    required this.investText,
    required this.finalText,
    required this.returnText,
    required this.badgeText,
  });

  final String title;
  final String periodText;
  final String investText;
  final String finalText;
  final String returnText;
  final String badgeText;
}

class BattleSharePayload {
  const BattleSharePayload({
    required this.assetAName,
    required this.assetBName,
    required this.assetAReturnText,
    required this.assetBReturnText,
    required this.initialInvestmentText,
    required this.finalValueAText,
    required this.finalValueBText,
    required this.periodText,
    required this.winnerLabel,
    required this.deltaText,
    required this.badgeText,
    required this.curiosityLine,
    required this.seriesA,
    required this.seriesB,
    required this.aWon,
    required this.isTie,
    this.shortIntersectionNotice = false,
  });

  final String assetAName;
  final String assetBName;
  final String assetAReturnText;
  final String assetBReturnText;
  final String initialInvestmentText;
  final String finalValueAText;
  final String finalValueBText;
  final String periodText;
  final String winnerLabel;
  final String deltaText;
  final String badgeText;
  final String curiosityLine;
  final List<double> seriesA;
  final List<double> seriesB;
  final bool aWon;
  final bool isTie;
  final bool shortIntersectionNotice;
}

class ShareTextComposer {
  const ShareTextComposer._();

  static const String appLink =
      'https://play.google.com/store/apps/details?id=com.motorstock.stocksimulator';
  static const int _softMaxChars = 240;

  static String simulation({
    required String assetName,
    required String percentReturn,
    required String initialValue,
    required String finalValue,
    required String dateRange,
  }) {
    final List<String> templates = <String>[
      '그때 샀다면… $assetName $percentReturn\n앱에서 직접 해보기 👇\n$appLink',
      '$assetName $dateRange\n결과: $percentReturn ($initialValue→$finalValue)\n$appLink',
      '같은 기간, 다른 선택은?\n$assetName $percentReturn\n$appLink',
      '이 날 100만원 넣었다면?\n$assetName $percentReturn\n$appLink',
      '왜 나는 그때 안 샀을까…\n$assetName $percentReturn\n$appLink',
      '다른 종목은 어땠을까?\n$assetName $percentReturn\n$appLink',
    ];

    return _pickTemplate(templates);
  }

  static String battle({
    required String assetAName,
    required String assetBName,
    required String assetAReturn,
    required String assetBReturn,
    required String winnerLabel,
  }) {
    final List<String> templates = <String>[
      '$assetAName vs $assetBName\n승자: $winnerLabel\n$assetAReturn vs $assetBReturn\n앱에서 직접 해보기 👇\n$appLink',
      '같은 기간, 선택이 갈렸다\n$assetAName $assetAReturn\n$assetBName $assetBReturn\n$appLink',
      '너라면 뭐 샀어?\n$assetAName vs $assetBName\n결과 공유함👇\n$appLink',
    ];
    return _pickTemplate(templates);
  }

  static String randomCuriosityLine() {
    const List<String> candidates = <String>[
      '너라면 뭐 골라?',
      '같은 기간, 승자는 누구였을까?',
      '금이랑 달러도 붙여볼까?',
    ];
    return candidates[Random().nextInt(candidates.length)];
  }

  static String _pickTemplate(List<String> templates) {
    final List<String> withinLimit =
        templates.where((String text) => text.length <= _softMaxChars).toList();
    final List<String> target = withinLimit.isNotEmpty ? withinLimit : templates;
    final int index = Random().nextInt(target.length);
    final String selected = target[index];

    if (selected.length <= _softMaxChars) {
      return selected;
    }

    const String ellipsis = '...';
    final int trimLength = _softMaxChars - appLink.length - ellipsis.length - 1;
    final String trimmedBody = selected.substring(0, max(0, trimLength));
    return '$trimmedBody$ellipsis\n$appLink';
  }
}
