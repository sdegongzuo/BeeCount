import 'dart:io';

import 'package:flutter/services.dart';
import 'package:toml/toml.dart';

import 'billing_rule_engine.dart';
import 'billing_rule_models.dart';
import 'billing_rule_storage.dart';
import '../payment_method_semantics.dart';

typedef BillingRuleFileLoader = Future<String?> Function(File file);

/// 读取当前不可变规则集的延迟加载器。
typedef BillingRuleSetLoader = Future<BillingRuleSet> Function();

/// 取得公共规则文件布局的延迟加载器。
typedef BillingRuleStorageLoader = Future<BillingRuleStorage> Function();

/// 生产公共规则仓库：缓存当前不可变快照，并在活动指针切换后显式失效。
///
/// 单次图片处理不会反复读取磁盘；更新服务完成原子切换后调用
/// [invalidateActiveSnapshot]，下一张图片会重新读取 active/previous/built-in
/// 三级安全链。进程重启时缓存自然为空，因此会读取已激活文件。
class RuntimeBillingRuleRepository implements BillingRuleRepository {
  final BillingRuleStorageLoader _storageLoader;
  final AssetBundle _assetBundle;
  final String _builtInAssetPath;
  final File? _debugOverrideRuleFile;
  final BillingRuleFileLoader _fileLoader;

  Future<TomlBillingRuleRepository>? _delegate;
  Future<BillingRuleSet>? _activeSnapshot;

  /// 创建一个可测试的运行时仓库。
  RuntimeBillingRuleRepository({
    required BillingRuleStorageLoader storageLoader,
    AssetBundle? assetBundle,
    String builtInAssetPath = TomlBillingRuleRepository.defaultBuiltInAssetPath,
    File? debugOverrideRuleFile,
    BillingRuleFileLoader? fileLoader,
  })  : _storageLoader = storageLoader,
        _assetBundle = assetBundle ?? rootBundle,
        _builtInAssetPath = builtInAssetPath,
        _debugOverrideRuleFile = debugOverrideRuleFile,
        _fileLoader = fileLoader ?? _readExistingFile;

  Future<TomlBillingRuleRepository> _repository() =>
      _delegate ??= _createRepository();

  Future<TomlBillingRuleRepository> _createRepository() async {
    final storage = await _storageLoader();
    return TomlBillingRuleRepository(
      assetBundle: _assetBundle,
      builtInAssetPath: _builtInAssetPath,
      activeRuleFile: storage.activeFile,
      previousRuleFile: storage.previousFile,
      debugOverrideRuleFile: _debugOverrideRuleFile,
      fileLoader: _fileLoader,
    );
  }

  /// 使当前内存快照失效；下一次读取会加载刚原子激活的文件。
  void invalidateActiveSnapshot() {
    _activeSnapshot = null;
  }

  @override
  Future<BillingRuleSet> loadActiveRuleSet() {
    return _activeSnapshot ??= _loadActiveRuleSet();
  }

  Future<BillingRuleSet> _loadActiveRuleSet() async {
    try {
      return await (await _repository()).loadActiveRuleSet();
    } catch (_) {
      _activeSnapshot = null;
      rethrow;
    }
  }

  Future<BillingRuleSet?> loadPublicSnapshot({
    required int rulePackageVersion,
    required String rulesVersion,
    required int normalizationVersion,
  }) async {
    final repository = await _repository();
    final candidates = <BillingRuleSet?>[
      await repository.loadDebugOverrideRuleSet(),
      await repository.loadActiveFileRuleSet(),
      await repository.loadPreviousRuleSet(),
      await repository.loadBuiltInRuleSet(),
    ];
    for (final candidate in candidates.whereType<BillingRuleSet>()) {
      if (candidate.rulePackageVersion == rulePackageVersion &&
          candidate.rulesVersion == rulesVersion &&
          candidate.normalizationVersion == normalizationVersion) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Future<BillingRuleSet> loadBuiltInRuleSet() async =>
      (await _repository()).loadBuiltInRuleSet();

  @override
  Future<BillingRuleSet?> loadDebugOverrideRuleSet() async =>
      (await _repository()).loadDebugOverrideRuleSet();

  @override
  Future<void> validateRuleSet(BillingRuleSet ruleSet) async =>
      (await _repository()).validateRuleSet(ruleSet);
}

RuntimeBillingRuleRepository? _productionRuntimeRepository;

/// 返回 OCR、BillingJob 与同步共同使用的进程内生产公共规则仓库。
RuntimeBillingRuleRepository productionBillingRuleRepository() =>
    _productionRuntimeRepository ??= RuntimeBillingRuleRepository(
      storageLoader: productionBillingRuleStorage,
    );

/// 通知生产仓库活动文件已经完成原子切换。
void invalidateProductionBillingRuleSnapshot() =>
    _productionRuntimeRepository?.invalidateActiveSnapshot();

/// 生产活动快照：公共 TOML 与 SQLite 活动个人修订在每次评估前合并。
class ActiveBillingRuleRepository implements BillingRuleRepository {
  /// 公共 TOML 规则的权威仓库。
  final BillingRuleRepository publicRepository;

  /// 从 SQLite 活动版本指针读取个人规则。
  final BillingRuleSetLoader loadActivePersonalRules;

  /// 创建在每次评估前原子读取并合并两层规则的仓库。
  const ActiveBillingRuleRepository({
    required this.publicRepository,
    required this.loadActivePersonalRules,
  });

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async {
    final publicRules = await publicRepository.loadActiveRuleSet();
    final personalRules = await loadActivePersonalRules();
    return BillingRuleSet.activeSnapshot(
      publicRules: publicRules,
      personalRules: personalRules,
    );
  }

  @override
  Future<BillingRuleSet> loadBuiltInRuleSet() =>
      publicRepository.loadBuiltInRuleSet();

  @override
  Future<BillingRuleSet?> loadDebugOverrideRuleSet() =>
      publicRepository.loadDebugOverrideRuleSet();

  @override
  Future<void> validateRuleSet(BillingRuleSet ruleSet) =>
      publicRepository.validateRuleSet(ruleSet);
}

class BillingRuleRepositoryException implements Exception {
  final String message;
  final Object? cause;

  const BillingRuleRepositoryException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause == null) return 'BillingRuleRepositoryException: $message';
    return 'BillingRuleRepositoryException: $message ($cause)';
  }
}

