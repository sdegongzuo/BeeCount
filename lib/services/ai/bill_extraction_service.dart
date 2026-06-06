import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/tasks/bill_extraction_task.dart';
import '../system/logger_service.dart';
import 'ai_constants.dart';
import 'ai_provider_factory.dart';

typedef BillExtractionTraceSink = void Function(BillExtractionTraceEvent event);

class BillExtractionTraceEvent {
  final String stage;
  final Map<String, dynamic> data;

  const BillExtractionTraceEvent({
    required this.stage,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'data': data,
      };
}

/// 账单提取服务
///
/// 统一处理账单提取业务逻辑，支持三种输入源：
/// - 文本（OCR 识别结果、手动输入）
/// - 图片（支付截图）
/// - 语音（语音记账）
class BillExtractionService {
  static const String _tag = 'BillExtraction';

  /// 支出分类列表
  final List<String>? expenseCategories;

  /// 收入分类列表
  final List<String>? incomeCategories;

  /// 账户列表
  final List<String>? accounts;

  /// 用户自定义提示词模板
  String? _customPromptTemplate;

  final BillExtractionTraceSink? traceSink;

  BillExtractionService({
    this.expenseCategories,
    this.incomeCategories,
    this.accounts,
    this.traceSink,
  });

  /// 初始化（加载用户配置）
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AIConstants.keyAiCustomPrompt);
    // 空字符串视为未配置，避免新装/异常下走出空提示词导致 AI 无法识账
    _customPromptTemplate =
        (saved != null && saved.trim().isNotEmpty) ? saved : null;
  }

  // ============================================================
  // 公开 API
  // ============================================================

  /// 从文本提取账单信息
  ///
  /// [text] OCR 识别文本或用户输入
  Future<BillInfo?> extractFromText(String text) async {
    if (text.trim().isEmpty) {
      logger.warning(_tag, '输入文本为空');
      return null;
    }

    try {
      final prompt = _buildPrompt(
        inputSource: '从以下支付账单文本中',
        ocrText: text,
      );

      logger.debug(_tag, '提取文本账单，prompt长度: ${prompt.length}');
      _emitTrace('prompt', {
        'mode': 'text',
        'prompt': prompt,
      });

      final response = await AIProviderFactory.chat(
        prompt,
        temperature: 0.3,
        logTag: _tag,
      );

      final billInfo = _parseResponse(response);
      _emitTrace('ai_response', {
        'mode': 'text',
        'response': response,
        'parsed': billInfo?.toJson(),
      });
      return billInfo;
    } on AIException catch (e) {
      logger.warning(_tag, '文本账单提取失败: ${e.message}');
      return null;
    } catch (e, st) {
      logger.error(_tag, '文本账单提取异常', e, st);
      return null;
    }
  }

  /// 从图片提取账单信息
  ///
  /// [image] 支付截图文件
  /// [ocrText] ML Kit OCR 文本。图片模型仍看原图，OCR 文本用于补充字段和降低幻觉。
  Future<BillInfo?> extractFromImage(
    File image, {
    String ocrText = '',
  }) async {
    if (!await image.exists()) {
      logger.warning(_tag, '图片文件不存在');
      return null;
    }

    try {
      final prompt = _buildPrompt(
        inputSource: '分析支付账单截图，从中',
        ocrText: ocrText.trim().isEmpty
            ? 'OCR文本未提供，请仅根据图片内容判断。'
            : 'OCR识别文本如下（可能有错字、漏字或顺序错乱，请结合图片判断）：\n$ocrText',
      );

      logger.debug(_tag, '提取图片账单，prompt长度: ${prompt.length}');
      _emitTrace('prompt', {
        'mode': 'image',
        'prompt': prompt,
      });

      final response = await AIProviderFactory.vision(
        image,
        prompt,
        logTag: _tag,
      );

      final billInfo = _parseResponse(response);
      _emitTrace('ai_response', {
        'mode': 'image',
        'response': response,
        'parsed': billInfo?.toJson(),
      });
      return billInfo;
    } on AIException catch (e) {
      logger.warning(_tag, '图片账单提取失败: ${e.message}');
      return null;
    } catch (e, st) {
      logger.error(_tag, '图片账单提取异常', e, st);
      return null;
    }
  }

  /// 从语音提取账单信息
  ///
  /// [audio] 录音文件
  /// 两步流程：语音转文字 → 文本提取账单
  Future<(BillInfo? bill, String? recognizedText)> extractFromVoice(
    File audio,
  ) async {
    if (!await audio.exists()) {
      logger.warning(_tag, '音频文件不存在');
      return (null, null);
    }

    try {
      // 步骤1：语音转文字
      logger.info(_tag, '步骤1: 语音转文字');
      final recognizedText = await AIProviderFactory.speechToText(
        audio,
        logTag: _tag,
      );
      logger.info(_tag, '识别结果: $recognizedText');

      if (recognizedText.trim().isEmpty) {
        logger.warning(_tag, '语音识别结果为空');
        return (null, null);
      }

      // 步骤2：从文字提取账单
      logger.info(_tag, '步骤2: 提取账单信息');
      final billInfo = await extractFromText(recognizedText);

      return (billInfo, recognizedText);
    } on AIException catch (e) {
      logger.warning(_tag, '语音账单提取失败: ${e.message}');
      return (null, null);
    } catch (e, st) {
      logger.error(_tag, '语音账单提取异常', e, st);
      return (null, null);
    }
  }

  /// 仅语音转文字（不提取账单）
  ///
  /// [audio] 录音文件
  Future<String?> speechToText(File audio) async {
    if (!await audio.exists()) {
      logger.warning(_tag, '音频文件不存在');
      return null;
    }

    try {
      final text = await AIProviderFactory.speechToText(audio, logTag: _tag);
      return text.trim().isEmpty ? null : text;
    } on AIException catch (e) {
      logger.warning(_tag, '语音转文字失败: ${e.message}');
      return null;
    } catch (e, st) {
      logger.error(_tag, '语音转文字异常', e, st);
      return null;
    }
  }

  // ============================================================
  // 常量
  // ============================================================

  /// 默认提示词模板（供外部使用，如提示词编辑页面）
  static const String defaultPromptTemplate = '''{{INPUT_SOURCE}}提取记账信息，返回JSON。

当前时间：{{CURRENT_TIME}}

{{OCR_TEXT}}

{{CATEGORIES}}{{ACCOUNTS}}

字段说明：
1. amount: 金额（支出负数，收入正数）
2. time: ISO8601格式，尽量推断时间：
   - 明确时间（如"14:30"、"2025-11-25"）→直接使用
   - 相对日期（昨天、前天、上周）→推算具体日期
   - 时间段（早上、中午、晚上）→使用合理时刻（早上09:00、中午12:00、晚上19:00）
   - 完全没提时间→使用当前时间
3. note: 备注（必须≤15字，超过则精简），提取优先级：
   - 商家/店铺名（如"天津海河测试餐厅甲"、"肯德基"）
   - 商品名称（长标题需简化，如"2025春季新款黑色斜纹格纹半身裙"→"黑色半身裙"）
   - 用户描述（如"给女儿买"）
   - 没有则留空
4. category: 从分类列表选择（转账可填"转账"）
5. type: income、expense 或 transfer
6. account: 支付账户（收入/支出可用）
7. payment_method: 实际付款方式/付款账户（可选，如"中国银行信用卡(2853)"、"平安银行信用卡(2299)"、"零钱"、"余额宝"、"数字人民币-招商银行钱包(0076)"；不要填微信支付/支付宝这类通道）
8. payment_channel: 支付通道/账单来源（可选，如"微信支付"、"支付宝"、"云闪付"、"美团"、"京东"、"拼多多"；不要填银行卡）
9. counterparty: 交易对方/收付款方（可选，如收款方、付款方、商户名、店铺名；优先真实消费对象）
10. merchant_full_name: 商户全称（可选，仅截图明确出现"商户全称"等字段时填写）
11. acquirer: 收单机构/清算机构（可选，如财付通、富友支付；不能作为 counterparty）
12. from_account: 转出账户（仅转账可用）
13. to_account: 转入账户（仅转账可用）
14. tag/tags: 标签（可选，单个字符串或字符串数组）
15. details: 补充明细（可选，JSON对象；只放不适合 note 但有用的信息，如店名、出发到达、订单号、原价/优惠）

示例：
输入"昨天中午吃饭50" → {"amount":-50,"time":"2025-11-24T12:00:00","category":"餐饮","type":"expense"}
输入"早上在天津海河测试餐厅甲买咖啡30" → {"amount":-30,"time":"{{CURRENT_DATE}}T09:00:00","note":"天津海河测试餐厅甲","category":"咖啡","type":"expense"}
输入"商品:2025春季新款黑色半身裙 金额:￥299" → {"amount":-299,"note":"黑色半身裙","category":"服装","type":"expense"}
输入"向天津津门测试餐厅乙付款25.21 支付方式:中国银行信用卡(2853)" → {"amount":-25.21,"note":"天津津门测试餐厅乙","counterparty":"天津津门测试餐厅乙","payment_channel":"微信支付","payment_method":"中国银行信用卡(2853)","category":"餐饮","type":"expense"}
输入"从建行转800到零钱包" → {"amount":800,"category":"转账","type":"transfer","from_account":"建行","to_account":"零钱包","tag":"自己"}

平台支付截图规则：
- 微信/支付宝/云闪付/财付通/收单机构/清算机构是支付通道或机构，不是消费商户；不要把它们作为 note 或 counterparty。
- 微信支付截图：如果界面是微信支付/交易详情，即使顶部显示拼多多、天津津门测试餐厅乙等商户，payment_channel 也必须填"微信支付"；顶部商户填 counterparty/note；收单机构填 acquirer。
- 微信支付 logo 规则：只要截图里有绿色对勾样式的"微信支付"logo/标识，payment_channel 必须填"微信支付"；不要因为顶部商户是拼多多、美团、天津津门测试餐厅乙等就把 payment_channel 改成商户或平台名。
- 支付宝截图：payment_channel 填"支付宝"；付款方式里的银行卡/余额/花呗填 payment_method。
- 云闪付/银联云闪付截图：payment_channel 填"云闪付"；"财付通"只可能是 acquirer 或商户名的一部分，不要填 payment_channel；note/counterparty 要去掉"_财付通"、"(银联云闪付)"。
- 美团/京东/拼多多账单详情截图：payment_channel 分别填"美团"、"京东"、"拼多多"。
- payment_channel 表示支付通道或账单来源；payment_method 表示银行卡、钱包、余额、数字人民币钱包等实际付款方式。
- 主金额优先取顶部大号实付/支付成功金额；不要把原价、优惠、支付立减、积分、奖励、订单号、交易号、商户单号、银行卡尾号当作 amount。
- 平台订单 note 规则：counterparty 可以是平台/店铺/商户；note 优先具体商品或服务详情。例如京东商品"可孚疫苗防水贴医用点痣可洗澡婴儿童迷..."应简化为"防水贴"；拼多多"拼多多月卡会员超值神券包"应简化为"月卡会员券包"；美团"消费场景 天津测试超市"可填"天津测试超市"。
- note 必须≤15字，输出前必须精简；去掉平台名前缀、"财付通"、"银联云闪付"、"订单详情"、"商户单号"、"平台商户"等非消费对象描述。
- 分类：平台购物、超市、生鲜、会员券包优先选购物/日用/超市/订阅类，不要仅因出现"会员"就选"视频会员"；餐饮饮品可选餐饮/饮品/奶茶中最贴近分类列表的一项。
- details 规则：不要把 details 拼成一句长文本，按 key-value 返回。例如 ETC 可返回 {"from":"天津测试甲站","to":"天津测试乙站","route_time":"2026-05-29 20:24:55至2026-05-29 20:33:30"}；微信支付拼多多可返回 {"merchant_order_no":"XP..."}；门店可返回 {"store_name":"南开测试店"}。

注意：只返回JSON，尽量推断时间不要返回null，note必须≤15字（长标题要精简）''';

  /// 构建提示词
  String _buildPrompt({
    required String inputSource,
    required String ocrText,
  }) {
    final categoryHint = _buildCategoryHint();
    final accountHint = _buildAccountHint();

    // 获取当前日期时间
    final now = DateTime.now();
    final currentDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentHour = now.hour.toString().padLeft(2, '0');
    final currentMinute = now.minute.toString().padLeft(2, '0');
    final currentTime = '$currentDate $currentHour:$currentMinute';

    // 使用用户自定义模板或默认模板（空字符串也回退到默认）
    final custom = _customPromptTemplate;
    final template = (custom != null && custom.trim().isNotEmpty)
        ? custom
        : defaultPromptTemplate;

    // 替换变量
    final prompt = template
        .replaceAll('{{INPUT_SOURCE}}', inputSource)
        .replaceAll('{{CURRENT_TIME}}', currentTime)
        .replaceAll('{{CURRENT_DATE}}', currentDate)
        .replaceAll('{{OCR_TEXT}}', ocrText)
        .replaceAll('{{CATEGORIES}}', categoryHint)
        .replaceAll('{{ACCOUNTS}}', accountHint);

    return _ensureMetadataFieldsPrompt(prompt);
  }

  String _ensureMetadataFieldsPrompt(String prompt) {
    var ensured = prompt;

    if (!prompt.contains('payment_method') ||
        !prompt.contains('payment_channel') ||
        !prompt.contains('counterparty') ||
        !prompt.contains('acquirer') ||
        !prompt.contains('details')) {
      ensured = '''$ensured

补充字段要求：
- payment_method: 实际付款方式/付款账户（可选，如"中国银行信用卡(2853)"、"平安银行信用卡(2299)"、"零钱"、"余额宝"、"数字人民币-招商银行钱包(0076)"；不要填微信支付/支付宝这类通道）
- payment_channel: 支付通道/账单来源（可选，如"微信支付"、"支付宝"、"云闪付"、"美团"、"京东"、"拼多多"；不要填银行卡）
- counterparty: 交易对方/收付款方（可选，如收款方、付款方、商户名、店铺名；优先真实消费对象）
- merchant_full_name: 商户全称（可选，仅截图明确出现"商户全称"等字段时填写）
- acquirer: 收单机构/清算机构（可选，如财付通、富友支付；不能作为 counterparty）
- details: 补充明细（可选，JSON对象；只放不适合 note 但有用的信息，如店名、出发到达、订单号、原价/优惠）
如果能识别，请在JSON中返回 payment_method、payment_channel、counterparty、merchant_full_name、acquirer、details；不能确定则省略或返回null。''';
    }

    if (!ensured.contains('绿色对勾') || !ensured.contains('微信支付')) {
      ensured = '''$ensured

微信支付视觉判定：
- 视觉模型看原图时，如果截图里有绿色对勾样式的"微信支付"logo/标识，payment_channel 必须填"微信支付"。
- 这条规则优先于顶部商户名或商品平台名；例如顶部显示"拼多多"，但有绿色对勾微信支付标识时，counterparty/note 可填"拼多多"，payment_channel 仍填"微信支付"。''';
    }

    return ensured;
  }

  void _emitTrace(String stage, Map<String, dynamic> data) {
    traceSink?.call(BillExtractionTraceEvent(stage: stage, data: data));
  }

  /// 构建分类提示
  String _buildCategoryHint() {
    if ((expenseCategories != null && expenseCategories!.isNotEmpty) ||
        (incomeCategories != null && incomeCategories!.isNotEmpty)) {
      final parts = <String>[];
      if (expenseCategories != null && expenseCategories!.isNotEmpty) {
        parts.add('支出：${expenseCategories!.join('、')}');
      }
      if (incomeCategories != null && incomeCategories!.isNotEmpty) {
        parts.add('收入：${incomeCategories!.join('、')}');
      }
      return '分类列表：\n${parts.join('\n')}';
    } else {
      return '分类列表：\n支出：餐饮、交通、购物、娱乐、居家、通讯、水电、医疗、教育\n收入：工资、理财、红包、奖金、报销、兼职';
    }
  }

  /// 构建账户提示
  String _buildAccountHint() {
    if (accounts != null && accounts!.isNotEmpty) {
      return '\n账户列表：${accounts!.join('、')}';
    }
    return '';
  }

  /// 解析 AI 响应
  BillInfo? _parseResponse(String response) {
    logger.debug(_tag, '原始响应: $response');

    // 提取 JSON（可能包含 ```json 包裹，也可能包含嵌套 details 对象）
    final jsonStr = _extractJsonObject(response);
    if (jsonStr == null) {
      logger.warning(_tag, '响应中没有找到JSON: $response');
      return null;
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final billInfo = BillInfo.fromJson(json);
      logger.info(_tag, '账单提取成功: $billInfo');
      return billInfo;
    } catch (e) {
      logger.warning(_tag, 'JSON解析失败: $e');
      return null;
    }
  }

  String? _extractJsonObject(String response) {
    final start = response.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < response.length; i++) {
      final char = response.codeUnitAt(i);

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == 0x5C) {
          escaped = true;
        } else if (char == 0x22) {
          inString = false;
        }
        continue;
      }

      if (char == 0x22) {
        inString = true;
      } else if (char == 0x7B) {
        depth++;
      } else if (char == 0x7D) {
        depth--;
        if (depth == 0) {
          return response.substring(start, i + 1);
        }
      }
    }

    return null;
  }
}
