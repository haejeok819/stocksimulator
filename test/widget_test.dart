import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/app/app.dart';

void main() {
  testWidgets('Main tabs and sim stock selector render', (WidgetTester tester) async {
    await tester.pumpWidget(const StockSimulatorApp());
    await tester.pumpAndSettle();

    expect(find.text('종목 선택'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('국내주식'), findsOneWidget);
    expect(find.text('금'), findsOneWidget);
    expect(find.text('환율'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsWidgets);
  });
}
