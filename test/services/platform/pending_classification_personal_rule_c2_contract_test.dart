import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final patrol =
      File('patrol_test/pending_classification_personal_rule_c2_test.dart');
  final classificationPage =
      File('lib/pages/billing/pending_transaction_classification_page.dart');
  final mainActivity = File(
    'android/app/src/main/kotlin/com/tntlikely/beecount/MainActivity.kt',
  );
  final shareActivity = File(
    'android/app/src/main/kotlin/com/tntlikely/beecount/ShareBillingActivity.kt',
  );
  final registration = File(
    'android/app/src/main/kotlin/com/tntlikely/beecount/'
    'ShareBillingC2ChannelRegistration.kt',
  );
  final report = File('docs/testing/issue-07-android-c2-report-template.md');
  final androidBuild = File('android/app/build.gradle');

  test('C2 走真实 ACTION_SEND、production Host 和真实补正页面', () {
    final source = patrol.readAsStringSync();

    expect(source, contains("_send('classification-first'"));
    expect(source, contains("_send('classification-second'"));
    expect(source, contains('PendingBillingNavigationHost'));
    expect(source, contains('PendingTransactionClassificationPage'));
    expect(source, contains("Key('classificationScope-currentLedger')"));
    expect(source, isNot(contains('scrollUntilExists(')));
    expect(source, isNot(contains('tester.scrollUntilVisible(')));
    expect(source, contains('scopeGroup.onChanged('));
    expect(source, contains('button.onPressed!()'));
    expect(source, contains('_waitForClassifiedTransaction('));
    expect(source, isNot(contains('.platform.tap(')));
    expect(source, isNot(contains('tester.pump()')));
    final pageSource = classificationPage.readAsStringSync();
    expect(pageSource, contains('_revealScopeSection'));
    expect(pageSource, contains('SingleChildScrollView('));
    expect(source, contains("fallback?.name, '其他'"));
    expect(source, contains("const expectedStructuredNote = '商户：极光测试实验室'"));
    expect(source, contains('firstBefore.note, expectedStructuredNote'));
    expect(source, contains('firstAfter.note, expectedStructuredNote'));
    expect(source, contains('second.note, expectedStructuredNote'));
    expect(source, contains("isNot(contains('补充信息：'))"));
    expect(source, contains("isNot(contains('待分类'))"));
    expect(source, contains('second!.needsClassification, isFalse'));
    expect(source, contains('secondJob.ruleResultJson!'));
    expect(source, isNot(contains('secondJob.finalResultJson!')));
    expect(source, contains("'locateActionSend'"));
  });

  test('C2 不直接调用补正 service 或个人规则写入接口', () {
    final source = patrol.readAsStringSync();

    expect(source, isNot(contains('PendingTransactionClassificationService(')));
    expect(source, isNot(contains('confirmClassification(')));
    expect(source, isNot(contains('SqlitePersonalCategoryRuleStore')));
    expect(source, isNot(contains('.remember(')));
  });

  test('native tracer 只按精确键只读定位 production cache 路径', () {
    final mainSource = mainActivity.readAsStringSync();
    final activitySource = shareActivity.readAsStringSync();
    final registrationSource = registration.readAsStringSync();

    expect(mainSource, contains('"sendActionSend"'));
    expect(mainSource, contains('"locateActionSend"'));
    expect(mainSource, contains('ShareBillingC2TraceRegistry.locate(key)'));
    expect(
        activitySource, contains('ShareBillingC2TraceRegistry.recordAccepted'));
    expect(activitySource, contains('EXTRA_C2_CASE_ID'));
    expect(
        registrationSource, contains('fun shouldRegister(isDebug: Boolean)'));
    expect(registrationSource, contains('= isDebug'));
  });

  test('Patrol C2 只执行 Dart 入口对应的 instrumentation class', () {
    final source = androidBuild.readAsStringSync();

    expect(source, contains("endsWith('/patrol_test/test_bundle.dart')"));
    expect(
      source,
      contains(
        'testInstrumentationRunnerArguments class: '
        '"com.tntlikely.beecount.MainActivityTest"',
      ),
    );
  });

  test('中文报告明确区分本地验证、真机闭环和恢复证据', () {
    final source = report.readAsStringSync();

    expect(source, contains('production 恢复 APK SHA-256'));
    expect(source, contains('测试后用户数据哨兵'));
    expect(source, contains('第二张相似图片'));
    expect(source, contains('本地验证'));
    expect(source, contains('真机安全闭环'));
  });
}
