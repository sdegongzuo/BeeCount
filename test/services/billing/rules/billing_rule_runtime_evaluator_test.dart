import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_runtime_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生产黄金样本源读取与 rule_eval 相同的固定样本和真值', () async {
    final samples = await BundledBillingRuleGoldenCorpus().load();

    expect(samples.length, greaterThanOrEqualTo(20));
    final wechat = samples.singleWhere(
      (sample) => sample.id == 'wechat_payment_detail_001',
    );
    expect(wechat.sourcePackage, 'com.tencent.mm');
    expect(wechat.expectedFields['amount'], -19.5);
    expect(wechat.expectedFields['time'], '2026-05-31T14:27:40.000');
  });

  group('BillingRuleRuntimeEvaluator', () {
    test('候选必须保持固定黄金样本的金额和时间真值', () async {
      final sample = BillingRuleGoldenSample(
        id: 'golden-1',
        normalizedOcr: '账单\n金额\n12.30\n时间\n2026-07-17 09:30:00',
        expectedFields: const {
          'matchedTemplateId': 'public-bill',
          'amount': 12.3,
          'time': '2026-07-17T09:30:00.000',
        },
      );
      final evaluator = _evaluator(
        goldenSamples: [sample],
        activePublic: _rules('active', amountLabel: '金额', timeLabel: '时间'),
        builtIn: _rules('built-in', amountLabel: '金额', timeLabel: '时间'),
      );

      expect(
        await evaluator.evaluateGolden(
          _rules(
            'candidate',
            amountLabel: '金额',
            timeLabel: '时间',
            templateId: 'wrong-template',
          ),
        ),
        isFalse,
      );
      expect(
        await evaluator.evaluateGolden(
          _rules('candidate', amountLabel: '总额', timeLabel: '时间'),
        ),
        isFalse,
      );
      expect(
        await evaluator.evaluateGolden(
          _rules('candidate', amountLabel: '金额', timeLabel: '时间'),
        ),
        isTrue,
      );
    });

    test('分页回归逐页读取500份样本且不一次持有全部明文', () async {
      final source = _PagedSamples(
        List.generate(500, (index) => _sample('sample-$index')),
      );
      final evaluator = _evaluator(
        samples: source,
        activePersonal: _emptyRules('personal'),
        batchSize: 37,
      );
      final watch = Stopwatch()..start();

      final result = await evaluator.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
      );

      watch.stop();
      expect(result.isPassed, isTrue);
      expect(source.requestedLimits, everyElement(37));
      expect(source.largestReturnedPage, 37);
      expect(source.readCount, greaterThan(1));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('任一页存在无法解密样本时安全拒绝候选', () async {
      final source = _PagedSamples(
        [_sample('ok')],
        unreadableOnPage: 0,
      );
      final evaluator = _evaluator(samples: source);

      final result = await evaluator.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
      );

      expect(result.isPassed, isFalse);
      expect(result.explanation, contains('无法解密'));
    });

    test('可取消长回归且取消后不再读取下一页', () async {
      final source = _PagedSamples(
        List.generate(100, (index) => _sample('sample-$index')),
      );
      final cancellation = BillingRuleEvaluationCancellation();
      final evaluator = _evaluator(
        samples: source,
        batchSize: 10,
        afterSample: (count) {
          if (count == 3) cancellation.cancel();
        },
      );

      final result = await evaluator.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
        cancellation: cancellation,
      );

      expect(result.isPassed, isFalse);
      expect(result.explanation, contains('取消'));
      expect(source.readCount, 1);
    });

    test('墙钟超时立即拒绝并取消后续分页', () async {
      final source = _PagedSamples(
        List.generate(100, (index) => _sample('sample-$index')),
        delay: const Duration(milliseconds: 80),
      );
      final evaluator = _evaluator(
        samples: source,
        batchSize: 10,
        timeout: const Duration(milliseconds: 20),
      );

      final result = await evaluator.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(result.isPassed, isFalse);
      expect(result.explanation, contains('超时'));
      expect(source.readCount, 1);
    });

    test('公共候选与个人规则等价时报告归档，不等价时保留并解释', () async {
      final equivalentPersonal = _rules(
        'personal',
        amountLabel: '金额',
        templateId: 'personal-amount',
        origin: BillingRuleOrigin.personal,
      );
      final equivalent = _evaluator(
        samples: _PagedSamples([_sample('same')]),
        activePersonal: equivalentPersonal,
      );

      final equivalentResult = await equivalent.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
      );

      expect(equivalentResult.isPassed, isTrue);
      expect(equivalentResult.equivalentPersonalRuleIds, ['personal-amount']);
      expect(equivalentResult.conflicts, isEmpty);

      final conflicting = _evaluator(
        samples: _PagedSamples([_sample('conflict')]),
        activePersonal: _rules(
          'personal',
          amountLabel: '金额',
          templateId: 'personal-amount',
          origin: BillingRuleOrigin.personal,
        ),
      );
      final conflictResult = await conflicting.evaluatePersonal(
        _rules('candidate', amountLabel: '总额'),
      );

      expect(conflictResult.isPassed, isTrue);
      expect(conflictResult.equivalentPersonalRuleIds, isEmpty);
      expect(conflictResult.conflicts.single.personalRuleId, 'personal-amount');
      expect(conflictResult.conflictExplanation, contains('personal-amount'));
    });

    test('逐条比较个人规则，不受另一条更具体个人规则遮蔽', () async {
      final generic = _rules(
        'one',
        amountLabel: '金额',
        templateId: 'personal-generic',
        origin: BillingRuleOrigin.personal,
      ).templates.single;
      const specific = BillingRuleTemplate(
        id: 'personal-specific',
        origin: BillingRuleOrigin.personal,
        match: BillingRuleTemplateMatch(keywordsAll: ['账单', '金额']),
        extractors: [
          BillingFieldExtractorRule(
            field: 'note',
            type: 'constant',
            value: '更具体备注',
          ),
        ],
      );
      final evaluator = _evaluator(
        samples: _PagedSamples([
          _sample('shadow', expectedFields: const {}),
        ]),
        activePersonal: BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'personal-2',
          paymentChannels: const [],
          templates: [generic, specific],
        ),
      );

      final result = await evaluator.evaluatePersonal(
        _rules('candidate', amountLabel: '金额'),
      );

      expect(result.isPassed, isTrue);
      expect(result.equivalentPersonalRuleIds, ['personal-generic']);
      expect(result.conflicts.map((item) => item.personalRuleId),
          ['personal-specific']);
    });
  });
}

