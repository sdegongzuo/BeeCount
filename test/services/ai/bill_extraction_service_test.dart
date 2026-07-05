import 'package:beecount/ai/tasks/bill_extraction_task.dart';
import 'package:beecount/services/ai/bill_extraction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('builds lightweight enhancement prompt without replacing default prompt',
      () async {
    final service = BillExtractionService(
      expenseCategories: const ['餐饮', '咖啡', '交通'],
      accounts: const ['中国银行信用卡(2853)'],
    );
    await service.init();

    final longPrompt = service.buildTextPromptForDiagnostics(
      '账单详情\n-18.46\n支付时间\n2026-06-18 10:24:36',
    );
    final lightPrompt = service.buildLightweightEnhancementPrompt(
      ocrText: '账单详情\n-18.46\n支付时间\n2026-06-18 10:24:36',
      ruleBillInfo: BillInfo(
        amount: -18.46,
        time: DateTime(2026, 6, 18, 10, 24, 36),
        note: '天津海河测试咖啡馆丑(和平测试店)外卖订单',
        category: '咖啡',
        paymentMethod: '中国银行信用卡(2853)',
        paymentChannel: '支付宝',
      ),
    );

    expect(longPrompt, contains('平台支付截图规则'));
    expect(lightPrompt, contains('轻量账单增强'));
    expect(lightPrompt, isNot(contains('平台支付截图规则')));
    expect(lightPrompt.length, lessThan(longPrompt.length));
    expect(lightPrompt.length, lessThan(1800));
  });
}
