import 'billing_rule_models.dart';

class BillingRuleExtractorTypes {
  static const constant = 'constant';
  static const regex = 'regex';
  static const labelNextLine = 'labelNextLine';
  static const labelSameLine = 'labelSameLine';
  static const labelPreviousLine = 'labelPreviousLine';
  static const betweenLabels = 'betweenLabels';
  static const nearKeyword = 'nearKeyword';
}

class BillingRuleExtraction {
  final String text;
  final String source;
  final double confidence;
  final List<BillingRuleFieldEvidence> evidence;

  const BillingRuleExtraction({
    required this.text,
    required this.source,
    required this.confidence,
    required this.evidence,
  });
}

class BillingRuleExtractors {
  static BillingRuleExtraction? extract({
    required BillingFieldExtractorRule rule,
    required String ocrText,
    required List<String> lines,
    required String templateId,
  }) {
    switch (rule.type) {
      case BillingRuleExtractorTypes.constant:
        return _constant(rule, templateId);
      case BillingRuleExtractorTypes.regex:
        return _regex(rule, ocrText, lines, templateId);
      case BillingRuleExtractorTypes.labelNextLine:
        return _labelNextLine(rule, lines, templateId);
      case BillingRuleExtractorTypes.labelSameLine:
        return _labelSameLine(rule, lines, templateId);
      case BillingRuleExtractorTypes.labelPreviousLine:
        return _labelPreviousLine(rule, lines, templateId);
      case BillingRuleExtractorTypes.betweenLabels:
        return _betweenLabels(rule, lines, templateId);
      case BillingRuleExtractorTypes.nearKeyword:
        return _nearKeyword(rule, lines, templateId);
      default:
        return null;
    }
  }

  static BillingRuleExtraction? _constant(
    BillingFieldExtractorRule rule,
    String templateId,
  ) {
    final value = rule.value?.trim();
    if (value == null || value.isEmpty) return null;
    return BillingRuleExtraction(
      text: value,
      source: value,
      confidence: rule.confidence,
      evidence: [
        BillingRuleFieldEvidence(
          type: rule.type,
          text: value,
          ruleId: templateId,
        ),
      ],
    );
  }

  static BillingRuleExtraction? _regex(
    BillingFieldExtractorRule rule,
    String ocrText,
    List<String> lines,
    String templateId,
  ) {
    final pattern = rule.pattern;
    if (pattern == null || pattern.isEmpty) return null;
    final match = RegExp(pattern, multiLine: true).firstMatch(ocrText);
    if (match == null) return null;
    final text = _matchText(match);
    if (text.isEmpty) return null;
    return BillingRuleExtraction(
      text: text,
      source: match.group(0) ?? text,
      confidence: rule.confidence,
      evidence: [
        BillingRuleFieldEvidence(
          type: rule.type,
          text: match.group(0) ?? text,
          lineIndex: _lineIndexForOffset(lines, ocrText, match.start),
          start: match.start,
          end: match.end,
          ruleId: templateId,
        ),
      ],
    );
  }

  static BillingRuleExtraction? _labelNextLine(
    BillingFieldExtractorRule rule,
    List<String> lines,
    String templateId,
  ) {
    final labelIndex = _findLabelLine(lines, rule.label);
    if (labelIndex == null) return null;
    final valueIndex = _nextNonEmptyLine(lines, labelIndex + 1);
    if (valueIndex == null) return null;
    return _lineExtraction(rule, lines[valueIndex], valueIndex, templateId);
  }

  static BillingRuleExtraction? _labelPreviousLine(
    BillingFieldExtractorRule rule,
    List<String> lines,
    String templateId,
  ) {
    final labelIndex = _findLabelLine(lines, rule.label);
    if (labelIndex == null) return null;
    final valueIndex = _previousNonEmptyLine(lines, labelIndex - 1);
    if (valueIndex == null) return null;
    return _lineExtraction(rule, lines[valueIndex], valueIndex, templateId);
  }

  static BillingRuleExtraction? _labelSameLine(
    BillingFieldExtractorRule rule,
    List<String> lines,
    String templateId,
  ) {
    final labelIndex = _findLabelLine(lines, rule.label);
    if (labelIndex == null) return null;
    final line = lines[labelIndex].trim();
    final stripped = _stripLabel(rule, line);
    if (stripped == null || stripped.isEmpty) return null;
    final text = _applyPattern(rule, stripped) ?? stripped;
    if (text.isEmpty) return null;
    return BillingRuleExtraction(
      text: text,
      source: line,
      confidence: rule.confidence,
      evidence: [
        BillingRuleFieldEvidence(
          type: rule.type,
          text: line,
          lineIndex: labelIndex,
          ruleId: templateId,
        ),
      ],
    );
  }

