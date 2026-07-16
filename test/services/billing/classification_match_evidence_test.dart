import 'package:beecount/services/billing/classification_match_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classification evidence uses merchant then counterparty then summary',
      () {
    expect(
      classificationMatchText(
        merchantFullName: ' 天津海河测试餐厅甲 ',
        counterparty: '候选对手方',
        structuredSummary: '商户：摘要商户',
      ),
      '天津海河测试餐厅甲',
    );
    expect(
      classificationMatchText(
        counterparty: ' 候选对手方 ',
        structuredSummary: '商户：摘要商户',
      ),
      '候选对手方',
    );
    expect(
      classificationMatchText(structuredSummary: '商户：摘要商户\n门店：A店'),
      '摘要商户',
    );
  });
}