class TomlBillingRuleRepository implements BillingRuleRepository {
  static const defaultBuiltInAssetPath = 'assets/rules/billing_rules.toml';

  static const supportedSchemaVersion = 1;

  static const allowedExtractorTypes = {
    'constant',
    'regex',
    'labelNextLine',
    'labelSameLine',
    'labelPreviousLine',
    'betweenLabels',
    'nearKeyword',
    'remainingLines',
  };

  static const allowedParsers = {
    'string',
    'signedAmount',
    'amount',
    'zhDatetime',
    'isoDatetime',
    'institutionName',
    'paymentMethod',
    'regexGroup',
    'raw',
  };

  static const _allowedTopLevelFields = {
    'amount',
    'note',
    'time',
    'paymentChannel',
    'paymentMethod',
    'counterparty',
    'merchantFullName',
    'acquirer',
  };

  final AssetBundle assetBundle;
  final String builtInAssetPath;
  final File? activeRuleFile;
  final File? previousRuleFile;
  final File? debugOverrideRuleFile;
  final BillingRuleFileLoader fileLoader;

  TomlBillingRuleRepository({
    AssetBundle? assetBundle,
    this.builtInAssetPath = defaultBuiltInAssetPath,
    this.activeRuleFile,
    this.previousRuleFile,
    this.debugOverrideRuleFile,
    BillingRuleFileLoader? fileLoader,
  })  : assetBundle = assetBundle ?? rootBundle,
        fileLoader = fileLoader ?? _readExistingFile;

  @override
  Future<BillingRuleSet> loadBuiltInRuleSet() async {
    final toml = await assetBundle.loadString(builtInAssetPath);
    return _parseToml(toml, source: 'asset:$builtInAssetPath');
  }

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async {
    final debugRuleSet = await loadDebugOverrideRuleSet();
    if (debugRuleSet != null) return debugRuleSet;

    final activeRuleSet = await _tryLoadFile(activeRuleFile);
    if (activeRuleSet != null) return activeRuleSet;

    final previousRuleSet = await _tryLoadFile(previousRuleFile);
    if (previousRuleSet != null) return previousRuleSet;

    return loadBuiltInRuleSet();
  }

  Future<BillingRuleSet?> loadActiveFileRuleSet() =>
      _tryLoadFile(activeRuleFile);

  Future<BillingRuleSet?> loadPreviousRuleSet() =>
      _tryLoadFile(previousRuleFile);

  @override
  Future<BillingRuleSet?> loadDebugOverrideRuleSet() {
    return _tryLoadFile(debugOverrideRuleFile);
  }

  @override
  Future<void> validateRuleSet(BillingRuleSet ruleSet) async {
    _validateRuleSet(ruleSet);
  }

  Future<BillingRuleSet?> _tryLoadFile(File? file) async {
    if (file == null) return null;
    try {
      final toml = await fileLoader(file);
      if (toml == null) return null;
      return _parseToml(toml, source: file.path);
    } on BillingRuleRepositoryException {
      return null;
    } on Object {
      return null;
    }
  }

