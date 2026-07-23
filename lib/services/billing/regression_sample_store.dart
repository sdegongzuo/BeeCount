import 'package:flutter/services.dart';

/// 个人规则回归样本的保留保护类型。
enum RegressionSampleProtection {
  /// 普通成功样本，可参与容量淘汰。
  none,

  /// 用户校正产生的受保护样本。
  correction,

  /// 防止错误命中的受保护负面样本。
  negative;

  /// 传递给 Android 存储层的稳定值。
  String get wireValue => name;
}

/// 等待加密保存的个人规则回归样本。
class RegressionSampleDraft {
  /// 完整规范化 OCR 文本。
  final String normalizedOcr;

  /// 用户确认后的期望账单字段。
  final Map<String, Object?> expectedFields;

  /// 回归所需的敏感提取证据。
  final Map<String, Object?> sensitiveEvidence;

  /// 用于计算结构指纹的稳定描述。
  final String structureDescriptor;

  /// 样本的保留保护类型。
  final RegressionSampleProtection protection;

  /// 创建一条等待加密保存的回归样本。
  const RegressionSampleDraft({
    required this.normalizedOcr,
    required this.expectedFields,
    required this.sensitiveEvidence,
    required this.structureDescriptor,
    this.protection = RegressionSampleProtection.none,
  });

  /// 转换为 Android 平台通道参数。
  Map<String, Object?> toChannelArguments() => {
        'normalizedOcr': normalizedOcr,
        'expectedFields': expectedFields,
        'sensitiveEvidence': sensitiveEvidence,
        'structureDescriptor': structureDescriptor,
        'protection': protection.wireValue,
      };
}

/// 保存个人规则回归样本的结果。
class SaveRegressionSampleResult {
  /// 是否插入了新样本；精确重复时为 false。
  final bool inserted;

  /// 新样本或既有重复样本的标识。
  final String? sampleId;

  /// 规范化内容的精确指纹。
  final String exactFingerprint;

  /// 等价行为覆盖的结构指纹。
  final String structureFingerprint;

  /// 创建保存结果。
  const SaveRegressionSampleResult({
    required this.inserted,
    required this.sampleId,
    required this.exactFingerprint,
    required this.structureFingerprint,
  });

  /// 从 Android 平台通道结果创建保存结果。
  factory SaveRegressionSampleResult.fromMap(Map<Object?, Object?> map) =>
      SaveRegressionSampleResult(
        inserted: map['inserted'] as bool,
        sampleId: map['sampleId'] as String?,
        exactFingerprint: map['exactFingerprint'] as String,
        structureFingerprint: map['structureFingerprint'] as String,
      );
}

enum RegressionExpectedRevisionState { prepared, active, compacted }

class RegressionExpectedRevision {
  final String revisionId;
  final String sampleId;
  final int normalizationVersion;
  final String? derivedFromRevisionId;
  final String migrationDecisionId;
  final RegressionExpectedRevisionState state;

  const RegressionExpectedRevision({
    required this.revisionId,
    required this.sampleId,
    required this.normalizationVersion,
    required this.migrationDecisionId,
    required this.state,
    this.derivedFromRevisionId,
  });

  factory RegressionExpectedRevision.fromMap(Map<Object?, Object?> map) =>
      RegressionExpectedRevision(
        revisionId: map['revisionId'] as String,
        sampleId: map['sampleId'] as String,
        normalizationVersion: map['normalizationVersion'] as int,
        migrationDecisionId: map['migrationDecisionId'] as String,
        derivedFromRevisionId: map['derivedFromRevisionId'] as String?,
        state: RegressionExpectedRevisionState.values
            .byName(map['state'] as String),
      );
}

class RegressionExpectedActivationResult {
  final int activeNormalizationVersion;
  final int? previousNormalizationVersion;
  final int activatedRevisionCount;

  const RegressionExpectedActivationResult({
    required this.activeNormalizationVersion,
    required this.previousNormalizationVersion,
    required this.activatedRevisionCount,
  });

  factory RegressionExpectedActivationResult.fromMap(
    Map<Object?, Object?> map,
  ) =>
      RegressionExpectedActivationResult(
        activeNormalizationVersion: map['activeNormalizationVersion'] as int,
        previousNormalizationVersion:
            map['previousNormalizationVersion'] as int?,
        activatedRevisionCount: map['activatedRevisionCount'] as int,
      );
}

class RegressionExpectedActivationState {
  final int? activeNormalizationVersion;
  final int? previousNormalizationVersion;
  final String? migrationDecisionId;

