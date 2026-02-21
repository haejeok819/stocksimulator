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
