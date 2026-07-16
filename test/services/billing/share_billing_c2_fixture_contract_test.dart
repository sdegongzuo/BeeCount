import 'package:beecount/services/billing/fast_billing_rule_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('确认场景首张图片使用生产内置规则可直接创建账单', () async {
    final evaluation = await FastBillingRuleService(
      ruleRepository: TomlBillingRuleRepository(),
      ruleEngine: BillingRuleEngineImpl(),
    ).evaluate(
      baseResult: OcrResult(
        rawText: _reliableBillText,
        allNumbers: ['18.50'],
      ),
    );

    expect(
      evaluation.accepted,
      isTrue,
      reason: 'ACTION_SEND 真机 C2 的可靠样本必须越过待确认分支：'
          '${evaluation.rejectReasons}',
    );
    expect(evaluation.result.amount, -18.5);
    expect(evaluation.result.time, DateTime(2026, 7, 16, 12, 34, 56));
  });
}

const _reliableBillText = '''
账单详情
支付成功
-18.50
支付时间
2026-07-16 12:34:56
付款方式
余额
''';
