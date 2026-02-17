import 'package:flutter/material.dart';

class PlaybackDesignTokens {
  PlaybackDesignTokens._();

  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF272734), Color(0xFF1D1D25)],
  );

  static BoxDecoration chartStageDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: screenBackground,
    border: Border.all(color: const Color(0x1AFFFFFF)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 12,
        spreadRadius: 1,
      ),
    ],
  );

  static const TextStyle title = TextStyle(fontSize: 21, fontWeight: FontWeight.w800);
  static const TextStyle headlineNumber = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
  static const TextStyle primaryBody = TextStyle(fontSize: 14, color: Colors.white);
  static const TextStyle secondary = TextStyle(fontSize: 13, color: Color(0xFFA1A1A8));

  static BoxDecoration playButtonDecoration({required bool active}) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(colors: <Color>[Color(0xFF5677E7), Color(0xFF7593F5)]),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF5677E7).withOpacity(active ? 0.5 : 0.25),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ],
    );
  }
}