  const RegressionExpectedActivationState({
    required this.activeNormalizationVersion,
    required this.previousNormalizationVersion,
    required this.migrationDecisionId,
  });

  factory RegressionExpectedActivationState.fromMap(
    Map<Object?, Object?> map,
  ) =>
      RegressionExpectedActivationState(
        activeNormalizationVersion: map['activeNormalizationVersion'] as int?,
        previousNormalizationVersion:
            map['previousNormalizationVersion'] as int?,
        migrationDecisionId: map['migrationDecisionId'] as String?,
      );
}

/// 一批样本读取与解密的分阶段耗时。
class RegressionSampleTimings {
  /// 数据密钥解封耗时。
  final double keyUnwrapMs;

  /// SQLite 样本读取耗时。
  final double sampleReadMs;

  /// AES-GCM 解密耗时。
  final double decryptMs;

  /// 明文载荷解码耗时。
  final double decodeMs;

  /// 完整批次总耗时。
  final double totalMs;

  /// 创建分阶段耗时。
  const RegressionSampleTimings({
    required this.keyUnwrapMs,
    required this.sampleReadMs,
    required this.decryptMs,
    required this.decodeMs,
    required this.totalMs,
  });

  /// 从 Android 平台通道结果创建分阶段耗时。
  factory RegressionSampleTimings.fromMap(Map<Object?, Object?> map) =>
      RegressionSampleTimings(
        keyUnwrapMs: (map['keyUnwrapMs'] as num).toDouble(),
        sampleReadMs: (map['sampleReadMs'] as num).toDouble(),
        decryptMs: (map['decryptMs'] as num).toDouble(),
        decodeMs: (map['decodeMs'] as num).toDouble(),
        totalMs: (map['totalMs'] as num).toDouble(),
      );
}

/// 已成功解密的个人规则回归样本。
class DecryptedRegressionSample {
  /// 样本标识。
  final String id;

  /// 完整规范化 OCR 文本。
  final String normalizedOcr;

  /// 用户确认后的期望账单字段。
  final Map<Object?, Object?> expectedFields;

  /// 回归所需的敏感提取证据。
  final Map<Object?, Object?> sensitiveEvidence;

  /// 规范化内容的精确指纹。
  final String exactFingerprint;

  /// 等价行为覆盖的结构指纹。
  final String structureFingerprint;

  /// 样本的保留保护类型。
  final RegressionSampleProtection protection;

  /// 加密此样本时使用的数据密钥版本。
  final int keyVersion;

  /// 创建一条已成功解密的回归样本。
  const DecryptedRegressionSample({
    required this.id,
    required this.normalizedOcr,
    required this.expectedFields,
    required this.sensitiveEvidence,
    required this.exactFingerprint,
    required this.structureFingerprint,
    required this.protection,
    required this.keyVersion,
  });

  /// 从 Android 平台通道结果创建解密样本。
  factory DecryptedRegressionSample.fromMap(Map<Object?, Object?> map) =>
      DecryptedRegressionSample(
        id: map['id'] as String,
        normalizedOcr: map['normalizedOcr'] as String,
        expectedFields: map['expectedFields'] as Map<Object?, Object?>,
        sensitiveEvidence: map['sensitiveEvidence'] as Map<Object?, Object?>,
        exactFingerprint: map['exactFingerprint'] as String,
        structureFingerprint: map['structureFingerprint'] as String,
        protection: RegressionSampleProtection.values
            .byName(map['protection'] as String),
        keyVersion: map['keyVersion'] as int,
      );
}

/// 一次批量回归读取的结果。
class RegressionSampleBatch {
  /// 成功解密并可参与回归的样本。
  final List<DecryptedRegressionSample> samples;

  /// 已标记为无法解密、但没有被删除的样本标识。
  final List<String> unreadableSampleIds;

  /// 本批次的数据密钥解封次数。
  final int keyUnwrapCount;

  /// 本批次的分阶段性能记录。
  final RegressionSampleTimings timings;

  /// 创建批量回归读取结果。
  const RegressionSampleBatch({
    required this.samples,
    required this.unreadableSampleIds,
    required this.keyUnwrapCount,
    required this.timings,
  });

  /// 从 Android 平台通道结果创建批量读取结果。
  factory RegressionSampleBatch.fromMap(Map<Object?, Object?> map) =>
      RegressionSampleBatch(
        samples: (map['samples'] as List<Object?>)
            .cast<Map<Object?, Object?>>()
            .map(DecryptedRegressionSample.fromMap)
            .toList(growable: false),
        unreadableSampleIds:
            (map['unreadableSampleIds'] as List<Object?>).cast<String>(),
        keyUnwrapCount: map['keyUnwrapCount'] as int,
        timings: RegressionSampleTimings.fromMap(
          map['timings'] as Map<Object?, Object?>,
        ),
      );
}