  BillingRuleSet _parseToml(String toml, {required String source}) {
    final Map<String, dynamic> map;
    try {
      map = TomlDocument.parse(toml).toMap();
    } on Object catch (error) {
      throw BillingRuleRepositoryException('Invalid TOML document', error);
    }

    final ruleSet = BillingRuleSet(
      schemaVersion: _requiredInt(map, 'schemaVersion'),
      rulePackageVersion:
          _optionalInt(map['rulePackageVersion'], 0, 'rulePackageVersion'),
      rulesVersion: _requiredString(map, 'rulesVersion'),
      normalizationVersion:
          _optionalInt(map['normalizationVersion'], 0, 'normalizationVersion'),
      compatibleNormalizationVersions: _intList(
        map['compatibleNormalizationVersions'],
        'compatibleNormalizationVersions',
      ),
      paymentChannels: _parsePaymentChannels(map['paymentChannels']),
      templates: _parseTemplates(map['templates']),
      source: source,
      loadedAt: DateTime.now(),
    );
    _validateRuleSet(ruleSet);
    return ruleSet;
  }

  List<BillingPaymentChannelRule> _parsePaymentChannels(Object? value) {
    final items = _optionalList(value, 'paymentChannels');
    return items.map((item) {
      final map = _asMap(item, 'paymentChannels item');
      return BillingPaymentChannelRule(
        channel: _requiredString(map, 'channel'),
        packages: _stringList(map['packages'], 'packages'),
        appNameKeywords: _stringList(
          map['appNameKeywords'],
          'appNameKeywords',
        ),
        confidence: _optionalDouble(map['confidence'], 0.9, 'confidence'),
      );
    }).toList(growable: false);
  }

  List<BillingRuleTemplate> _parseTemplates(Object? value) {
    final items = _requiredList(value, 'templates');
    return items.map((item) {
      final map = _asMap(item, 'templates item');
      final match = _parseMatch(map['match']);
      final id = _requiredString(map, 'id');
      final extractors = _parseExtractors(id, map['extract']);
      return BillingRuleTemplate(
        id: id,
        enabled: _optionalBool(map['enabled'], true, 'enabled'),
        priority: _optionalInt(map['priority'], 0, 'priority'),
        match: match,
        extractors: extractors,
        baseConfidence: _optionalDouble(
          map['baseConfidence'],
          0.8,
          'baseConfidence',
        ),
        origin: _parseOrigin(map['origin']),
        revision: _optionalInt(map['revision'], 1, 'revision'),
        extractorSelection: _parseExtractorSelection(
          map['extractorSelection'],
        ),
      );
    }).toList(growable: false);
  }

  BillingRuleTemplateMatch _parseMatch(Object? value) {
    if (value == null) return const BillingRuleTemplateMatch();
    final map = _asMap(value, 'templates.match');
    return BillingRuleTemplateMatch(
      sourcePackages: _stringList(map['sourcePackages'], 'sourcePackages'),
      requiredSource: _optionalBool(
        map['requiredSource'],
        false,
        'requiredSource',
      ),
      appNameKeywords: _stringList(map['appNameKeywords'], 'appNameKeywords'),
      keywordsAll: _stringList(map['keywordsAll'], 'keywordsAll'),
      keywordsAny: _stringList(map['keywordsAny'], 'keywordsAny'),
    );
  }

  List<BillingFieldExtractorRule> _parseExtractors(
    String templateId,
    Object? value,
  ) {
    final items = _requiredList(value, 'templates.extract');
    return items.map((item) {
      final map = _asMap(item, 'templates.extract item');
      return BillingFieldExtractorRule(
        id: _optionalString(map['id'], 'id'),
        field: _requiredString(map, 'field'),
        type: _requiredString(map, 'type'),
        value: _optionalString(map['value'], 'value'),
        label: _optionalString(map['label'], 'label'),
        parser: _optionalString(map['parser'], 'parser'),
        pattern: _optionalString(map['pattern'], 'pattern'),
        confidence: _optionalDouble(map['confidence'], 0.8, 'confidence'),
        options: _optionsMap(map['options']),
      ).withResolvedId(templateId);
    }).toList(growable: false);
  }

  BillingRuleOrigin _parseOrigin(Object? value) {
    final name = _optionalString(value, 'origin') ?? 'public';
    return BillingRuleOrigin.values.firstWhere(
      (origin) => origin.name == name,
      orElse: () => throw BillingRuleRepositoryException(
        'Unknown rule origin: $name',
      ),
    );
  }

  BillingExtractorSelection _parseExtractorSelection(Object? value) {
    final name =
        _optionalString(value, 'extractorSelection') ?? 'firstSuccessful';
    return BillingExtractorSelection.values.firstWhere(
      (selection) => selection.name == name,
      orElse: () => throw BillingRuleRepositoryException(
        'Unknown extractor selection: $name',
      ),
    );
  }

