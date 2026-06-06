import 'dart:io';
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_bill_service.dart';
import '../ai/ai_constants.dart';
import '../ai/bill_extraction_service.dart';
import '../../data/repositories/base_repository.dart';
import '../system/logger_service.dart';
import 'bill_recognition_normalizer.dart';

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
      aiProvider: aiProvider,
      aiEnhanced: true,
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
        'aiProvider': aiProvider,
        'aiEnhanced': aiEnhanced,
      };
}

/// OCR服务 - 识别支付截图中的金额等信息
class OcrService {
  // 使用中文识别 - 可以识别中文、数字、符号
  // 需要在 android/app/build.gradle 中添加依赖:
  // implementation 'com.google.mlkit:text-recognition-chinese:16.0.0'
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
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
  }) async {
    final startTime = DateTime.now();
    logger.info(_tag, '========== OCR识别开始 ==========');

    try {
      // 1. OCR文本识别
      logger.debug(_tag, '开始文本识别...');
      final ocrStartTime = DateTime.now();

      // 尝试不同的InputImage创建方式,解决华为权限问题
      RecognizedText recognizedText;

      try {
        // 方式1: 直接从文件路径读取(适用于大多数设备)
        logger.debug(_tag, '尝试方式1: 从文件路径读取');
        final inputImage = InputImage.fromFile(imageFile);
        recognizedText = await _textRecognizer.processImage(inputImage);
        logger.debug(_tag, '方式1成功');
      } catch (e) {
        logger.warning(_tag, '方式1失败: $e');
        logger.debug(_tag, '尝试方式2: 从文件字节读取(解决华为权限问题)');

        // 方式2: 先复制文件到App私有目录,再读取
        // 华为系统对Screenshots目录有特殊权限保护
        final appDir = await getTemporaryDirectory();
        final tempFile = File(
            '${appDir.path}/temp_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg');

        // 复制文件
        await imageFile.copy(tempFile.path);
        logger.debug(_tag, '文件已复制到: ${tempFile.path}');

        // 从临时文件读取
        final inputImage = InputImage.fromFile(tempFile);
        recognizedText = await _textRecognizer.processImage(inputImage);
        logger.debug(_tag, '方式2成功');

        // 清理临时文件
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      final rawText = recognizedText.text;
      final ocrDuration = DateTime.now().difference(ocrStartTime);
      logger.info(_tag, '[文本识别] ${ocrDuration.inMilliseconds}ms');
      logger.debug(_tag, '识别文本: $rawText');
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'ocr',
        data: {
          'rawText': rawText,
          'durationMs': ocrDuration.inMilliseconds,
        },
      ));

      // 2. 规则提取
      final ruleStartTime = DateTime.now();
      final allNumbers = _extractAllNumbers(rawText);
      final amount = _extractAmount(rawText);
      final note = _extractNote(rawText);
      final time = _extractTime(rawText);
      final ruleDuration = DateTime.now().difference(ruleStartTime);

      logger.info(_tag,
          '[规则提取] ${ruleDuration.inMilliseconds}ms | 金额:${amount ?? "无"} 备注:${note ?? "无"} 时间:${time ?? "无"} 候选:$allNumbers');

      final baseResult = OcrResult(
        amount: amount,
        note: note,
        time: time,
        rawText: rawText,
        allNumbers: allNumbers,
      );
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'rule',
        data: baseResult.toJson(),
      ));

      // 3. AI增强（如果启用）
      final enhancedResult = await _enhanceWithAI(
        baseResult,
        repo: repo,
        imageFile: imageFile,
        traceSink: traceSink,
      );
      traceSink?.call(BillExtractionTraceEvent(
        stage: 'final',
        data: enhancedResult.toJson(),
      ));

      final totalDuration = DateTime.now().difference(startTime);
      logger.info(_tag, '[总计] 识别完成 ${totalDuration.inMilliseconds}ms');

      return enhancedResult;
    } catch (e) {
      logger.error(_tag, '识别失败', e);
      rethrow;
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
        final detectedPaymentChannel = await _detectPaymentChannelFromImage(
          imageFile,
          baseResult.rawText,
        );
        final mergedPaymentChannel =
            billInfo.paymentChannel ?? baseResult.paymentChannel;
        final mergedCounterparty =
            billInfo.counterparty ?? baseResult.counterparty;
        final mergedMerchantFullName =
            billInfo.merchantFullName ?? baseResult.merchantFullName;
        final mergedAcquirer = billInfo.acquirer ?? baseResult.acquirer;
        final mergedDetails = billInfo.details ?? baseResult.details;

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

  Future<String?> _detectPaymentChannelFromImage(
    File? imageFile,
    String rawText,
  ) async {
    if (imageFile == null) return null;

    try {
      if (_hasWechatPaymentDetailText(rawText) &&
          await _hasWechatPayGreenLogo(imageFile)) {
        logger.debug(_tag, '[视觉规则] 命中微信支付绿色对勾标识');
        return '微信支付';
      }
    } catch (e) {
      logger.warning(_tag, '[视觉规则] 支付通道检测失败: $e');
    }

    return null;
  }

  bool _hasWechatPaymentDetailText(String rawText) {
    final text = rawText.replaceAll(RegExp(r'\s+'), '');
    return text.contains('收单机构') ||
        text.contains('收單機構') ||
        text.contains('财付通') ||
        text.contains('財付通') ||
        text.contains('富友支付');
  }

  Future<bool> _hasWechatPayGreenLogo(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return false;

      final width = image.width;
      final height = image.height;

      // 微信支付交易详情页的绿色对勾标识位于上方 tab 区域。
      // 限定纵向范围，避免状态栏电池图标和底部优惠文案造成误判。
      final startY = (height * 0.12).round();
      final endY = (height * 0.25).round();
      final startX = (width * 0.45).round();
      final endX = (width * 0.95).round();

      var greenPixels = 0;
      var minX = width;
      var maxX = 0;
      var minY = height;
      var maxY = 0;

      for (var y = startY; y < endY; y++) {
        for (var x = startX; x < endX; x++) {
          final offset = (y * width + x) * 4;
          final r = data.getUint8(offset);
          final g = data.getUint8(offset + 1);
          final b = data.getUint8(offset + 2);

          if (_isWechatPayGreen(r, g, b)) {
            greenPixels++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (greenPixels < 80) return false;

      final clusterWidth = maxX - minX + 1;
      final clusterHeight = maxY - minY + 1;
      return clusterWidth >= 16 &&
          clusterWidth <= width * 0.18 &&
          clusterHeight >= 16 &&
          clusterHeight <= height * 0.08;
    } finally {
      image.dispose();
    }
  }

  bool _isWechatPayGreen(int r, int g, int b) {
    return r <= 90 &&
        g >= 145 &&
        g <= 230 &&
        b >= 45 &&
        b <= 155 &&
        g - r >= 70 &&
        g - b >= 35;
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
            return amount;
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
          return amount;
        }
      }
    }

    // 通用金额匹配：xx.xx元
    final generalPattern = RegExp(r'(\d+\.\d{2})元');
    final generalMatch = generalPattern.firstMatch(cleanText);
    if (generalMatch != null) {
      final amountStr = generalMatch.group(1);
      if (amountStr != null) {
        return double.tryParse(amountStr);
      }
    }

    // 如果前面都没匹配到,尝试匹配负号金额: -14.00 或 -14.93
    // 只匹配带小数点的金额，避免误匹配时间等
    final negativePattern = RegExp(r'-(\d+\.\d{2})');
    final negativeMatches = negativePattern.allMatches(cleanText);
    if (negativeMatches.isNotEmpty) {
      // 过滤掉小额红包（小于1元的），优先选择最大的负数金额
      double? maxAmount;
      for (final match in negativeMatches) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null &&
              amount >= 0.01 &&
              amount < 100000 &&
              (maxAmount == null || amount > maxAmount)) {
            maxAmount = amount;
          }
        }
      }
      if (maxAmount != null && maxAmount >= 1.0) {
        // 只返回大于等于1元的金额，过滤小额红包
        // 重要：返回负数以表示支出
        return -maxAmount;
      }
    }

    // 最后尝试: 如果 allNumbers 中有有效金额,使用第一个
    final allNumbers = _extractAllNumbers(text);
    if (allNumbers.isNotEmpty) {
      return double.tryParse(allNumbers.first);
    }

    return null;
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
