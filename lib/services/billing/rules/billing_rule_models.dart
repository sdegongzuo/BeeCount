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

enum BillingRuleOrigin { public, personal }

enum BillingExtractorSelection { firstSuccessful, highestConfidence }

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

  factory BillingRuleSet.activeSnapshot({
    required BillingRuleSet publicRules,
    required BillingRuleSet personalRules,
  }) {
    if (publicRules.schemaVersion != personalRules.schemaVersion) {
      throw ArgumentError('Rule sets must use the same schema version');
    }
    return BillingRuleSet(
      schemaVersion: publicRules.schemaVersion,
      rulesVersion: '${publicRules.rulesVersion}+${personalRules.rulesVersion}',
      paymentChannels: [
        ...publicRules.paymentChannels,
        ...personalRules.paymentChannels,
      ],
      templates: [
        ...publicRules.templates.map(
          (template) => template.copyWith(origin: BillingRuleOrigin.public),
        ),
        ...personalRules.templates.map(
          (template) => template.copyWith(origin: BillingRuleOrigin.personal),
        ),
      ],
      source: 'active-snapshot',
      loadedAt: DateTime.now(),
    );
  }

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
  final BillingRuleOrigin origin;
  final int revision;
  final BillingExtractorSelection extractorSelection;

  const BillingRuleTemplate({
    required this.id,
    required this.match,
    required this.extractors,
    this.enabled = true,
    this.priority = 0,
    this.baseConfidence = 0.8,
    this.origin = BillingRuleOrigin.public,
    this.revision = 1,
    this.extractorSelection = BillingExtractorSelection.firstSuccessful,
  });

  factory BillingRuleTemplate.fromJson(
    Map<String, dynamic> json, {
    BillingRuleOrigin origin = BillingRuleOrigin.personal,
  }) {
    final match = Map<String, dynamic>.from(json['match'] as Map);
    List<String> strings(String key) =>
        (match[key] as List?)?.whereType<String>().toList() ?? const [];
    return BillingRuleTemplate(
      id: json['id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      baseConfidence: (json['base_confidence'] as num?)?.toDouble() ?? 0.8,
      origin: origin,
      revision: json['revision'] as int? ?? 1,
      extractorSelection: json['extractor_selection'] == 'highestConfidence'
          ? BillingExtractorSelection.highestConfidence
          : BillingExtractorSelection.firstSuccessful,
      match: BillingRuleTemplateMatch(
        sourcePackages: strings('source_packages'),
        requiredSource: match['required_source'] as bool? ?? false,
        appNameKeywords: strings('app_name_keywords'),
        keywordsAll: strings('keywords_all'),
        keywordsAny: strings('keywords_any'),
      ),
      extractors:
          (json['extractors'] as List? ?? const []).whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        return BillingFieldExtractorRule(
          id: item['id'] as String?,
          field: item['field'] as String,
          type: item['type'] as String,
          value: item['value'] as String?,
          label: item['label'] as String?,
          parser: item['parser'] as String?,
          pattern: item['pattern'] as String?,
          confidence: (item['confidence'] as num?)?.toDouble() ?? 0.8,
          options:
              (item['options'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
      }).toList(growable: false),
    );
  }

  int get specificity => match.specificity;

  BillingRuleTemplate copyWith({BillingRuleOrigin? origin}) =>
      BillingRuleTemplate(
        id: id,
        match: match,
        extractors: extractors,
        enabled: enabled,
        priority: priority,
        baseConfidence: baseConfidence,
        origin: origin ?? this.origin,
        revision: revision,
        extractorSelection: extractorSelection,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'priority': priority,
        'match': match.toJson(),
        'extractors':
            extractors.map((extractor) => extractor.toJson()).toList(),
        'base_confidence': baseConfidence,
        'origin': origin.name,
        'revision': revision,
        'extractor_selection': extractorSelection.name,
      };
}

class BillingRuleTemplateMatch {
  final List<String> sourcePackages;
  final bool requiredSource;
  final List<String> appNameKeywords;
  final List<String> keywordsAll;
  final List<String> keywordsAny;

  const BillingRuleTemplateMatch({
    this.sourcePackages = const [],
    this.requiredSource = false,
    this.appNameKeywords = const [],
    this.keywordsAll = const [],
    this.keywordsAny = const [],
  });

  int get specificity =>
      sourcePackages.length * 100 +
      appNameKeywords.length * 50 +
      keywordsAll.length * 10 +
      keywordsAny.length;

  Map<String, dynamic> toJson() => {
        'source_packages': sourcePackages,
        'required_source': requiredSource,
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
  final int specificity;

  const BillingRuleMatch({
    required this.templateId,
    required this.confidence,
    this.evidence = const [],
    this.matchedKeywords = const [],
    this.sourcePackage,
    this.sourceAppName,
    this.specificity = 0,
  });

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'confidence': confidence,
        'evidence': evidence,
        'matched_keywords': matchedKeywords,
        'source_package': sourcePackage,
        'source_app_name': sourceAppName,
        'specificity': specificity,
      };
}

class BillingFieldExtractorRule {
  final String? id;
  final String field;
  final String type;
  final String? value;
  final String? label;
  final String? parser;
  final String? pattern;
  final double confidence;
  final Map<String, dynamic> options;

  const BillingFieldExtractorRule({
    this.id,
    required this.field,
    required this.type,
    this.value,
    this.label,
    this.parser,
    this.pattern,
    this.confidence = 0.8,
    this.options = const {},
  });

  String resolvedId(String templateId) {
    if (id != null && id!.trim().isNotEmpty) return id!;
    final identity = [field, type, value, label, parser, pattern].join('|');
    var hash = 0x811c9dc5;
    for (final unit in identity.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return '$templateId:extract:${hash.toRadixString(16).padLeft(8, '0')}';
  }

  BillingFieldExtractorRule withResolvedId(String templateId) =>
      BillingFieldExtractorRule(
        id: resolvedId(templateId),
        field: field,
        type: type,
        value: value,
        label: label,
        parser: parser,
        pattern: pattern,
        confidence: confidence,
        options: options,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
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

  Map<String, dynamic> toDebugJson({bool includeSensitive = false}) => {
        ...toJson(),
        'fields': fields.map(
          (field, result) => MapEntry(
            field,
            result.toDebugJson(includeSensitive: includeSensitive),
          ),
        ),
      };
}

class BillingRuleFieldResult {
  final String field;
  final Object? rawValue;
  final Object? value;
  final double confidence;
  final String extractorType;
  final String? extractorId;
  final String? source;
  final List<BillingRuleFieldEvidence> evidence;

  const BillingRuleFieldResult({
    required this.field,
    required this.value,
    this.rawValue,
    required this.confidence,
    required this.extractorType,
    this.extractorId,
    this.source,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'value': _jsonValue(value),
        'confidence': confidence,
        'extractor_type': extractorType,
        if (extractorId != null) 'extractor_id': extractorId,
        'source': source,
        'evidence': evidence.map((item) => item.toJson()).toList(),
      };

  Map<String, dynamic> toDebugJson({bool includeSensitive = false}) => {
        ...toJson(),
        'raw_value': _jsonValue(
          includeSensitive ? rawValue : _redactSensitiveValue(rawValue),
        ),
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

Object? _redactSensitiveValue(Object? value) {
  if (value is! String) return value;
  return value.replaceAllMapped(
    RegExp(r'\d{7,}'),
    (match) => '${'*' * (match.group(0)!.length - 4)}'
        '${match.group(0)!.substring(match.group(0)!.length - 4)}',
  );
}
