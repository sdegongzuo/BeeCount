enum AiEnhanceStatus {
  pending,
  completed,
  failed,
  timeout,
  skipped,
}

extension AiEnhanceStatusJson on AiEnhanceStatus {
  String get wireName {
    switch (this) {
      case AiEnhanceStatus.pending:
        return 'pending';
      case AiEnhanceStatus.completed:
        return 'completed';
      case AiEnhanceStatus.failed:
        return 'failed';
      case AiEnhanceStatus.timeout:
        return 'timeout';
      case AiEnhanceStatus.skipped:
        return 'skipped';
    }
  }
}

AiEnhanceStatus parseAiEnhanceStatus(
  String? value, {
  AiEnhanceStatus fallback = AiEnhanceStatus.skipped,
}) {
  final normalized = value?.trim();
  for (final status in AiEnhanceStatus.values) {
    if (status.wireName == normalized) return status;
  }
  return fallback;
}

class BillingImageRegion {
  final int left;
  final int top;
  final int width;
  final int height;

  const BillingImageRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };
}

class OcrPreprocessResult {
  final String method;
  final String? originalPath;
  final String? outputPath;
  final int? originalWidth;
  final int? originalHeight;
  final int? outputWidth;
  final int? outputHeight;
  final BillingImageRegion? cropRect;
  final List<BillingImageRegion> maskedRegions;
  final Map<String, dynamic> metadata;

  const OcrPreprocessResult({
    required this.method,
    this.originalPath,
    this.outputPath,
    this.originalWidth,
    this.originalHeight,
    this.outputWidth,
    this.outputHeight,
    this.cropRect,
    this.maskedRegions = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'original_path': originalPath,
        'output_path': outputPath,
        'original_width': originalWidth,
        'original_height': originalHeight,
        'output_width': outputWidth,
        'output_height': outputHeight,
        'crop_rect': cropRect?.toJson(),
        'masked_regions':
            maskedRegions.map((region) => region.toJson()).toList(),
        'metadata': _jsonValue(metadata),
      };
}

class BillingRuleSet {
  final int schemaVersion;
  final String rulesVersion;
  final List<BillingPaymentChannelRule> paymentChannels;
  final List<BillingRuleTemplate> templates;
  final String? source;
  final DateTime? loadedAt;

  const BillingRuleSet({
    required this.schemaVersion,
    required this.rulesVersion,
    required this.paymentChannels,
    required this.templates,
    this.source,
    this.loadedAt,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'rules_version': rulesVersion,
        'payment_channels':
            paymentChannels.map((channel) => channel.toJson()).toList(),
        'templates': templates.map((template) => template.toJson()).toList(),
        'source': source,
        'loaded_at': loadedAt?.toIso8601String(),
      };
}

class BillingPaymentChannelRule {
  final String channel;
  final List<String> packages;
  final List<String> appNameKeywords;
  final double confidence;

  const BillingPaymentChannelRule({
    required this.channel,
    this.packages = const [],
    this.appNameKeywords = const [],
    this.confidence = 0.9,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'packages': packages,
        'app_name_keywords': appNameKeywords,
        'confidence': confidence,
      };
}

class BillingRuleTemplate {
  final String id;
  final bool enabled;
  final int priority;
  final BillingRuleTemplateMatch match;
  final List<BillingFieldExtractorRule> extractors;
  final double baseConfidence;

  const BillingRuleTemplate({
    required this.id,
    required this.match,
    required this.extractors,
    this.enabled = true,
    this.priority = 0,
    this.baseConfidence = 0.8,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'priority': priority,
        'match': match.toJson(),
        'extractors':
            extractors.map((extractor) => extractor.toJson()).toList(),
        'base_confidence': baseConfidence,
      };
}

class BillingRuleTemplateMatch {
  final List<String> sourcePackages;
  final List<String> appNameKeywords;
  final List<String> keywordsAll;
  final List<String> keywordsAny;

  const BillingRuleTemplateMatch({
    this.sourcePackages = const [],
    this.appNameKeywords = const [],
    this.keywordsAll = const [],
    this.keywordsAny = const [],
  });

