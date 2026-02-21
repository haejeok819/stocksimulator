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
    required this.aTitle,
    required this.aReturnText,
    required this.bTitle,
    required this.bReturnText,
    required this.periodText,
    required this.winnerText,
    required this.badgeText,
  });

  final String aTitle;
  final String aReturnText;
  final String bTitle;
  final String bReturnText;
  final String periodText;
  final String winnerText;
  final String badgeText;
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
    required String winnerText,
    required String periodText,
  }) {
    final List<String> templates = <String>[
      '같은 기간, 다른 선택은?\n$winnerText\n$periodText\n$appLink',
      '왜 나는 그때 안 샀을까…\n$winnerText\n$appLink',
      '다른 종목은 어땠을까?\n$winnerText\n$appLink',
    ];
    return _pickTemplate(templates);
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
