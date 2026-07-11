import 'dart:convert';

import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import 'regression_sample_store.dart';

/// 保存回归样本的可替换函数边界。
typedef SaveRegressionSample = Future<SaveRegressionSampleResult> Function(
  RegressionSampleDraft draft,
);

/// 按交易标识读取用户最终保存的权威账单字段。
typedef LoadExpectedBillFields = Future<Map<String, Object?>> Function(
  int transactionId,
);

/// 将成功 Billing Job 转换成可重放的个人规则回归样本。
class SuccessfulRegressionSampleRecorder {
  final SaveRegressionSample _saveSample;
  final LoadExpectedBillFields _loadExpectedFields;

  /// 创建成功样本记录器。
  const SuccessfulRegressionSampleRecorder({
    required SaveRegressionSample saveSample,
    required LoadExpectedBillFields loadExpectedFields,
  })  : _saveSample = saveSample,
        _loadExpectedFields = loadExpectedFields;

  /// 如果 [job] 已成功且材料完整，则加密保存一条普通成功样本。
  Future<void> capture(BillingJob job) async {
    if (job.status != BillingJobStatus.succeeded ||
        job.transactionId == null ||
        job.rawText == null ||
        job.rawText!.trim().isEmpty ||
        job.ruleResultJson == null ||
        job.ruleResultJson!.isEmpty) {
      return;
    }

    final result = _decodeMap(job.ruleResultJson);
    if (result == null) return;
    final expectedFields = await _loadExpectedFields(job.transactionId!);
    if (expectedFields.isEmpty) return;
    final source = _decodeMap(job.sourceInfoJson) ?? const <String, Object?>{};
    final ruleResult = _asMap(result['billing_rule_result']);
    final templateId = ruleResult?['templateId']?.toString() ??
        ruleResult?['template_id']?.toString() ??
        'unmatched';
    final structureDescriptor = [
      source['sourceAppPackage'] ?? 'unknown-source',
      source['sourcePaymentChannel'] ??
          result['payment_channel'] ??
          'unknown-channel',
      templateId,
      expectedFields.keys.toList()..sort(),
    ].join('|');

    await _saveSample(
      RegressionSampleDraft(
        normalizedOcr: _normalizeOcr(job.rawText!),
        expectedFields: expectedFields,
        sensitiveEvidence: {
          for (final key in _sensitiveEvidenceKeys)
            if (result.containsKey(key)) key: result[key],
          if (source.isNotEmpty) 'source': source,
        },
        structureDescriptor: structureDescriptor,
      ),
    );
  }

  static Map<String, Object?>? _decodeMap(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return _asMap(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _normalizeOcr(String value) => value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
      .where((line) => line.isNotEmpty)
      .join('\n');
}

const _sensitiveEvidenceKeys = {
  'allNumbers',
  'detected_payment_channel',
  'preprocess',
  'billing_rule_result',
  'billing_rule_trace',
  'ocr_engine',
};