  Map<String, dynamic> toJson() => {
        'source_packages': sourcePackages,
        'app_name_keywords': appNameKeywords,
        'keywords_all': keywordsAll,
        'keywords_any': keywordsAny,
      };
}

class BillingRuleMatch {
  final String templateId;
  final double confidence;
  final List<String> evidence;
  final List<String> matchedKeywords;
  final String? sourcePackage;
  final String? sourceAppName;

  const BillingRuleMatch({
    required this.templateId,
    required this.confidence,
    this.evidence = const [],
    this.matchedKeywords = const [],
    this.sourcePackage,
    this.sourceAppName,
  });

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'confidence': confidence,
        'evidence': evidence,
        'matched_keywords': matchedKeywords,
        'source_package': sourcePackage,
        'source_app_name': sourceAppName,
      };
}

class BillingFieldExtractorRule {
  final String field;
  final String type;
  final String? value;
  final String? label;
  final String? parser;
  final String? pattern;
  final double confidence;
  final Map<String, dynamic> options;

  const BillingFieldExtractorRule({
    required this.field,
    required this.type,
    this.value,
    this.label,
    this.parser,
    this.pattern,
    this.confidence = 0.8,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'type': type,
        'value': value,
        'label': label,
        'parser': parser,
        'pattern': pattern,
        'confidence': confidence,
        'options': _jsonValue(options),
      };
}

class BillingRuleResult {
  final double? amount;
  final String? note;
  final DateTime? time;
  final String? paymentChannel;
  final String? paymentMethod;
  final String? counterparty;
  final String? merchantFullName;
  final String? acquirer;
  final Map<String, dynamic>? details;
  final double confidence;
  final String? matchedTemplateId;
  final Map<String, BillingRuleFieldResult> fields;
  final AiEnhanceStatus aiEnhanceStatus;

  const BillingRuleResult({
    this.amount,
    this.note,
    this.time,
    this.paymentChannel,
    this.paymentMethod,
    this.counterparty,
    this.merchantFullName,
    this.acquirer,
    this.details,
    this.confidence = 0,
    this.matchedTemplateId,
    this.fields = const {},
    this.aiEnhanceStatus = AiEnhanceStatus.skipped,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'note': note,
        'time': time?.toIso8601String(),
        'payment_channel': paymentChannel,
        'payment_method': paymentMethod,
        'counterparty': counterparty,
        'merchant_full_name': merchantFullName,
        'acquirer': acquirer,
        'details': details == null ? null : _jsonValue(details!),
        'confidence': confidence,
        'matched_template_id': matchedTemplateId,
        'fields': fields.map(
          (field, result) => MapEntry(field, result.toJson()),
        ),
        'ai_enhance_status': aiEnhanceStatus.wireName,
      };

  Map<String, dynamic> toDebugJson() => toJson();
}

class BillingRuleFieldResult {
  final String field;
  final Object? value;
  final double confidence;
  final String extractorType;
  final String? source;
  final List<BillingRuleFieldEvidence> evidence;

  const BillingRuleFieldResult({
    required this.field,
    required this.value,
    required this.confidence,
    required this.extractorType,
    this.source,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'value': _jsonValue(value),
        'confidence': confidence,
        'extractor_type': extractorType,
        'source': source,
        'evidence': evidence.map((item) => item.toJson()).toList(),
      };
}

class BillingRuleFieldEvidence {
  final String type;
  final String text;
  final int? lineIndex;
  final int? start;
  final int? end;
  final String? ruleId;

  const BillingRuleFieldEvidence({
    required this.type,
    required this.text,
    this.lineIndex,
    this.start,
    this.end,
    this.ruleId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'line_index': lineIndex,
        'start': start,
        'end': end,
        'rule_id': ruleId,
      };
}

dynamic _jsonValue(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value is Enum) return value.name;
  if (value is List) return value.map(_jsonValue).toList();
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _jsonValue(item)),
    );
  }
  return value;
}
