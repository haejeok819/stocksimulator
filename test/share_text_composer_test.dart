import 'package:flutter_test/flutter_test.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

void main() {
  test('simulation share text contains app link and line breaks', () {
    final String text = ShareTextComposer.simulation(
      assetName: '삼성전자',
      percentReturn: '+12.40%',
      initialValue: '투자금 1,000,000원',
      finalValue: '최종 1,124,000원',
      dateRange: '2020.01.01 ~ 2020.12.31',
    );

    expect(text, contains(ShareTextComposer.appLink));
    expect(text, contains('\n'));
  });

  test('battle share text contains app link and remains short', () {
    final String text = ShareTextComposer.battle(
      assetAName: '삼성전자',
      assetBName: '현대차',
      assetAReturn: '+24.10%',
      assetBReturn: '+10.20%',
      winnerLabel: '삼성전자 승',
    );

    expect(text, contains(ShareTextComposer.appLink));
    expect(text.length, lessThanOrEqualTo(240));
  });
}
