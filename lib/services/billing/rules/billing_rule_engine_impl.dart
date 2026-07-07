import 'billing_rule_engine.dart';
import 'billing_rule_extractors.dart';
import 'billing_rule_models.dart';
import 'billing_rule_parsers.dart';
import 'billing_rule_trace.dart';

class BillingRuleEngineImpl implements BillingRuleEngine {
  @override
  Future<BillingRuleResult> evaluate({
    required BillingRuleSet ruleSet,
    required String ocrText,
    OcrPreprocessResult? preprocessResult,
    String? sourcePackage,
    String? sourceAppName,
    String? sourcePaymentChannel,
    BillingRuleTraceSink? traceSink,
  }) async {
    final startedAt = DateTime.now();
    final matches = _matchTemplates(
      ruleSet,
      ocrText,
      sourcePackage,
      sourceAppName,
    );
    BillingRuleResult result;
    final fieldEvidence = <String, List<BillingRuleFieldEvidence>>{};
    final debugMessages = <String>[];

    if (matches.isEmpty) {
      result = const BillingRuleResult();
      _emitTrace(
        traceSink: traceSink,
        ruleSet: ruleSet,
        ocrText: ocrText,
        sourcePackage: sourcePackage,
        sourceAppName: sourceAppName,
        sourcePaymentChannel: sourcePaymentChannel,
        preprocessResult: preprocessResult,
        matches: matches,
        fieldEvidence: fieldEvidence,
        result: result,
        startedAt: startedAt,
        debugMessages: const ['No billing rule template matched'],
      );
      return result;
    }

    final selected = matches.first.template;
    final fields = <String, BillingRuleFieldResult>{};
    final details = <String, dynamic>{};
    double? amount;
    String? note;
    DateTime? time;
    String? paymentChannel;
    String? paymentMethod;
    String? counterparty;
    String? merchantFullName;
    String? acquirer;
    final lines = _splitLines(ocrText);
    final remainingExtractors = <BillingFieldExtractorRule>[];
    final extractedLabelLineIndexes = <int>{};

    for (final extractorRule in selected.extractors) {
      if (extractorRule.type == BillingRuleExtractorTypes.remainingLines) {
        remainingExtractors.add(extractorRule);
        continue;
      }
      final extraction = BillingRuleExtractors.extract(
        rule: extractorRule,
        ocrText: ocrText,
        lines: lines,
        templateId: selected.id,
      );
      if (extraction == null) {
        debugMessages.add('Extractor missed field ${extractorRule.field}');
        continue;
      }
      final parsed = BillingRuleParsers.parse(
        extractorRule.parser,
        extraction.text,
        pattern: extractorRule.pattern,
        options: extractorRule.options,
      );
      if (!parsed.success || parsed.value == null) {
        debugMessages.add(
          'Parser missed field ${extractorRule.field}: ${parsed.error}',
        );
        continue;
      }

      final confidence = _clampConfidence(
        extraction.confidence * parsed.confidence,
      );
      final fieldResult = BillingRuleFieldResult(
        field: extractorRule.field,
        value: parsed.value,
        confidence: confidence,
        extractorType: extractorRule.type,
        source: extraction.source,
        evidence: extraction.evidence,
      );
      fields[extractorRule.field] = fieldResult;
      fieldEvidence[extractorRule.field] = extraction.evidence;
      final labelLineIndex = _findLabelLine(lines, extractorRule.label);
      if (labelLineIndex != null) {
        extractedLabelLineIndexes.add(labelLineIndex);
      }

      switch (extractorRule.field) {
        case 'amount':
          amount = _asDouble(parsed.value);
          break;
        case 'note':
          note = parsed.value.toString();
          break;
        case 'time':
          if (parsed.value is DateTime) time = parsed.value as DateTime;
          break;
        case 'paymentChannel':
          paymentChannel = parsed.value.toString();
          break;
        case 'paymentMethod':
          paymentMethod = parsed.value.toString();
          break;
        case 'counterparty':
          counterparty = parsed.value.toString();
          break;
        case 'merchantFullName':
          merchantFullName = parsed.value.toString();
          break;
        case 'acquirer':
          acquirer = parsed.value.toString();
          break;
        default:
          if (extractorRule.field.startsWith('details.')) {
            _writeDetailsValue(details, extractorRule.field, parsed.value);
          }
          break;
      }
    }

    for (final extractorRule in remainingExtractors) {
      final extraction = _extractRemainingLines(
        rule: extractorRule,
        lines: lines,
        fieldEvidence: fieldEvidence,
        extraUsedLineIndexes: extractedLabelLineIndexes,
        templateId: selected.id,
      );
      if (extraction == null) {
        debugMessages.add('Extractor missed field ${extractorRule.field}');
        continue;
      }
      final parsed = BillingRuleParsers.parse(
        extractorRule.parser,
        extraction.text,
        pattern: extractorRule.pattern,
        options: extractorRule.options,
      );
      if (!parsed.success || parsed.value == null) {
        debugMessages.add(
          'Parser missed field ${extractorRule.field}: ${parsed.error}',
        );
        continue;
      }
      final confidence = _clampConfidence(
        extraction.confidence * parsed.confidence,
      );
      fields[extractorRule.field] = BillingRuleFieldResult(
        field: extractorRule.field,
        value: parsed.value,
        confidence: confidence,
        extractorType: extractorRule.type,
        source: extraction.source,
        evidence: extraction.evidence,
      );
      fieldEvidence[extractorRule.field] = extraction.evidence;
      if (extractorRule.field.startsWith('details.')) {
        _writeDetailsValue(details, extractorRule.field, parsed.value);
      }
    }

    if (!details.containsKey('remaining_text')) {
      final extraction = _extractRemainingLines(
        rule: const BillingFieldExtractorRule(
          field: 'details.remaining_text',
          type: BillingRuleExtractorTypes.remainingLines,
          confidence: 0.7,
        ),
        lines: lines,
        fieldEvidence: fieldEvidence,
        extraUsedLineIndexes: extractedLabelLineIndexes,
        templateId: selected.id,
      );
      if (extraction != null) {
        final parsed = BillingRuleParsers.parse(
          BillingRuleParserTypes.raw,
          extraction.text,
        );
        if (parsed.success && parsed.value != null) {
          fields['details.remaining_text'] = BillingRuleFieldResult(
            field: 'details.remaining_text',
            value: parsed.value,
            confidence: _clampConfidence(
              extraction.confidence * parsed.confidence,
            ),
            extractorType: BillingRuleExtractorTypes.remainingLines,
            source: extraction.source,
            evidence: extraction.evidence,
          );
          fieldEvidence['details.remaining_text'] = extraction.evidence;
          _writeDetailsValue(details, 'details.remaining_text', parsed.value);
        }
      }
    }

    result = BillingRuleResult(
      amount: amount,
      note: note,
      time: time,
      paymentChannel: paymentChannel,
      paymentMethod: paymentMethod,
      counterparty: counterparty,
      merchantFullName: merchantFullName,
      acquirer: acquirer,
      details: details.isEmpty ? null : details,
      confidence: _resultConfidence(selected, fields),
      matchedTemplateId: selected.id,
      fields: fields,
      aiEnhanceStatus: AiEnhanceStatus.skipped,
    );
    _emitTrace(
      traceSink: traceSink,
      ruleSet: ruleSet,
      ocrText: ocrText,
      sourcePackage: sourcePackage,
      sourceAppName: sourceAppName,
      sourcePaymentChannel: sourcePaymentChannel,
      preprocessResult: preprocessResult,
      matches: matches,
      fieldEvidence: fieldEvidence,
      result: result,
      startedAt: startedAt,
      debugMessages: debugMessages,
    );
    return result;
  }

