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
}
