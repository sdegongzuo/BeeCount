import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_runtime_evaluator.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late SqlitePersonalRuleRevisionStore revisions;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    revisions = SqlitePersonalRuleRevisionStore(db);
    await revisions.ensureSchema();
  });

  tearDown(() => db.close());

  test('合成标签相对位置规则，通过回归后原子启用', () async {
    final service = _service(revisions, [
      _sample('old', '金额\n12.00', {'amount': 12.0}),
    ]);

    final result = await service.applyCorrection(
      const PersonalRuleCorrection(
        field: 'amount',
        confirmedValue: 18.5,
        normalizedOcr: '微信支付\n金额\n18.50\n交易成功',
        sourcePackage: 'com.tencent.mm',
      ),
    );

    expect(result.status, PersonalRuleLifecycleStatus.enabled);
    expect(result.candidate!.extractors.single.type, 'labelNextLine');
    expect(await revisions.activeVersion(), result.revision);
    expect((await revisions.loadActiveRuleSet()).templates, hasLength(1));
  });

  test('正则仅作为没有稳定标签时的后备', () async {
    final result = await _service(revisions, const []).applyCorrection(
      const PersonalRuleCorrection(
        field: 'amount',
        confirmedValue: 18.5,
        normalizedOcr: '微信支付\n实付 ¥18.50\n交易成功',
        sourcePackage: 'com.tencent.mm',
      ),
    );

    expect(result.status, PersonalRuleLifecycleStatus.enabled);
    expect(result.candidate!.extractors.single.type, 'regex');
  });

  test('无法由 OCR 证据安全表达的校正只作用于当前账单', () async {
    final result = await _service(revisions, const []).applyCorrection(
      const PersonalRuleCorrection(
        field: 'note',
        confirmedValue: '和朋友聚餐',
        normalizedOcr: '微信支付\n金额\n18.50',
        sourcePackage: 'com.tencent.mm',
      ),
    );

    expect(result.status, PersonalRuleLifecycleStatus.pendingValidation);
    expect(result.currentBillOnly, isTrue);
    expect(await revisions.activeVersion(), isNull);
  });

  test('影响样本改变既有结果时拒绝，来源不匹配样本可证明排除', () async {
    final samples = [
      _sample('affected', '金额\n12.00', {'amount': 99.0},
          source: 'com.tencent.mm'),
      _sample('excluded', '金额\n12.00', {'amount': 99.0},
          source: 'com.eg.android.AlipayGphone'),
    ];
    final rejected = await _service(revisions, samples).applyCorrection(
      const PersonalRuleCorrection(
          field: 'amount',
          confirmedValue: 18.5,
          normalizedOcr: '金额\n18.50',
          sourcePackage: 'com.tencent.mm'),
    );

    expect(rejected.status, PersonalRuleLifecycleStatus.regressionRejected);
    expect(rejected.impactSampleIds, ['affected']);
    expect(rejected.excludedSampleIds, ['excluded']);
    expect(await revisions.activeVersion(), isNull);
  });

  test('同作用域不兼容候选返回冲突', () async {
    final first = await _service(revisions, const []).applyCorrection(
      const PersonalRuleCorrection(
          field: 'amount',
          confirmedValue: 18.5,
          normalizedOcr: '金额\n18.50',
          sourcePackage: 'com.tencent.mm'),
    );
    expect(first.status, PersonalRuleLifecycleStatus.enabled);

    final second = await _service(revisions, const []).applyCorrection(
      const PersonalRuleCorrection(
          field: 'amount',
          confirmedValue: 20.0,
          normalizedOcr: '金额：20.00',
          sourcePackage: 'com.tencent.mm'),
    );
    expect(second.status, PersonalRuleLifecycleStatus.conflict);
    expect(await revisions.activeVersion(), first.revision);
  });

  test('事务中断继续使用原活动快照', () async {
    final first = await _service(revisions, const []).applyCorrection(
      const PersonalRuleCorrection(
          field: 'amount',
          confirmedValue: 18.5,
          normalizedOcr: '金额\n18.50',
          sourcePackage: 'com.tencent.mm'),
    );
    revisions.failBeforePointerSwitch = true;

    await expectLater(
      revisions.activate(_candidate('new-rule', '时间', 'time'),
          expectedActiveVersion: first.revision),
      throwsStateError,
    );
    expect(await revisions.activeVersion(), first.revision);
    expect((await revisions.loadActiveRuleSet()).templates.single.id,
        first.candidate!.id);
  });

  test('500 条完整回归 P95 不超过 500ms、最坏不超过一秒', () async {
    final samples = List.generate(
        500, (i) => _sample('$i', '订单$i\n金额\n12.00', {'amount': 12.0}));
    final elapsed = <int>[];
    for (var run = 0; run < 20; run++) {
      final watch = Stopwatch()..start();
      final result = await _service(revisions, samples).applyCorrection(
        const PersonalRuleCorrection(
            field: 'amount',
            confirmedValue: 18.5,
            normalizedOcr: '金额\n18.50',
            sourcePackage: 'com.tencent.mm'),
      );
      watch.stop();
      expect(result.status, PersonalRuleLifecycleStatus.enabled);
      elapsed.add(watch.elapsedMilliseconds);
    }
    elapsed.sort();
    final p95 = elapsed[18];
    final worst = elapsed.last;
    // ignore: avoid_print
    print('500-sample regression: p95=${p95}ms worst=${worst}ms');
    expect(p95, lessThan(500));
    expect(worst, lessThan(1000));
  });

  test('仅有来源应用名时保持应用作用域', () async {
    final result = await _service(revisions, [
      _sample('other', '金额\n99.00', {'amount': 7.0},
          source: '', sourceAppName: '支付宝'),
    ]).applyCorrection(
      const PersonalRuleCorrection(
          field: 'amount',
          confirmedValue: 18.5,
          normalizedOcr: '金额\n18.50',
          sourceAppName: '微信'),
    );

    expect(result.status, PersonalRuleLifecycleStatus.enabled);
    expect(result.candidate!.match.appNameKeywords, ['微信']);
    expect(result.excludedSampleIds, ['other']);
  });

  test('超过一秒的完整回归不启用候选', () async {
    final service = PersonalRuleLifecycleService(
      engine: BillingRuleEngineImpl(),
      revisionStore: revisions,
      regressionSamples:
          _Samples(const [], delay: Duration(milliseconds: 1001)),
      publicRules: const BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'public',
          paymentChannels: [],
          templates: []),
    );
    final result = await service.applyCorrection(const PersonalRuleCorrection(
        field: 'amount', confirmedValue: 18.5, normalizedOcr: '金额\n18.50'));
    expect(result.status, PersonalRuleLifecycleStatus.pendingValidation);
    expect(await revisions.activeVersion(), isNull);
  });

  test('并发启用使用活动版本 CAS，禁止静默丢失规则', () async {
    final firstVersion = await revisions.activate(
      _candidate('first', '金额', 'amount'),
      expectedActiveVersion: null,
    );
    final attempts = await Future.wait<Object>([
      revisions
          .activate(_candidate('time-rule', '时间', 'time'),
              expectedActiveVersion: firstVersion)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      revisions
          .activate(_candidate('note-rule', '备注', 'note'),
              expectedActiveVersion: firstVersion)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(attempts.whereType<int>(), hasLength(1));
    expect(attempts.whereType<PersonalRuleActivationConflict>(), hasLength(1));
    expect((await revisions.loadActiveRuleSet()).templates, hasLength(2));
  });

  test('公共规则等价时原子归档个人规则并保留审计记录', () async {
    final first = await revisions.activate(
      _candidate('equivalent', '金额', 'amount'),
      expectedActiveVersion: null,
    );
    final second = await revisions.activate(
      _candidate('retained', '时间', 'time'),
      expectedActiveVersion: first,
    );

    final version = await revisions.archiveEquivalentRules(
      const ['equivalent'],
      publicRulesVersion: 'public-2',
      expectedActiveVersion: second,
    );

    expect((await revisions.loadActiveRuleSet()).templates.map((e) => e.id),
        ['retained']);
    expect(version, greaterThan(second));
    final audit = await db
        .customSelect(
          'SELECT rule_id, public_rules_version FROM personal_rule_archives',
        )
        .getSingle();
    expect(audit.read<String>('rule_id'), 'equivalent');
    expect(audit.read<String>('public_rules_version'), 'public-2');
  });

  test('公共规则激活裁决原子归档等价规则并记录冲突解释', () async {
    final first = await revisions.activate(
      _candidate('equivalent', '金额', 'amount'),
      expectedActiveVersion: null,
    );
    final second = await revisions.activate(
      _candidate('conflicting', '时间', 'time'),
      expectedActiveVersion: first,
    );
    const result = BillingRulePersonalRegressionResult.passed(
      equivalentPersonalRuleIds: ['equivalent'],
      expectedPersonalRulesVersion: 2,
      conflicts: [
        BillingRulePersonalConflict(
          personalRuleId: 'conflicting',
          explanation: '公共候选时间不同，保留个人结果。',
        ),
      ],
    );

    await revisions.reconcilePublicRules(
      result,
      publicRulesVersion: 'public-3',
    );

    expect((await revisions.loadActiveRuleSet()).templates.map((e) => e.id),
        ['conflicting']);
    final decision =
        await db.customSelect('''SELECT rule_id, public_rules_version,
          decision, explanation FROM personal_rule_public_decisions''').getSingle();
    expect(decision.read<String>('rule_id'), 'conflicting');
    expect(decision.read<String>('public_rules_version'), 'public-3');
    expect(decision.read<String>('decision'), 'retained_conflict');
    expect(decision.read<String>('explanation'), contains('保留个人结果'));
    expect(second, 2);
  });

  test('公共裁决提交后重放只证明完成，不重复归档或写冲突', () async {
    final first = await revisions.activate(
      _candidate('equivalent', '金额', 'amount'),
      expectedActiveVersion: null,
    );
    final second = await revisions.activate(
      _candidate('conflicting', '时间', 'time'),
      expectedActiveVersion: first,
    );
    final result = BillingRulePersonalRegressionResult.passed(
      equivalentPersonalRuleIds: const ['equivalent'],
      expectedPersonalRulesVersion: second,
      conflicts: const [
        BillingRulePersonalConflict(
          personalRuleId: 'conflicting',
          explanation: '保留个人时间结果',
        ),
      ],
    );

    final appliedVersion = await revisions.reconcilePublicRules(
      result,
      publicRulesVersion: 'public-replay',
    );
    final replayedVersion = await revisions.reconcilePublicRules(
      result,
      publicRulesVersion: 'public-replay',
    );

    expect(replayedVersion, appliedVersion);
    expect(
      await revisions.isPublicReconciliationApplied(
        result,
        publicRulesVersion: 'public-replay',
      ),
      isTrue,
    );
    for (final table in [
      'personal_rule_archives',
      'personal_rule_public_archive_resolutions',
      'personal_rule_public_decisions',
    ]) {
      final row = await db
          .customSelect('SELECT COUNT(*) AS count FROM $table')
          .getSingle();
      expect(row.read<int>('count'), 1, reason: table);
    }
  });

  test('评测后的个人活动版本变化时整个公共裁决不落库', () async {
    final version = await revisions.activate(
      _candidate('retained', '金额', 'amount'),
      expectedActiveVersion: null,
    );
    const stale = BillingRulePersonalRegressionResult.passed(
      equivalentPersonalRuleIds: ['retained'],
      expectedPersonalRulesVersion: null,
      conflicts: [
        BillingRulePersonalConflict(
          personalRuleId: 'retained',
          explanation: 'stale',
        ),
      ],
    );

    await expectLater(
      revisions.reconcilePublicRules(stale, publicRulesVersion: 'public-4'),
      throwsA(isA<PersonalRuleActivationConflict>()),
    );

    expect(await revisions.activeVersion(), version);
    expect((await revisions.loadActiveRuleSet()).templates, hasLength(1));
    final count = await db
        .customSelect(
            'SELECT COUNT(*) AS count FROM personal_rule_public_decisions')
        .getSingle();
    expect(count.read<int>('count'), 0);
  });

  test('旧版个人规则三表升级时新增冲突裁决表且保留历史归档', () async {
    await db.close();
    final legacyDb = BeeDatabase.forTesting(NativeDatabase.memory());
    db = legacyDb;
    await legacyDb.customStatement('''CREATE TABLE personal_rule_revisions (
      version INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''');
    await legacyDb.customStatement('''CREATE TABLE personal_rule_state (
      singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
      active_version INTEGER REFERENCES personal_rule_revisions(version)
    )''');
    await legacyDb.customStatement('''CREATE TABLE personal_rule_archives (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      public_rules_version TEXT NOT NULL,
      archived_at INTEGER NOT NULL
    )''');
    await legacyDb.customStatement(
      'INSERT INTO personal_rule_state(singleton, active_version) VALUES (1, NULL)',
    );
    await legacyDb.customStatement(
      'INSERT INTO personal_rule_archives(rule_id, public_rules_version, archived_at) VALUES (?, ?, ?)',
      ['historical', 'public-1', 1],
    );

    await SqlitePersonalRuleRevisionStore(legacyDb).ensureSchema();

    final table = await legacyDb
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'personal_rule_public_decisions'",
        )
        .getSingle();
    expect(table.read<String>('name'), 'personal_rule_public_decisions');
    final resolutionTable = await legacyDb
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'personal_rule_public_archive_resolutions'",
        )
        .getSingle();
    expect(resolutionTable.read<String>('name'),
        'personal_rule_public_archive_resolutions');
    final historical = await legacyDb
        .customSelect('SELECT rule_id FROM personal_rule_archives')
        .getSingle();
    expect(historical.read<String>('rule_id'), 'historical');
  });
}

