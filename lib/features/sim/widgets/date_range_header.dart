import 'package:flutter/material.dart';

class DateRangeHeader extends StatelessWidget {
  const DateRangeHeader({
    super.key,
    required this.start,
    required this.end,
    required this.tradingDayCount,
    required this.animation,
  });

  final String start;
  final String end;
  final int tradingDayCount;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              start,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            FadeTransition(
              opacity: animation,
              child: const Text(
                '→',
                style: TextStyle(
                  color: Color(0xFF5677E7),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: tradingDayCount),
          duration: const Duration(milliseconds: 550),
          builder: (BuildContext context, int value, _) {
            return Text(
              '총 $value 거래일',
              style: const TextStyle(
                color: Color(0xFFA1A1A8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }
}