  void _validateRuleSet(BillingRuleSet ruleSet) {
    if (ruleSet.schemaVersion != supportedSchemaVersion) {
      throw BillingRuleRepositoryException(
        'Unsupported schemaVersion: ${ruleSet.schemaVersion}',
      );
    }
    if (ruleSet.rulesVersion.trim().isEmpty) {
      throw const BillingRuleRepositoryException('rulesVersion is required');
    }
    if (!ruleSet.supportsNormalizationVersion(
      PaymentMethodSemantics.currentNormalizationVersion,
    )) {
      throw BillingRuleRepositoryException(
        'Rule package normalization version ${ruleSet.normalizationVersion} '
        'is incompatible with app normalization version '
        '${PaymentMethodSemantics.currentNormalizationVersion}',
      );
    }

    final templateIds = <String>{};
    for (final template in ruleSet.templates) {
      if (template.id.trim().isEmpty) {
        throw const BillingRuleRepositoryException('Template id is required');
      }
      if (!templateIds.add(template.id)) {
        throw BillingRuleRepositoryException(
          'Duplicate template id: ${template.id}',
        );
      }
      for (final extractor in template.extractors) {
        _validateExtractor(template.id, extractor);
      }
    }
  }

  List<int> _intList(Object? value, String field) {
    if (value == null) return const [];
    final values = _optionalList(value, field);
    if (values.any((item) => item is! int)) {
      throw BillingRuleRepositoryException('$field must contain integers');
    }
    return values.cast<int>();
  }

  void _validateExtractor(String templateId, BillingFieldExtractorRule rule) {
    if (!_isValidFieldPath(rule.field)) {
      throw BillingRuleRepositoryException(
        'Invalid field path in $templateId: ${rule.field}',
      );
    }
    if (!allowedExtractorTypes.contains(rule.type)) {
      throw BillingRuleRepositoryException(
        'Unknown extractor type in $templateId: ${rule.type}',
      );
    }
    final parser = rule.parser;
    if (parser != null && !allowedParsers.contains(parser)) {
      throw BillingRuleRepositoryException(
        'Unknown parser in $templateId: $parser',
      );
    }
    final pattern = rule.pattern;
    if (pattern != null) {
      try {
        RegExp(pattern);
      } on FormatException catch (error) {
        throw BillingRuleRepositoryException(
          'Invalid regex in $templateId for ${rule.field}',
          error,
        );
      }
    }
  }

  bool _isValidFieldPath(String field) {
    if (_allowedTopLevelFields.contains(field)) return true;
    final parts = field.split('.');
    if (parts.length != 2 || parts.first != 'details') return false;
    return RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(parts.last);
  }
}

Future<String?> _readExistingFile(File file) async {
  if (!file.existsSync()) return null;
  return file.readAsString();
}

Map<String, dynamic> _asMap(Object? value, String name) {
  if (value is Map) return value.cast<String, dynamic>();
  throw BillingRuleRepositoryException('$name must be a TOML table');
}

List<Object?> _requiredList(Object? value, String name) {
  if (value is List) return value.cast<Object?>();
  throw BillingRuleRepositoryException('$name must be an array');
}

List<Object?> _optionalList(Object? value, String name) {
  if (value == null) return const [];
  if (value is List) return value.cast<Object?>();
  throw BillingRuleRepositoryException('$name must be an array');
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw BillingRuleRepositoryException('$key must be an integer');
}

int _optionalInt(Object? value, int fallback, String key) {
  if (value == null) return fallback;
  if (value is int) return value;
  throw BillingRuleRepositoryException('$key must be an integer');
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw BillingRuleRepositoryException('$key must be a non-empty string');
}

String? _optionalString(Object? value, String key) {
  if (value == null) return null;
  if (value is String) return value;
  throw BillingRuleRepositoryException('$key must be a string');
}

bool _optionalBool(Object? value, bool fallback, String key) {
  if (value == null) return fallback;
  if (value is bool) return value;
  throw BillingRuleRepositoryException('$key must be a boolean');
}

double _optionalDouble(Object? value, double fallback, String key) {
  if (value == null) return fallback;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  throw BillingRuleRepositoryException('$key must be a number');
}

List<String> _stringList(Object? value, String key) {
  if (value == null) return const [];
  if (value is! List) {
    throw BillingRuleRepositoryException('$key must be an array of strings');
  }
  final strings = <String>[];
  for (final item in value) {
    if (item is! String) {
      throw BillingRuleRepositoryException('$key must be an array of strings');
    }
    strings.add(item);
  }
  return List.unmodifiable(strings);
}

Map<String, dynamic> _optionsMap(Object? value) {
  if (value == null) return const {};
  if (value is Map) return Map.unmodifiable(value.cast<String, dynamic>());
  throw const BillingRuleRepositoryException('options must be a TOML table');
}