  static BillingRuleExtraction? _betweenLabels(
    BillingFieldExtractorRule rule,
    List<String> lines,
    String templateId,
  ) {
    final startIndex = _findLabelLine(lines, rule.label);
    if (startIndex == null) return null;
    final endLabel = rule.options['endLabel'] as String?;
    final values = <String>[];
    var endIndex = lines.length;
    for (var index = startIndex + 1; index < lines.length; index++) {
      final line = lines[index].trim();
      if (endLabel != null && line.contains(endLabel)) {
        endIndex = index;
        break;
      }
      if (line.isNotEmpty) values.add(line);
    }
    final text = values.join('\n').trim();
    if (text.isEmpty) return null;
    final extracted = _applyPattern(rule, text) ?? text;
    if (extracted.isEmpty) return null;
    return BillingRuleExtraction(
      text: extracted,
      source: text,
      confidence: rule.confidence,
      evidence: [
        BillingRuleFieldEvidence(
          type: rule.type,
          text: text,
          lineIndex: startIndex + 1,
          end: endIndex,
          ruleId: templateId,
        ),
      ],
    );
  }

  static BillingRuleExtraction? _nearKeyword(
    BillingFieldExtractorRule rule,
    List<String> lines,
    String templateId,
  ) {
    final keywordIndex = _findLabelLine(lines, rule.label);
    if (keywordIndex == null) return null;
    final window = _intOption(rule.options['windowLines']) ?? 1;
    final start = (keywordIndex - window).clamp(0, lines.length - 1);
    final end = (keywordIndex + window).clamp(0, lines.length - 1);
    for (var index = start; index <= end; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final extracted = _applyPattern(rule, line) ?? _stripLabel(rule, line);
      if (extracted == null || extracted.isEmpty) continue;
      return BillingRuleExtraction(
        text: extracted,
        source: line,
        confidence: rule.confidence,
        evidence: [
          BillingRuleFieldEvidence(
            type: rule.type,
            text: line,
            lineIndex: index,
            ruleId: templateId,
          ),
        ],
      );
    }
    return null;
  }

  static BillingRuleExtraction? _lineExtraction(
    BillingFieldExtractorRule rule,
    String line,
    int lineIndex,
    String templateId,
  ) {
    final source = line.trim();
    final text = _applyPattern(rule, source) ?? source;
    if (text.isEmpty) return null;
    return BillingRuleExtraction(
      text: text,
      source: source,
      confidence: rule.confidence,
      evidence: [
        BillingRuleFieldEvidence(
          type: rule.type,
          text: source,
          lineIndex: lineIndex,
          ruleId: templateId,
        ),
      ],
    );
  }
}

String _matchText(RegExpMatch match) {
  if (match.groupCount > 0) {
    return match.group(1)?.trim() ?? '';
  }
  return match.group(0)?.trim() ?? '';
}

String? _applyPattern(BillingFieldExtractorRule rule, String source) {
  final pattern = rule.pattern;
  if (pattern == null || pattern.isEmpty) return null;
  final match = RegExp(pattern, multiLine: true).firstMatch(source);
  if (match == null) return null;
  return _matchText(match);
}

String? _stripLabel(BillingFieldExtractorRule rule, String source) {
  final label = rule.label;
  if (label == null || label.isEmpty || !source.contains(label)) {
    return null;
  }
  return source
      .replaceFirst(label, '')
      .replaceFirst(RegExp(r'^[\s:：-]+'), '')
      .trim();
}

int? _findLabelLine(List<String> lines, String? label) {
  if (label == null || label.isEmpty) return null;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].trim().contains(label)) return index;
  }
  return null;
}

int? _nextNonEmptyLine(List<String> lines, int start) {
  for (var index = start; index < lines.length; index++) {
    if (lines[index].trim().isNotEmpty) return index;
  }
  return null;
}

int? _previousNonEmptyLine(List<String> lines, int start) {
  for (var index = start; index >= 0; index--) {
    if (lines[index].trim().isNotEmpty) return index;
  }
  return null;
}

int _lineIndexForOffset(List<String> lines, String ocrText, int offset) {
  var consumed = 0;
  for (var index = 0; index < lines.length; index++) {
    consumed += lines[index].length;
    if (offset <= consumed) return index;
    consumed += _lineBreakLengthAt(ocrText, consumed);
  }
  return lines.length - 1;
}

int _lineBreakLengthAt(String text, int offset) {
  if (offset >= text.length) return 0;
  if (text.startsWith('\r\n', offset)) return 2;
  if (text[offset] == '\n' || text[offset] == '\r') return 1;
  return 0;
}

int? _intOption(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
