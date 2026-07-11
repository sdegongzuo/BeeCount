import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_bill_service.dart';
import '../ai/ai_constants.dart';
import '../ai/bill_extraction_service.dart';
import '../../data/repositories/base_repository.dart';
import '../platform/screenshot_source_info.dart';
import '../system/logger_service.dart';
import 'bill_recognition_normalizer.dart';
import 'details_text_helper.dart';
import 'fast_billing_rule_service.dart';
import 'ocr_image_preprocessor.dart';
import 'rules/billing_rule_engine_impl.dart';
import 'rules/billing_rule_models.dart';
import 'rules/billing_rule_repository.dart';
import 'rules/billing_rule_trace.dart';
import 'payment_channel_detector.dart';
import 'ocr_text_quality.dart';

/// OCR识别结果
class OcrResult {
  final double? amount;
  final String? note;
  final DateTime? time;
  final String rawText;
  final List<String> allNumbers;
  final int? suggestedCategoryId; // 推荐的分类ID
  final String? aiCategoryName; // AI识别的分类名称
  final String? aiType; // AI识别的类型 (income/expense/transfer)
  final String? aiAccountName; // AI识别的账户名称
  final String? paymentMethod; // 支付方式/付款方式
  final String? paymentChannel; // 支付通道/账单来源
  final String? counterparty; // 交易对方/收付款方
  final String? merchantFullName; // 商户全称
  final String? acquirer; // 收单机构/清算机构
  final Map<String, dynamic>? details; // 补充明细
  final String? detailsText; // 补充明细化文本（优先使用）
  final PaymentChannelDetection? detectedPaymentChannel; // 规则检测出的支付通道
  final OcrPreprocessResult? preprocessResult; // OCR 前预处理结果
  final BillingRuleResult? billingRuleResult; // 快速记账规则结果
  final BillingRuleTrace? billingRuleTrace; // 快速记账规则 trace
  final bool fastBillingAccepted; // 是否满足快速记账条件
  final List<String> fastBillingRejectReasons; // 快速记账拒绝原因
  final String? ocrEngine; // OCR 引擎 rapidocr / mlkit / manual
  final String? aiProvider; // AI提供商（用于日志）
  final bool aiEnhanced; // 是否经过AI增强

  OcrResult({
    this.amount,
    this.note,
    this.time,
    required this.rawText,
    required this.allNumbers,
    this.suggestedCategoryId,
    this.aiCategoryName,
    this.aiType,
    this.aiAccountName,
    this.paymentMethod,
    this.paymentChannel,
    this.counterparty,
    this.merchantFullName,
    this.acquirer,
    this.details,
    this.detailsText,
    this.detectedPaymentChannel,
    this.preprocessResult,
    this.billingRuleResult,
    this.billingRuleTrace,
    this.fastBillingAccepted = false,
    this.fastBillingRejectReasons = const [],
    this.ocrEngine,
    this.aiProvider,
    this.aiEnhanced = false,
  });

  /// 创建副本并合并AI结果
  OcrResult copyWithAI({
    double? amount,
    String? note,
    DateTime? time,
    int? suggestedCategoryId,
    String? aiCategoryName,
    String? aiType,
    String? aiAccountName,
    String? paymentMethod,
    String? paymentChannel,
    String? counterparty,
    String? merchantFullName,
    String? acquirer,
    Map<String, dynamic>? details,
    String? detailsText,
    PaymentChannelDetection? detectedPaymentChannel,
    String? aiProvider,
  }) {
    return OcrResult(
      amount: amount ?? this.amount,
      note: note ?? this.note,
      time: time ?? this.time,
      rawText: rawText,
      allNumbers: allNumbers,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      aiCategoryName: aiCategoryName ?? this.aiCategoryName,
      aiType: aiType ?? this.aiType,
      aiAccountName: aiAccountName ?? this.aiAccountName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      counterparty: counterparty ?? this.counterparty,
      merchantFullName: merchantFullName ?? this.merchantFullName,
      acquirer: acquirer ?? this.acquirer,
      details: details ?? this.details,
      detailsText: detailsText ?? this.detailsText,
      detectedPaymentChannel:
          detectedPaymentChannel ?? this.detectedPaymentChannel,
      preprocessResult: preprocessResult,
      billingRuleResult: billingRuleResult,
      billingRuleTrace: billingRuleTrace,
      fastBillingAccepted: fastBillingAccepted,
      fastBillingRejectReasons: fastBillingRejectReasons,
      ocrEngine: ocrEngine,
      aiProvider: aiProvider,
      aiEnhanced: true,
    );
  }