PersonalRuleLifecycleService _service(
  PersonalRuleRevisionStore store,
  List<DecryptedRegressionSample> samples,
) =>
    PersonalRuleLifecycleService(
      engine: BillingRuleEngineImpl(),
      revisionStore: store,
      regressionSamples: _Samples(samples),
      publicRules: const BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'public',
          paymentChannels: [],
          templates: []),
    );

DecryptedRegressionSample _sample(
        String id, String ocr, Map<Object?, Object?> expected,
        {String source = 'com.tencent.mm', String? sourceAppName}) =>
    DecryptedRegressionSample(
        id: id,
        normalizedOcr: ocr,
        expectedFields: expected,
        sensitiveEvidence: {
          'source_package': source,
          if (sourceAppName != null) 'source_app_name': sourceAppName,
        },
        exactFingerprint: 'e$id',
        structureFingerprint: 's$id',
        protection: RegressionSampleProtection.none,
        keyVersion: 1);

BillingRuleTemplate _candidate(String id, String label, String field) =>
    BillingRuleTemplate(
        id: id,
        match: const BillingRuleTemplateMatch(),
        extractors: [
          BillingFieldExtractorRule(
              field: field, type: 'labelNextLine', label: label)
        ]);

class _Samples implements PersonalRuleRegressionSampleSource {
  final List<DecryptedRegressionSample> samples;
  final Duration delay;
  _Samples(this.samples, {this.delay = Duration.zero});
  @override
  Future<RegressionSampleBatch> readBatch() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return RegressionSampleBatch(
        samples: samples,
        unreadableSampleIds: const [],
        keyUnwrapCount: 1,
        timings: const RegressionSampleTimings(
            keyUnwrapMs: 0,
            sampleReadMs: 0,
            decryptMs: 0,
            decodeMs: 0,
            totalMs: 0));
  }
}
