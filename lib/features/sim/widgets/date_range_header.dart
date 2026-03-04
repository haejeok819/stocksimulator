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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double dateFontSize = (constraints.maxWidth * 0.09).clamp(21.0, 32.0);
        final double arrowFontSize = (dateFontSize - 2).clamp(18.0, 30.0);

        return Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: dateFontSize * 1.25,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        start,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: dateFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FadeTransition(
                  opacity: animation,
                  child: Text(
                    '→',
                    style: TextStyle(
                      color: const Color(0xFF5677E7),
                      fontSize: arrowFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: dateFontSize * 1.25,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        end,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: dateFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
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
      },
    );
  }
}