  OcrResult copyWithFastBillingRule({
    double? amount,
    String? note,
    DateTime? time,
    String? paymentMethod,
    String? paymentChannel,
    String? counterparty,
    String? merchantFullName,
    String? acquirer,
    Map<String, dynamic>? details,
    String? detailsText,
    OcrPreprocessResult? preprocessResult,
    BillingRuleResult? billingRuleResult,
    BillingRuleTrace? billingRuleTrace,
    bool? fastBillingAccepted,
    List<String>? fastBillingRejectReasons,
  }) {
    return OcrResult(
      amount: amount ?? this.amount,
      note: note ?? this.note,
      time: time ?? this.time,
      rawText: rawText,
      allNumbers: allNumbers,
      suggestedCategoryId: suggestedCategoryId,
      aiCategoryName: aiCategoryName,
      aiType: aiType,
      aiAccountName: aiAccountName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      counterparty: counterparty ?? this.counterparty,
      merchantFullName: merchantFullName ?? this.merchantFullName,
      acquirer: acquirer ?? this.acquirer,
      details: details ?? this.details,
      detailsText: detailsText ?? this.detailsText,
      detectedPaymentChannel: detectedPaymentChannel,
      preprocessResult: preprocessResult ?? this.preprocessResult,
      billingRuleResult: billingRuleResult ?? this.billingRuleResult,
      billingRuleTrace: billingRuleTrace ?? this.billingRuleTrace,
      fastBillingAccepted: fastBillingAccepted ?? this.fastBillingAccepted,
      fastBillingRejectReasons:
          fastBillingRejectReasons ?? this.fastBillingRejectReasons,
      ocrEngine: ocrEngine,
      aiProvider: aiProvider,
      aiEnhanced: aiEnhanced,
    );
  }