  List<_TemplateMatch> _matchTemplates(
    BillingRuleSet ruleSet,
    String ocrText,
    String? sourcePackage,
    String? sourceAppName,
  ) {
    final matches = <_TemplateMatch>[];
    final normalizedSourceAppName = sourceAppName?.trim();
    for (final template in ruleSet.templates) {
      if (!template.enabled) continue;
      final match = template.match;
      if (match.sourcePackages.isNotEmpty &&
          sourcePackage != null &&
          !match.sourcePackages.contains(sourcePackage)) {
        continue;
      }
      if (match.appNameKeywords.isNotEmpty &&
          (normalizedSourceAppName == null ||
              normalizedSourceAppName.isEmpty ||
              !match.appNameKeywords.any(
                (keyword) => normalizedSourceAppName.contains(keyword),
              ))) {
        continue;
      }
      if (match.keywordsAll.any((keyword) => !ocrText.contains(keyword))) {
        continue;
      }
      if (match.keywordsAny.isNotEmpty &&
          !match.keywordsAny.any(ocrText.contains)) {
        continue;
      }

      final matchedKeywords = [
        ...match.keywordsAll,
        ...match.keywordsAny.where(ocrText.contains),
      ];
      final evidence = <String>[
        if (sourcePackage != null &&
            match.sourcePackages.contains(sourcePackage))
          'sourcePackage:$sourcePackage',
        if (normalizedSourceAppName != null)
          ...match.appNameKeywords
              .where((keyword) => normalizedSourceAppName.contains(keyword))
              .map((keyword) => 'sourceAppName:$keyword'),
        ...matchedKeywords.map((keyword) => 'keyword:$keyword'),
      ];
      matches.add(
        _TemplateMatch(
          template: template,
          match: BillingRuleMatch(
            templateId: template.id,
            confidence: _templateConfidence(template, evidence),
            evidence: evidence,
            matchedKeywords: matchedKeywords,
            sourcePackage: sourcePackage,
            sourceAppName: normalizedSourceAppName,
          ),
        ),
      );
    }
    matches.sort((left, right) {
      final priorityCompare = right.template.priority.compareTo(
        left.template.priority,
      );
      if (priorityCompare != 0) return priorityCompare;
      return left.template.id.compareTo(right.template.id);
    });
    return matches;
  }
}

