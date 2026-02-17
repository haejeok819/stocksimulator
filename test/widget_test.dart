import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/app/app.dart';

void main() {
  testWidgets('Main tabs and sim stock selector render', (WidgetTester tester) async {
    await tester.pumpWidget(const StockSimulatorApp());

    expect(find.text('종목 선택'), findsOneWidget);
    expect(find.text('US'), findsOneWidget);
    expect(find.text('KR'), findsOneWidget);
    expect(find.text('Top100'), findsOneWidget);
    expect(find.text('종목명/심볼 검색'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsWidgets);
  });
}
