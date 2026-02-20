import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';

void main() {
  test('calculateReturnPct uses (end/start-1)*100 formula', () {
    expect(calculateReturnPct(startValue: 100, endValue: 110), closeTo(10.0, 1e-9));
    expect(calculateReturnPct(startValue: 100, endValue: 90), closeTo(-10.0, 1e-9));
    expect(calculateReturnPct(startValue: 0, endValue: 120), 0);
  });
}