/// 分页解密回归样本，避免一次在 Dart 堆中持有全部 OCR 明文。
class RegressionSamplePage {
  final List<DecryptedRegressionSample> samples;
  final List<String> unreadableSampleIds;
  final String? nextCursor;

  /// 创建一页解密样本；[nextCursor] 为空表示已到末页。
  const RegressionSamplePage({
    required this.samples,
    required this.unreadableSampleIds,
    required this.nextCursor,
  });

  /// 从 Android 平台通道结果创建一页样本。
  factory RegressionSamplePage.fromMap(Map<Object?, Object?> map) =>
      RegressionSamplePage(
        samples: (map['samples'] as List<Object?>)
            .cast<Map<Object?, Object?>>()
            .map(DecryptedRegressionSample.fromMap)
            .toList(growable: false),
        unreadableSampleIds:
            (map['unreadableSampleIds'] as List<Object?>).cast<String>(),
        nextCursor: map['nextCursor'] as String?,
      );
}

/// 运行时规则评测读取加密样本的分页边界。
abstract class RegressionSamplePageSource {
  /// 解密读取一页；调用方处理完后即可释放本页全部 OCR 明文。
  Future<RegressionSamplePage> readPage({
    required int limit,
    String? cursor,
  });
}

/// Android 本机加密个人规则回归样本存储入口。
abstract class RegressionExpectedRevisionStore {
  Future<RegressionExpectedRevision> prepareExpectedRevision({
    required String sampleId,
    required int normalizationVersion,
    required Map<String, Object?> expectedFields,
    required String migrationDecisionId,
    String? derivedFromRevisionId,
  });

  Future<RegressionExpectedActivationResult> activateExpectedRevisions({
    required int normalizationVersion,
    required String migrationDecisionId,
  });

  Future<RegressionExpectedActivationResult> rollbackExpectedRevisions();

  Future<RegressionExpectedActivationState> readExpectedActivationState();
}

class RegressionSampleStore
    implements RegressionSamplePageSource, RegressionExpectedRevisionStore {
  /// Flutter 与 Android 共用的平台通道名称。
  static const channelName = 'com.tntlikely.beecount/regression_samples';
  static const _channel = MethodChannel(channelName);

  /// 创建本机回归样本存储入口。
  const RegressionSampleStore();

  /// 加密保存样本，并对精确重复执行去重。
  Future<SaveRegressionSampleResult> save(RegressionSampleDraft draft) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'save',
      draft.toChannelArguments(),
    );
    return SaveRegressionSampleResult.fromMap(result!);
  }

  /// 批量读取并解密可用样本，同时返回不可读标记和性能数据。
  Future<RegressionSampleBatch> readBatch() async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('readBatch');
    return RegressionSampleBatch.fromMap(result!);
  }

  @override
  Future<RegressionExpectedRevision> prepareExpectedRevision({
    required String sampleId,
    required int normalizationVersion,
    required Map<String, Object?> expectedFields,
    required String migrationDecisionId,
    String? derivedFromRevisionId,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'prepareExpectedRevision',
      {
        'sampleId': sampleId,
        'normalizationVersion': normalizationVersion,
        'expectedFields': expectedFields,
        'migrationDecisionId': migrationDecisionId,
        if (derivedFromRevisionId != null)
          'derivedFromRevisionId': derivedFromRevisionId,
      },
    );
    return RegressionExpectedRevision.fromMap(result!);
  }

  @override
  Future<RegressionExpectedActivationResult> activateExpectedRevisions({
    required int normalizationVersion,
    required String migrationDecisionId,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'activateExpectedRevisions',
      {
        'normalizationVersion': normalizationVersion,
        'migrationDecisionId': migrationDecisionId,
      },
    );
    return RegressionExpectedActivationResult.fromMap(result!);
  }

  @override
  Future<RegressionExpectedActivationResult> rollbackExpectedRevisions() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'rollbackExpectedRevisions',
    );
    return RegressionExpectedActivationResult.fromMap(result!);
  }

  @override
  Future<RegressionExpectedActivationState>
      readExpectedActivationState() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'readExpectedActivationState',
    );
    return RegressionExpectedActivationState.fromMap(result!);
  }

  @override
  Future<RegressionSamplePage> readPage({
    required int limit,
    String? cursor,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'readPage',
      {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return RegressionSamplePage.fromMap(result!);
  }
}