  /// 从 JSON 反序列化（仅恢复 createBillTransaction 所需的字段）。
  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      amount: (json['amount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      time: json['time'] != null
          ? DateTime.tryParse(json['time'] as String)
          : null,
      rawText: json['rawText'] as String? ?? '',
      allNumbers: (json['allNumbers'] as List<dynamic>?)?.cast<String>() ?? [],
      suggestedCategoryId: json['suggestedCategoryId'] as int?,
      aiCategoryName: json['aiCategoryName'] as String?,
      aiType: json['aiType'] as String?,
      aiAccountName: json['aiAccountName'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentChannel: json['payment_channel'] as String?,
      counterparty: json['counterparty'] as String?,
      merchantFullName: json['merchant_full_name'] as String?,
      acquirer: json['acquirer'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      detailsText: json['details_text'] as String?,
      fastBillingAccepted: json['fast_billing_accepted'] as bool? ?? false,
      fastBillingRejectReasons:
          (json['fast_billing_reject_reasons'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
      ocrEngine: json['ocr_engine'] as String?,
      aiProvider: json['aiProvider'] as String?,
      aiEnhanced: json['aiEnhanced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'note': note,
        'time': time?.toIso8601String(),
        'rawText': rawText,
        'allNumbers': allNumbers,
        'suggestedCategoryId': suggestedCategoryId,
        'aiCategoryName': aiCategoryName,
        'aiType': aiType,
        'aiAccountName': aiAccountName,
        'payment_method': paymentMethod,
        'payment_channel': paymentChannel,
        'counterparty': counterparty,
        'merchant_full_name': merchantFullName,
        'acquirer': acquirer,
        'details': details,
        'details_text': detailsText,
        'detected_payment_channel': detectedPaymentChannel?.toJson(),
        'preprocess': preprocessResult?.toJson(),
        'billing_rule_result': billingRuleResult?.toJson(),
        'billing_rule_trace': billingRuleTrace?.toDebugJson(),
        'fast_billing_accepted': fastBillingAccepted,
        'fast_billing_reject_reasons': fastBillingRejectReasons,
        'ocr_engine': ocrEngine,
        'aiProvider': aiProvider,
        'aiEnhanced': aiEnhanced,
      };
}

/// OCR服务 - 识别支付截图中的金额等信息
class OcrService {
  static const MethodChannel _rapidOcrChannel =
      MethodChannel('com.tntlikely.beecount/rapid_ocr');

  // 使用中文识别 - 可以识别中文、数字、符号
  // 需要在 android/app/build.gradle 中添加依赖:
  // implementation 'com.google.mlkit:text-recognition-chinese:16.0.0'
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
  );
  final PaymentChannelResolver _paymentChannelResolver =
      const PaymentChannelResolver();
  final OcrImagePreprocessor _imagePreprocessor;
  final FastBillingRuleService _fastBillingRuleService;

  OcrService({
    OcrImagePreprocessor? imagePreprocessor,
    FastBillingRuleService? fastBillingRuleService,
  })  : _imagePreprocessor = imagePreprocessor ?? const OcrImagePreprocessor(),
        _fastBillingRuleService = fastBillingRuleService ??
            FastBillingRuleService(
              ruleRepository: TomlBillingRuleRepository(),
              ruleEngine: BillingRuleEngineImpl(),
            );

  /// 识别图片中的文本并提取支付信息
  ///
  /// [imageFile] 图片文件
  /// [repo] Repository实例（可选，用于获取账户列表）
  static const _tag = 'OCR';

  Future<OcrResult> recognizePaymentImage(
    File imageFile, {
    BaseRepository? repo,
    BillExtractionTraceSink? traceSink,
    ScreenshotSourceInfo? sourceInfo,
    bool enableAiEnhancement = true,
  }) async {
    final startTime = DateTime.now();
    logger.info(_tag, '========== OCR识别开始 ==========');

    try {
      // 1. OCR前预处理
      final preprocessStartTime = DateTime.now();
      OcrPreprocessResult? preprocessResult;
      File ocrImageFile = imageFile;
      try {
        preprocessResult = await _imagePreprocessor.preprocess(imageFile);
        final outputPath = preprocessResult.outputPath;
        if (outputPath != null && outputPath.isNotEmpty) {
          ocrImageFile = File(outputPath);
        }
        final preprocessDuration =
            DateTime.now().difference(preprocessStartTime);
        traceSink?.call(BillExtractionTraceEvent(
          stage: 'preprocess',
          data: {
            ...preprocessResult.toJson(),
            'durationMs': preprocessDuration.inMilliseconds,
          },
        ));
        logger.info(
          _tag,
          '[OCR预处理] ${preprocessDuration.inMilliseconds}ms | '
          'method=${preprocessResult.method} | output=${preprocessResult.outputPath}',
        );
      } catch (e, stackTrace) {
        logger.error(_tag, '[OCR预处理] 失败，回退原图', e, stackTrace);
        traceSink?.call(BillExtractionTraceEvent(
          stage: 'preprocess',
          data: {
            'method': 'error_fallback_original',
            'original_path': imageFile.path,
            'error': e.toString(),
          },
        ));
      }

      // 2. OCR文本识别
      logger.debug(_tag, '开始文本识别...');
      final ocrStartTime = DateTime.now();

      final textResult = await _recognizeImageText(ocrImageFile);
      final rawText = textResult.rawText;
      final ocrDuration = DateTime.now().difference(ocrStartTime);
      logger.info(
          _tag, '[文本识别:${textResult.engine}] ${ocrDuration.inMilliseconds}ms');
      logger.debug(_tag, '识别文本: $rawText');
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'ocr',
        data: {
          'rawText': rawText,
          'durationMs': ocrDuration.inMilliseconds,
          'engine': textResult.engine,
        },
      ));

      // 3. 旧规则提取
      final ruleStartTime = DateTime.now();
      final allNumbers = _extractAllNumbers(rawText);
      final amount = _extractAmount(rawText);
      final note = _extractNote(rawText);
      final time = _extractTime(rawText);
      final paymentChannelDetection = await _paymentChannelResolver.resolve(
        rawText,
        imageFile: imageFile,
      );
      final sourcePaymentChannel = _sourcePaymentChannel(sourceInfo);
      final finalPaymentChannel =
          paymentChannelDetection?.channel ?? sourcePaymentChannel;
      final sourceDetails = _sourceDetails(
        sourceInfo,
        ocrPaymentChannel: paymentChannelDetection?.channel,
      );
      final ruleDuration = DateTime.now().difference(ruleStartTime);

      logger.info(_tag,
          '[规则提取] ${ruleDuration.inMilliseconds}ms | 金额:${amount ?? "无"} 备注:${note ?? "无"} 时间:${time ?? "无"} 支付通道:${finalPaymentChannel ?? "无"} 来源通道:${sourcePaymentChannel ?? "无"} 规则通道:${paymentChannelDetection?.channel ?? "无"} 候选:$allNumbers');

      final baseResult = OcrResult(
        amount: amount,
        note: note,
        time: time,
        rawText: rawText,
        allNumbers: allNumbers,
        paymentChannel: finalPaymentChannel,
        details: sourceDetails.isEmpty ? null : sourceDetails,
        detectedPaymentChannel: paymentChannelDetection,
        ocrEngine: textResult.engine,
      );
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'rule',
        data: baseResult.toJson(),
      ));

      // 4. 快速记账规则引擎
      final fastEvaluation = await _fastBillingRuleService.evaluate(
        baseResult: baseResult,
        sourceInfo: sourceInfo,
        preprocessResult: preprocessResult,
        traceSink: traceSink,
      );
      final fastResult = fastEvaluation.result;
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'fast_billing_decision',
        data: {
          'accepted': fastEvaluation.accepted,
          'reject_reasons': fastEvaluation.rejectReasons,
          'result': fastResult.toJson(),
        },
      ));
      logger.info(
        _tag,
        '[快速规则] accepted=${fastEvaluation.accepted} | '
        'reasons=${fastEvaluation.rejectReasons.join(",")} | '
        'amount=${fastResult.amount ?? "无"} | '
        'time=${fastResult.time ?? "无"} | '
        'channel=${fastResult.paymentChannel ?? "无"}',
      );

      // 5. AI增强（如果启用）
      final enhancedResult = enableAiEnhancement
          ? await _enhanceWithAI(
              fastResult,
              repo: repo,
              imageFile: imageFile,
              sourceInfo: sourceInfo,
              traceSink: traceSink,
            )
          : fastResult;
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'final',
        data: enhancedResult.toJson(),
      ));

      final totalDuration = DateTime.now().difference(startTime);
      logger.info(
        _tag,
        '[总计] 识别完成 ${totalDuration.inMilliseconds}ms | '
        '最终支付通道:${enhancedResult.paymentChannel ?? "无"} | '
        '来源:${sourceInfo?.toJson() ?? "无"} | '
        'details:${enhancedResult.details ?? "无"}',
      );

      return enhancedResult;
    } catch (e) {
      logger.error(_tag, '识别失败', e);
      rethrow;
    }
  }

  Future<_OcrTextResult> _recognizeImageText(File imageFile) async {
    if (Platform.isAndroid) {
      try {
        final rapidResult =
            await _rapidOcrChannel.invokeMapMethod<String, dynamic>(
          'recognizeImage',
          {
            'path': imageFile.path,
            'maxSideLen': 1920,
          },
        );
        final rawText = rapidResult?['rawText']?.toString().trim() ?? '';
        if (isUsableRapidOcrText(rawText)) {
          return _OcrTextResult(rawText: rawText, engine: 'rapidocr');
        }
        logger.warning(
          _tag,
          rawText.isEmpty
              ? 'RapidOCR返回空文本，回退到ML Kit'
              : 'RapidOCR返回不可用文本，回退到ML Kit',
        );
      } catch (e) {
        logger.warning(_tag, 'RapidOCR失败，回退到ML Kit: $e');
      }
    }

    final recognizedText = await _recognizeWithMlKit(imageFile);
    return _OcrTextResult(rawText: recognizedText.text, engine: 'mlkit');
  }

  Future<RecognizedText> _recognizeWithMlKit(File imageFile) async {
    try {
      // 方式1: 直接从文件路径读取(适用于大多数设备)
      logger.debug(_tag, 'ML Kit方式1: 从文件路径读取');
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      logger.debug(_tag, 'ML Kit方式1成功');
      return recognizedText;
    } catch (e) {
      logger.warning(_tag, 'ML Kit方式1失败: $e');
      logger.debug(_tag, 'ML Kit方式2: 从临时文件读取(解决华为权限问题)');

      // 方式2: 先复制文件到App私有目录,再读取
      // 华为系统对Screenshots目录有特殊权限保护
      final appDir = await getTemporaryDirectory();
      final tempFile = File(
          '${appDir.path}/temp_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await imageFile.copy(tempFile.path);
      logger.debug(_tag, '文件已复制到: ${tempFile.path}');

      try {
        final inputImage = InputImage.fromFile(tempFile);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        logger.debug(_tag, 'ML Kit方式2成功');
        return recognizedText;
      } finally {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// AI增强识别结果
  ///
  /// [baseResult] 基础OCR识别结果
  /// [repo] Repository实例（可选，用于获取账户列表）
  /// [imageFile] 图片文件（用于Vision模型）
  Future<OcrResult> _enhanceWithAI(
    OcrResult baseResult, {
    BaseRepository? repo,
    File? imageFile,
    ScreenshotSourceInfo? sourceInfo,
    BillExtractionTraceSink? traceSink,
  }) async {
    try {
      // 检查是否启用AI
      final prefs = await SharedPreferences.getInstance();
      final aiEnabled =
          prefs.getBool(AIConstants.keyAiBillExtractionEnabled) ?? false;

      if (!aiEnabled) {
        return baseResult;
      }

      logger.debug(_tag, '[AI增强] 开始...');
      final aiStartTime = DateTime.now();

      // 获取用户分类列表(从数据库读取，仅获取可用于记账的叶子分类)
      List<String> expenseCategories = [];
      List<String> incomeCategories = [];
      if (repo != null) {
        try {
          // 使用 getUsableCategories 获取可用分类（排除有子分类的父分类）
          final expenseCats = await repo.getUsableCategories('expense');
          final incomeCats = await repo.getUsableCategories('income');
          expenseCategories = expenseCats.map((c) => c.name).toList();
          incomeCategories = incomeCats.map((c) => c.name).toList();
          logger.debug(_tag,
              '[分类列表] 支出${expenseCategories.length}个 收入${incomeCategories.length}个');
        } catch (e) {
          logger.warning(_tag, '[分类列表] 获取失败: $e');
        }
      }

      // 获取用户账户列表（如果账户功能已启用且提供了Repository实例）
      List<String>? accounts;
      final accountFeatureEnabled =
          prefs.getBool('account_feature_enabled') ?? true; // 默认启用
      if (accountFeatureEnabled && repo != null) {
        try {
          final allAccounts = await repo.getAllAccounts();
          accounts = allAccounts.map((a) => a.name).toList();
          logger.debug(
              _tag, '[账户列表] ${accounts.length}个: ${accounts.join('、')}');
        } catch (e) {
          logger.warning(_tag, '[账户列表] 获取失败: $e');
          accounts = null;
        }
      }

      // 初始化AI服务
      final aiService = AIBillService();
      await aiService.initialize(
        expenseCategories: expenseCategories,
        incomeCategories: incomeCategories,
        accounts: accounts,
        imageFile: imageFile,
        traceSink: traceSink,
      );

      final billInfo = await aiService.extractBillInfo(
        baseResult.rawText,
        expenseCategories: expenseCategories,
        incomeCategories: incomeCategories,
        accounts: accounts,
        imageFile: imageFile,
        traceSink: traceSink,
      );
      final aiDuration = DateTime.now().difference(aiStartTime);

      if (billInfo != null) {
        // 智能合并策略：AI优先，规则兜底
        final mergedAmount = billInfo.amount ?? baseResult.amount;
        final mergedNote = billInfo.note ?? baseResult.note;
        final mergedAccount = billInfo.account;
        final mergedPaymentMethod =
            billInfo.paymentMethod ?? baseResult.paymentMethod;
        final detectedPaymentChannel = sourceInfo?.hasPaymentChannel == true
            ? null
            : baseResult.detectedPaymentChannel?.isHighConfidence == true
                ? baseResult.detectedPaymentChannel?.channel
                : null;
        final sourcePaymentChannel = _sourcePaymentChannel(sourceInfo);
        final mergedPaymentChannel = sourcePaymentChannel ??
            billInfo.paymentChannel ??
            baseResult.paymentChannel;
        final mergedCounterparty =
            billInfo.counterparty ?? baseResult.counterparty;
        final mergedMerchantFullName =
            billInfo.merchantFullName ?? baseResult.merchantFullName;
        final mergedAcquirer = billInfo.acquirer ?? baseResult.acquirer;
        final mergedDetails =
            _mergeDetails(baseResult.details, billInfo.details);
        // detailsText: 优先使用 detailsMapToText(billInfo.details)，已有文本可保留
        final mergedDetailsText = billInfo.details != null
            ? detailsMapToText(billInfo.details)
            : (baseResult.detailsText);

        final mergedTime = billInfo.time ?? baseResult.time;
        final normalized = const BillRecognitionNormalizer().normalize(
          BillRecognitionFields(
            note: mergedNote,
            category: billInfo.category,
            paymentMethod: mergedPaymentMethod,
            paymentChannel: mergedPaymentChannel,
            counterparty: mergedCounterparty,
            merchantFullName: mergedMerchantFullName,
            details: mergedDetails,
          ),
          detectedPaymentChannel: detectedPaymentChannel,
        );

        final typeText = billInfo.type?.toString().split('.').last ?? '未知';
        final timeStr = mergedTime?.toString().substring(0, 16) ?? '无';
        logger.info(_tag,
            '[AI增强] ${aiDuration.inMilliseconds}ms | $typeText 金额:$mergedAmount 备注:${normalized.note ?? "无"} 分类:${normalized.category ?? "无"} 账户:${mergedAccount ?? "无"} 支付方式:${normalized.paymentMethod ?? "无"} 交易对方:${normalized.counterparty ?? "无"} 时间:$timeStr');

        return baseResult.copyWithAI(
          amount: mergedAmount,
          note: normalized.note,
          time: mergedTime,
          aiCategoryName: normalized.category,
          aiType: typeText,
          aiAccountName: mergedAccount,
          paymentMethod: normalized.paymentMethod,
          paymentChannel: normalized.paymentChannel,
          counterparty: normalized.counterparty,
          merchantFullName: normalized.merchantFullName,
          acquirer: mergedAcquirer,
          details: normalized.details,
          detailsText: mergedDetailsText,
          aiProvider: 'AI',
        );
      } else {
        logger.warning(_tag, '[AI增强] 失败或超时，使用规则识别结果');
        return baseResult;
      }
    } catch (e) {
      logger.error(_tag, '[AI增强] 失败', e);
      return baseResult;
    }
  }

  String? _sourcePaymentChannel(ScreenshotSourceInfo? sourceInfo) {
    final channel = sourceInfo?.paymentChannel?.trim();
    return channel == null || channel.isEmpty ? null : channel;
  }

  Map<String, dynamic> _sourceDetails(
    ScreenshotSourceInfo? sourceInfo, {
    String? ocrPaymentChannel,
  }) {
    if (sourceInfo == null) return const {};
    return {
      'screenshot_source_app': sourceInfo.appName,
      'screenshot_source_package': sourceInfo.packageName,
      'screenshot_source_payment_channel': sourceInfo.paymentChannel,
      'screenshot_source_confidence': sourceInfo.confidence,
      'screenshot_source_method': sourceInfo.method,
      'ocr_payment_channel': ocrPaymentChannel,
    };
  }

  Map<String, dynamic>? _mergeDetails(
    Map<String, dynamic>? base,
    Map<String, dynamic>? override,
  ) {
    final result = <String, dynamic>{
      if (base != null) ...base,
      if (override != null) ...override,
    };
    return result.isEmpty ? null : result;
  }

  /// 直接解析文本并提取支付信息(无需OCR)
  /// 用于快捷指令传递的已识别文本
  OcrResult parsePaymentText(String rawText) {
    // 提取所有可能的金额数字
    final allNumbers = _extractAllNumbers(rawText);

    // 提取金额
    final amount = _extractAmount(rawText);

    // 提取备注
    final note = _extractNote(rawText);

    // 提取时间
    final time = _extractTime(rawText);

    return OcrResult(
      amount: amount,
      note: note,
      time: time,
      rawText: rawText,
      allNumbers: allNumbers,
    );
  }

  /// 提取所有可能的数字（供用户选择）
  List<String> _extractAllNumbers(String text) {
    final numbers = <String>[];

    // 匹配各种金额格式
    final patterns = [
      RegExp(r'¥\s*(\d+\.?\d*)'), // ¥123.45
      RegExp(r'￥\s*(\d+\.?\d*)'), // ￥123.45
      RegExp(r'(\d+\.\d{2})\s*元'), // 123.45元
      RegExp(r'(\d+\.\d{2})'), // 纯数字带小数点
      RegExp(r'(\d{1,6})\s*\.\s*(\d{2})'), // 123 . 45 (可能有空格)
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        if (match.groupCount > 0) {
          final numStr = match.group(1);
          if (numStr != null && numStr.isNotEmpty) {
            final num = double.tryParse(numStr);
            if (num != null && num > 0 && num < 1000000) {
              numbers.add(numStr);
            }
          }
        }
      }
    }

    // 去重并排序
    final uniqueNumbers = numbers.toSet().toList();
    uniqueNumbers.sort((a, b) {
      final numA = double.parse(a);
      final numB = double.parse(b);
      return numB.compareTo(numA); // 从大到小排序
    });

    return uniqueNumbers;
  }

  /// 提取金额 - 优先识别支付宝/微信支付的特征
  double? _extractAmount(String text) {
    // 移除所有空格和换行，方便匹配
    final cleanText = text.replaceAll(RegExp(r'\s+'), '');

    // 优先识别带加号的金额（明确表示收入）: +9.04
    final plusPattern = RegExp(r'\+(\d+\.?\d*)');
    final plusMatch = plusPattern.firstMatch(cleanText);
    if (plusMatch != null && plusMatch.groupCount > 0) {
      final amountStr = plusMatch.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          // 返回正数，但会在类型判断中识别加号
          return amount;
        }
      }
    }

    // 优先匹配顶部/主金额里的纯负数，避免后续优惠券 ¥0.30 抢先命中。
    final plainNegativeAmount = _largestPlainNegativeAmount(cleanText);
    if (plainNegativeAmount != null) {
      return plainNegativeAmount;
    }

    // 云闪付等页面可能显示为 -¥23.60，OCR 有时把负号识别成中文“一”。
    final negativeCurrencyPattern = RegExp(r'[-−一]\s*[¥￥]\s*(\d+\.?\d*)');
    final negativeCurrencyMatches =
        negativeCurrencyPattern.allMatches(cleanText);
    for (final match in negativeCurrencyMatches) {
      final amountStr = match.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          final priorText = cleanText.substring(0, match.start);
          final nearbyStart = match.start > 12 ? match.start - 12 : 0;
          final nearbyText = cleanText.substring(nearbyStart, match.start);
          final hasEarlierCurrency =
              RegExp(r'[¥￥]\s*\d+\.?\d*').hasMatch(priorText);
          final looksLikeDiscount = RegExp(r'优惠|立减|券|减').hasMatch(nearbyText);
          if (hasEarlierCurrency && looksLikeDiscount) {
            continue;
          }
          return -amount;
        }
      }
    }

    // 支付宝特征：付款 ¥123.45 或 实付 ¥123.45
    final alipayPatterns = [
      RegExp(r'[付实付收款]款?[¥￥]\s*(\d+\.?\d*)'),
      RegExp(r'[¥￥]\s*(\d+\.\d{2})', caseSensitive: false),
    ];

    for (final pattern in alipayPatterns) {
      final match = pattern.firstMatch(cleanText);
      if (match != null && match.groupCount > 0) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) {
            return _withPaymentSign(amount, cleanText);
          }
        }
      }
    }

    // 微信支付特征：¥123.45 通常在顶部较大字体
    final wechatPattern = RegExp(r'[¥￥](\d+\.\d{2})');
    final matches = wechatPattern.allMatches(cleanText);

    // 取第一个匹配（通常是金额）
    if (matches.isNotEmpty) {
      final match = matches.first;
      final amountStr = match.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return _withPaymentSign(amount, cleanText);
        }
      }
    }

    // 通用金额匹配：xx.xx元
    final generalPattern = RegExp(r'(\d+\.\d{2})元');
    final generalMatch = generalPattern.firstMatch(cleanText);
    if (generalMatch != null) {
      final amountStr = generalMatch.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        return amount == null ? null : _withPaymentSign(amount, cleanText);
      }
    }

    // 如果前面都没匹配到,尝试匹配负号金额: -14.00 或 -14.93
    // 只匹配带小数点的金额，避免误匹配时间等
    final fallbackNegativeAmount = _largestPlainNegativeAmount(cleanText);
    if (fallbackNegativeAmount != null) {
      return fallbackNegativeAmount;
    }

    // 最后尝试: 如果 allNumbers 中有有效金额,使用第一个
    final allNumbers = _extractAllNumbers(text);
    if (allNumbers.isNotEmpty) {
      final amount = double.tryParse(allNumbers.first);
      return amount == null ? null : _withPaymentSign(amount, cleanText);
    }

    return null;
  }

  double? _largestPlainNegativeAmount(String cleanText) {
    final negativePattern = RegExp(r'[-−](\d+\.\d{2})');
    final negativeMatches = negativePattern.allMatches(cleanText);
    if (negativeMatches.isEmpty) return null;

    // 过滤小额优惠/红包，优先选择最大的负数金额。
    double? maxAmount;
    for (final match in negativeMatches) {
      final amountStr = match.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null &&
            amount >= 1.0 &&
            amount < 100000 &&
            (maxAmount == null || amount > maxAmount)) {
          maxAmount = amount;
        }
      }
    }
    return maxAmount == null ? null : -maxAmount;
  }

  double _withPaymentSign(double amount, String cleanText) {
    if (amount <= 0) return amount;
    if (RegExp(r'收款|收入|退款|到账|已退').hasMatch(cleanText)) {
      return amount;
    }
    if (RegExp(r'支付成功|支付咸功|支付成咸功|交易成功|交易成戌功|付款成功|自动扣款成功|消费|付款方式|支付方式')
        .hasMatch(cleanText)) {
      return -amount;
    }
    return amount;
  }

  /// 提取备注信息
  String? _extractNote(String text) {
    // 提取可作为备注的信息（商家、收款方等）
    final patterns = [
      // 收款方全称后面可能换行，匹配下一行的公司名
      RegExp(r'收款方全称[:：]\s*\n?\s*([^\n]{3,30})'),
      RegExp(r'收款方全称[:：]\s*([^\n]{3,30})'),
      RegExp(r'收款方[:：]\s*\n?\s*([^\n]{3,30})'),
      RegExp(r'收款方[:：]\s*([^\n]{3,30})'),
      RegExp(r'商家[:：]\s*([^\n]{3,30})'),
      RegExp(r'店铺[:：]\s*([^\n]{3,30})'),
      // 匹配公司名称特征（包含"公司"、"店"等）
      RegExp(r'([^\n]{2,20}(?:有限公司|责任公司|股份公司|公司|店|商行))'),
      // 微信支付特征：向xxx付款
      RegExp(r'向\s*([^\n付款]{2,20})\s*付款'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount > 0) {
        var note = match.group(1)?.trim();
        if (note != null && note.isNotEmpty) {
          // 过滤掉一些无用信息
          note = note.split(RegExp(r'[,，。\.]')).first.trim();
          // 过滤掉数字、日期等
          if (note.length >= 3 &&
              !RegExp(r'^\d+$').hasMatch(note) &&
              !RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(note)) {
            return note;
          }
        }
      }
    }

    return null;
  }

  /// 提取支付时间
  DateTime? _extractTime(String text) {
    // 时间格式：支持多种格式
    final patterns = [
      // 2025-11-06 14:30:25
      RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      // 2025-11-06 14:30
      RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})'),
      // 2025年11 月06日 14:30:25，OCR 可能在年月日前后插入空格
      RegExp(
          r'(\d{4})年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s+(\d{1,2}):(\d{2}):(\d{2})'),
      // 2025年11月06日 14:30:25
      RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日\s+(\d{2}):(\d{2}):(\d{2})'),
      // 2025年8月30日 16:06:30
      RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日\s+(\d{1,2}):(\d{2}):(\d{2})'),
      // 2025年11月06日 14:30
      RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日\s+(\d{2}):(\d{2})'),
      // MM-DD HH:mm
      RegExp(r'(\d{2})-(\d{2})\s+(\d{2}):(\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          if (match.groupCount == 6) {
            // 完整日期时间带秒
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            final hour = int.parse(match.group(4)!);
            final minute = int.parse(match.group(5)!);
            final second = int.parse(match.group(6)!);
            return DateTime(year, month, day, hour, minute, second);
          } else if (match.groupCount == 5) {
            // 完整日期时间不带秒
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            final hour = int.parse(match.group(4)!);
            final minute = int.parse(match.group(5)!);
            return DateTime(year, month, day, hour, minute);
          } else if (match.groupCount == 4) {
            // MM-DD格式，使用当前年份
            final now = DateTime.now();
            final month = int.parse(match.group(1)!);
            final day = int.parse(match.group(2)!);
            final hour = int.parse(match.group(3)!);
            final minute = int.parse(match.group(4)!);
            return DateTime(now.year, month, day, hour, minute);
          }
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  /// 释放资源
  void dispose() {
    _textRecognizer.close();
  }
}

class _OcrTextResult {
  final String rawText;
  final String engine;

  const _OcrTextResult({
    required this.rawText,
    required this.engine,
  });
}