class _TemplateMatch {
  final BillingRuleTemplate template;
  final BillingRuleMatch match;

  const _TemplateMatch({
    required this.template,
    required this.match,
  });
}

void _emitTrace({
  required BillingRuleTraceSink? traceSink,
  required BillingRuleSet ruleSet,
  required String ocrText,
  required String? sourcePackage,
  required String? sourceAppName,
  required String? sourcePaymentChannel,
  required OcrPreprocessResult? preprocessResult,
  required List<_TemplateMatch> matches,
  required Map<String, List<BillingRuleFieldEvidence>> fieldEvidence,
  required BillingRuleResult result,
  required DateTime startedAt,
  required List<String> debugMessages,
}) {
  if (traceSink == null) return;
  final completedAt = DateTime.now();
  traceSink(
    BillingRuleTrace(
      traceId: 'rule-${startedAt.microsecondsSinceEpoch}',
      rulesVersion: ruleSet.rulesVersion,
      sourcePackage: sourcePackage,
      sourceAppName: sourceAppName,
      sourcePaymentChannel: sourcePaymentChannel,
      ocrText: ocrText,
      preprocessResult: preprocessResult,
      matchedRuleIds: matches.map((match) => match.template.id).toList(),
      fieldEvidence: fieldEvidence,
      result: result,
      durationMs: completedAt.difference(startedAt).inMilliseconds,
      startedAt: startedAt,
      completedAt: completedAt,
      debugMessages: debugMessages,
    ),
  );
}

List<String> _splitLines(String text) {
  return text.split(RegExp(r'\r\n|\n|\r')).map((line) => line.trim()).toList();
}

double _templateConfidence(
  BillingRuleTemplate template,
  List<String> evidence,
) {
  return _clampConfidence(template.baseConfidence + evidence.length * 0.01);
}

double _resultConfidence(
  BillingRuleTemplate template,
  Map<String, BillingRuleFieldResult> fields,
) {
  if (fields.isEmpty) return 0;
  final fieldAverage =
      fields.values.map((field) => field.confidence).reduce((a, b) => a + b) /
          fields.length;
  return _clampConfidence((template.baseConfidence + fieldAverage) / 2);
}

double _clampConfidence(double value) {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

void _writeDetailsValue(
  Map<String, dynamic> details,
  String fieldPath,
  Object? value,
) {
  final parts = fieldPath.split('.').skip(1).toList();
  if (parts.isEmpty) return;
  var current = details;
  for (final part in parts.take(parts.length - 1)) {
    final next = current.putIfAbsent(part, () => <String, dynamic>{});
    if (next is Map<String, dynamic>) {
      current = next;
    } else {
      return;
    }
  }
  current[parts.last] = value;
}

BillingRuleExtraction? _extractRemainingLines({
  required BillingFieldExtractorRule rule,
  required List<String> lines,
  required Map<String, List<BillingRuleFieldEvidence>> fieldEvidence,
  Set<int> extraUsedLineIndexes = const {},
  required String templateId,
}) {
  final usedLineIndexes = <int>{...extraUsedLineIndexes};
  for (final evidences in fieldEvidence.values) {
    for (final evidence in evidences) {
      final index = evidence.lineIndex;
      if (index == null) continue;
      usedLineIndexes.add(index);
      final end = evidence.end;
      if (evidence.start == null &&
          end != null &&
          end > index &&
          end <= lines.length) {
        for (var i = index; i < end; i++) {
          usedLineIndexes.add(i);
        }
      }
    }
  }

  final excludeLabels = _stringOptionList(rule.options['excludeLabels']);
  final excludePatterns = _regexOptionList(rule.options['excludePatterns']);
  final values = <String>[];
  final evidences = <BillingRuleFieldEvidence>[];
  for (var index = 0; index < lines.length; index++) {
    if (usedLineIndexes.contains(index)) continue;
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    if (excludeLabels.any(line.contains)) continue;
    if (excludePatterns.any((pattern) => pattern.hasMatch(line))) continue;
    values.add(line);
    evidences.add(
      BillingRuleFieldEvidence(
        type: rule.type,
        text: line,
        lineIndex: index,
        ruleId: templateId,
      ),
    );
  }
  final text = values.join('\n').trim();
  if (text.isEmpty) return null;
  return BillingRuleExtraction(
    text: text,
    source: text,
    confidence: rule.confidence,
    evidence: evidences,
  );
}

int? _findLabelLine(List<String> lines, String? label) {
  if (label == null || label.isEmpty) return null;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].trim().contains(label)) return index;
  }
  return null;
}

List<String> _stringOptionList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

List<RegExp> _regexOptionList(Object? value) {
  if (value is! List) return const [];
  final result = <RegExp>[];
  for (final item in value) {
    try {
      result.add(RegExp(item.toString()));
    } on FormatException {
      continue;
    }
  }
  return result;
}