BillingRuleRuntimeEvaluator _evaluator({
  List<BillingRuleGoldenSample> goldenSamples = const [],
  RegressionSamplePageSource? samples,
  BillingRuleSet? activePublic,
  BillingRuleSet? builtIn,
  BillingRuleSet? activePersonal,
  int batchSize = 50,
  void Function(int count)? afterSample,
  Duration timeout = const Duration(seconds: 10),
}) =>
    BillingRuleRuntimeEvaluator(
      engine: BillingRuleEngineImpl(),
      goldenCorpus: _GoldenCorpus(goldenSamples),
      regressionSamples: samples ?? _PagedSamples(const []),
      loadActivePublicRules: () async => activePublic ?? _emptyRules('active'),
      loadBuiltInRules: () async => builtIn ?? _emptyRules('built-in'),
      loadActivePersonalRules: () async =>
          activePersonal ?? _emptyRules('personal'),
      batchSize: batchSize,
      timeout: timeout,
      afterSampleForTesting: afterSample,
    );

class _GoldenCorpus implements BillingRuleGoldenCorpusSource {
  final List<BillingRuleGoldenSample> samples;
  const _GoldenCorpus(this.samples);

  @override
  Future<List<BillingRuleGoldenSample>> load() async => samples;
}

class _PagedSamples implements RegressionSamplePageSource {
  final List<DecryptedRegressionSample> samples;
  final int? unreadableOnPage;
  final Duration delay;
  final List<int> requestedLimits = [];
  int largestReturnedPage = 0;
  int readCount = 0;

  _PagedSamples(
    this.samples, {
    this.unreadableOnPage,
    this.delay = Duration.zero,
  });

  @override
  Future<RegressionSamplePage> readPage({
    required int limit,
    String? cursor,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    requestedLimits.add(limit);
    final pageIndex = readCount++;
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + limit).clamp(0, samples.length);
    final page = samples.sublist(start, end);
    largestReturnedPage =
        largestReturnedPage < page.length ? page.length : largestReturnedPage;
    return RegressionSamplePage(
      samples: page,
      unreadableSampleIds:
          unreadableOnPage == pageIndex ? const ['corrupt-1'] : const [],
      nextCursor: end < samples.length ? '$end' : null,
    );
  }
}

DecryptedRegressionSample _sample(
  String id, {
  Map<Object?, Object?> expectedFields = const {'amount': 12.3},
}) =>
    DecryptedRegressionSample(
      id: id,
      normalizedOcr: '账单\n金额\n12.30',
      expectedFields: expectedFields,
      sensitiveEvidence: const {},
      exactFingerprint: id,
      structureFingerprint: 'structure-$id',
      protection: RegressionSampleProtection.none,
      keyVersion: 1,
    );

BillingRuleSet _emptyRules(String version) => BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: version,
      paymentChannels: const [],
      templates: const [],
    );

BillingRuleSet _rules(
  String version, {
  required String amountLabel,
  String? timeLabel,
  String templateId = 'public-bill',
  BillingRuleOrigin origin = BillingRuleOrigin.public,
}) =>
    BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: version,
      paymentChannels: const [],
      templates: [
        BillingRuleTemplate(
          id: templateId,
          origin: origin,
          match: const BillingRuleTemplateMatch(keywordsAll: ['账单']),
          extractors: [
            BillingFieldExtractorRule(
              field: 'amount',
              type: 'labelNextLine',
              label: amountLabel,
              parser: 'amount',
            ),
            if (timeLabel != null)
              BillingFieldExtractorRule(
                field: 'time',
                type: 'labelNextLine',
                label: timeLabel,
                parser: 'isoDatetime',
              ),
          ],
        ),
      ],
    );
