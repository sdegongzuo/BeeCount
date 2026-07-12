import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PersonalRuleRevision extraction(String id, String value,
          {String device = 'a', int version = 1}) =>
      PersonalRuleRevision(
        revisionId: id,
        ruleId: 'amount-rule',
        originDeviceId: device,
        originVersion: version,
        kind: PersonalRuleSyncKind.extraction,
        scopeKey: 'app:wechat',
        conditionKey: 'label:amount',
        payload: {'field': 'amount', 'extractor': value},
      );

  test('同步载荷保留来源版本，冻结内容并拒绝嵌套完整 OCR', () {
    final revision = extraction('r1', 'next-line');
    expect(revision.toSyncJson(), {
      'revision_id': 'r1',
      'rule_id': 'amount-rule',
      'origin_device_id': 'a',
      'origin_version': 1,
      'kind': 'extraction',
      'scope_key': 'app:wechat',
      'condition_key': 'label:amount',
      'payload': {'field': 'amount', 'extractor': 'next-line'},
    });
    expect(
      () => PersonalRuleRevision.validated(
        revisionId: 'bad',
        ruleId: 'bad',
        originDeviceId: 'a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.notePreference,
        scopeKey: 'merchant:x',
        conditionKey: 'same',
        payload: const {'normalized_ocr': 'secret'},
      ),
      throwsArgumentError,
    );
    final restored = PersonalRuleRevision.fromSyncJson(revision.toSyncJson());
    expect(restored.toSyncJson(), revision.toSyncJson());
    final mutable = <String, Object?>{'suffix': '午餐'};
    final frozen = PersonalRuleRevision(
      revisionId: 'note',
      ruleId: 'note',
      originDeviceId: 'a',
      originVersion: 1,
      kind: PersonalRuleSyncKind.notePreference,
      scopeKey: 'merchant:x',
      conditionKey: 'same',
      payload: mutable,
    );
    mutable['suffix'] = '已篡改';
    expect(frozen.payload, {'suffix': '午餐'});
    expect(
      () => PersonalRuleRevision(
        revisionId: 'nested',
        ruleId: 'bad',
        originDeviceId: 'a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.extraction,
        scopeKey: 'x',
        conditionKey: 'y',
        payload: const {
          'evidence': {'normalized_ocr': 'secret'}
        },
      ),
      throwsArgumentError,
    );
  });

  test('新设备收到提取修订保持待验证，只有本机回归通过才启用', () async {
    final pending = await PersonalRuleSyncService(
      localDeviceId: 'new',
      regressionGate: (_) async => LocalRegressionVerdict.insufficient,
    ).merge([extraction('r1', 'next-line')]);
    expect(pending.stateFor('r1'), PersonalRuleRevisionState.pendingValidation);
    expect(pending.pausedMatchKeys, ['extraction|app:wechat|label:amount']);

    final enabled = await PersonalRuleSyncService(
      localDeviceId: 'new',
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    ).merge([extraction('r1', 'next-line')]);
    expect(enabled.stateFor('r1'), PersonalRuleRevisionState.active);
  });

  test('本机既有提取修订保持活动，不重复要求远端门禁', () async {
    final result = await PersonalRuleSyncService(localDeviceId: 'a')
        .merge([extraction('r1', 'next-line')]);
    expect(result.stateFor('r1'), PersonalRuleRevisionState.active);
  });

  test('分类目标冲突暂停相同匹配范围', () async {
    final result = await PersonalRuleSyncService(localDeviceId: 'c').merge([
      PersonalRuleRevision(
        revisionId: 'c1',
        ruleId: 'category',
        originDeviceId: 'a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:coffee',
        payload: {'category_sync_id': 'food'},
      ),
      PersonalRuleRevision(
        revisionId: 'c2',
        ruleId: 'category',
        originDeviceId: 'b',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:coffee',
        payload: {'category_sync_id': 'social'},
      ),
    ]);
    expect(result.stateFor('c1'), PersonalRuleRevisionState.conflict);
    expect(result.stateFor('c2'), PersonalRuleRevisionState.conflict);
    expect(result.pausedMatchKeys, ['category|ledger:L1|merchant:coffee']);
  });

  test('分类目标相同但审计元数据不同仍视为等价', () async {
    final result = await PersonalRuleSyncService(localDeviceId: 'c').merge([
      PersonalRuleRevision(
        revisionId: 'c1',
        ruleId: 'category',
        originDeviceId: 'a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:x',
        payload: const {'category_sync_id': 'food', 'created_at': 1},
      ),
      PersonalRuleRevision(
        revisionId: 'c2',
        ruleId: 'category',
        originDeviceId: 'b',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:x',
        payload: const {'category_sync_id': 'food', 'created_at': 2},
      ),
    ]);
    expect(result.pausedMatchKeys, isEmpty);
    expect(result.states.values, contains(PersonalRuleRevisionState.active));
  });

  test('用户确认的新修订解决旧冲突并使设备收敛', () async {
    final resolved = PersonalRuleRevision(
      revisionId: 'c3',
      ruleId: 'category',
      originDeviceId: 'c',
      originVersion: 1,
      kind: PersonalRuleSyncKind.category,
      scopeKey: 'ledger:L1',
      conditionKey: 'merchant:x',
      payload: const {'category_sync_id': 'food'},
      resolvedRevisionIds: const ['c1', 'c2'],
    );
    final result = await PersonalRuleSyncService(localDeviceId: 'c').merge([
      PersonalRuleRevision(
        revisionId: 'c1',
        ruleId: 'category',
        originDeviceId: 'a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:x',
        payload: const {'category_sync_id': 'food'},
      ),
      PersonalRuleRevision(
        revisionId: 'c2',
        ruleId: 'category',
        originDeviceId: 'b',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'ledger:L1',
        conditionKey: 'merchant:x',
        payload: const {'category_sync_id': 'social'},
      ),
      resolved,
    ]);
    expect(result.stateFor('c1'), PersonalRuleRevisionState.resolved);
    expect(result.stateFor('c2'), PersonalRuleRevisionState.resolved);
    expect(result.stateFor('c3'), PersonalRuleRevisionState.active);
    expect(result.pausedMatchKeys, isEmpty);
  });

  test('等价提取修订归档冗余；仅一条回归通过时启用通过者', () async {
    final equivalent = await PersonalRuleSyncService(
      localDeviceId: 'c',
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    ).merge([
      extraction('r2', 'next-line', device: 'b'),
      extraction('r1', 'next-line')
    ]);
    expect(equivalent.stateFor('r1'), PersonalRuleRevisionState.active);
    expect(equivalent.stateFor('r2'),
        PersonalRuleRevisionState.archivedEquivalent);

    final decided = await PersonalRuleSyncService(
      localDeviceId: 'c',
      regressionGate: (r) async => r.revisionId == 'r2'
          ? LocalRegressionVerdict.passed
          : LocalRegressionVerdict.rejected,
    ).merge([
      extraction('r1', 'regex-a'),
      extraction('r2', 'regex-b', device: 'b')
    ]);
    expect(decided.stateFor('r2'), PersonalRuleRevisionState.active);
    expect(
        decided.stateFor('r1'), PersonalRuleRevisionState.regressionRejected);
  });

  test('等价修订只启用实际通过本机回归的修订', () async {
    final result = await PersonalRuleSyncService(
      localDeviceId: 'c',
      regressionGate: (r) async => r.revisionId == 'r2'
          ? LocalRegressionVerdict.passed
          : LocalRegressionVerdict.rejected,
    ).merge([
      extraction('r1', 'next-line'),
      extraction('r2', 'next-line', device: 'b'),
    ]);
    expect(result.stateFor('r2'), PersonalRuleRevisionState.active);
    expect(result.stateFor('r1'), PersonalRuleRevisionState.archivedEquivalent);
  });

  test('不兼容或证据不足时暂停提取范围并进入待确认', () async {
    final result = await PersonalRuleSyncService(
      localDeviceId: 'c',
      regressionGate: (r) async => r.revisionId == 'r1'
          ? LocalRegressionVerdict.passed
          : LocalRegressionVerdict.insufficient,
    ).merge([
      extraction('r1', 'regex-a'),
      extraction('r2', 'regex-b', device: 'b')
    ]);
    expect(result.stateFor('r1'), PersonalRuleRevisionState.conflict);
    expect(result.stateFor('r2'), PersonalRuleRevisionState.pendingValidation);
    expect(result.requiresConfirmation, isTrue);
  });

  test('离线并发、乱序和重复修订收敛到同一不可变结果', () async {
    final inputs = [
      extraction('a2', 'next-line', version: 2),
      extraction('b1', 'next-line', device: 'b'),
      extraction('a1', 'old', version: 1),
      extraction('a2', 'next-line', version: 2),
    ];
    final service = PersonalRuleSyncService(
      localDeviceId: 'c',
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    );
    final forward = await service.merge(inputs);
    final reverse = await service.merge(inputs.reversed);
    expect(forward.toJson(), reverse.toJson());
    expect(forward.revisions, hasLength(3));
    expect(forward.stateFor('a2'), PersonalRuleRevisionState.active);
    expect(
        forward.stateFor('b1'), PersonalRuleRevisionState.archivedEquivalent);
    expect(forward.stateFor('a1'), PersonalRuleRevisionState.superseded);
  });
}
