import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(RegressionSampleStore.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('保存个人规则回归样本时传递完整规范化证据和保护类型', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'inserted': true,
        'sampleId': 'sample-1',
        'exactFingerprint': 'exact',
        'structureFingerprint': 'structure',
      };
    });

    final result = await const RegressionSampleStore().save(
      const RegressionSampleDraft(
        normalizedOcr: '支付成功\n金额 12.00',
        expectedFields: {'amount': 12},
        sensitiveEvidence: {'orderId': 'A1'},
        structureDescriptor: 'wechat|payment|amount-label',
        protection: RegressionSampleProtection.correction,
      ),
    );

    expect(received?.method, 'save');
    expect(received?.arguments, containsPair('protection', 'correction'));
    expect(result.sampleId, 'sample-1');
  });

  test('批量读取公开不可解密标记和分阶段性能', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => {
                  'samples': <Object?>[],
                  'unreadableSampleIds': ['broken'],
                  'keyUnwrapCount': 1,
                  'timings': {
                    'keyUnwrapMs': 1.0,
                    'sampleReadMs': 2.0,
                    'decryptMs': 3.0,
                    'decodeMs': 4.0,
                    'totalMs': 10.0,
                  },
                });

    final batch = await const RegressionSampleStore().readBatch();

    expect(batch.unreadableSampleIds, ['broken']);
    expect(batch.keyUnwrapCount, 1);
    expect(batch.timings.totalMs, 10);
  });

  test('分页读取把页大小与游标传给本机加密存储', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'samples': <Object?>[],
        'unreadableSampleIds': <String>[],
        'nextCursor': '200|sample-2',
      };
    });

    final page = await const RegressionSampleStore().readPage(
      limit: 50,
      cursor: '100|sample-1',
    );

    expect(received?.method, 'readPage');
    expect(received?.arguments, {
      'limit': 50,
      'cursor': '100|sample-1',
    });
    expect(page.nextCursor, '200|sample-2');
  });

  test('准备 expected 修订时传递版本、来源和迁移决策', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'revisionId': 'revision-2',
        'sampleId': 'sample-1',
        'normalizationVersion': 2,
        'migrationDecisionId': 'decision-2',
        'derivedFromRevisionId': 'revision-1',
        'state': 'prepared',
      };
    });

    final revision =
        await const RegressionSampleStore().prepareExpectedRevision(
      sampleId: 'sample-1',
      normalizationVersion: 2,
      expectedFields: const {
        'paymentMethod': '中国银行信用卡(2853)',
      },
      migrationDecisionId: 'decision-2',
      derivedFromRevisionId: 'revision-1',
    );

    expect(received?.method, 'prepareExpectedRevision');
    expect(received?.arguments, {
      'sampleId': 'sample-1',
      'normalizationVersion': 2,
      'expectedFields': {'paymentMethod': '中国银行信用卡(2853)'},
      'migrationDecisionId': 'decision-2',
      'derivedFromRevisionId': 'revision-1',
    });
    expect(revision.revisionId, 'revision-2');
    expect(revision.state, RegressionExpectedRevisionState.prepared);
  });

  test('激活 expected 修订时返回原子切换结果', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'activeNormalizationVersion': 2,
        'previousNormalizationVersion': 1,
        'activatedRevisionCount': 3,
      };
    });

    final activation =
        await const RegressionSampleStore().activateExpectedRevisions(
      normalizationVersion: 2,
      migrationDecisionId: 'decision-2',
    );

    expect(received?.method, 'activateExpectedRevisions');
    expect(received?.arguments, {
      'normalizationVersion': 2,
      'migrationDecisionId': 'decision-2',
    });
    expect(activation.activeNormalizationVersion, 2);
    expect(activation.previousNormalizationVersion, 1);
    expect(activation.activatedRevisionCount, 3);
  });

  test('回滚 expected 修订时调用无参数本机事务', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'activeNormalizationVersion': 1,
        'previousNormalizationVersion': 2,
        'activatedRevisionCount': 3,
      };
    });

    final rollback =
        await const RegressionSampleStore().rollbackExpectedRevisions();

    expect(received?.method, 'rollbackExpectedRevisions');
    expect(received?.arguments, isNull);
    expect(rollback.activeNormalizationVersion, 1);
    expect(rollback.previousNormalizationVersion, 2);
    expect(rollback.activatedRevisionCount, 3);
  });

  test('读取 expected 激活状态用于规则与归一化恢复校验', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'activeNormalizationVersion': 2,
        'previousNormalizationVersion': 1,
        'migrationDecisionId': 'migration-2',
      };
    });

    final state =
        await const RegressionSampleStore().readExpectedActivationState();

    expect(received?.method, 'readExpectedActivationState');
    expect(state.activeNormalizationVersion, 2);
    expect(state.previousNormalizationVersion, 1);
    expect(state.migrationDecisionId, 'migration-2');
  });
}
