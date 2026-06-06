import 'package:flutter_ai_kit/flutter_ai_kit.dart';

/// 账单提取任务
///
/// 从OCR文本中提取账单信息
class BillExtractionTask extends AITask<String, BillInfo> {
  @override
  String get taskType => 'bill_extraction';

  @override
  final String input;

  BillExtractionTask(this.input);

  @override
  Map<String, dynamic> toJson() => {
        'task_type': taskType,
        'ocr_text': input,
      };
}

/// 账单信息
class BillInfo {
  /// 金额
  final double? amount;

  /// 时间
  final DateTime? time;

  /// 备注
  final String? note;

  /// 分类
  final String? category;

  /// 类型（收入/支出）
  final BillType? type;

  /// 账户名称
  final String? account;

  /// 支付方式/付款方式
  final String? paymentMethod;

  /// 支付通道/账单来源（如微信支付、支付宝、云闪付、美团）
  final String? paymentChannel;

  /// 交易对方/收付款方
  final String? counterparty;

  /// 商户全称（截图中有明确字段时填写）
  final String? merchantFullName;

  /// 收单机构/清算机构（如财付通、富友支付）
  final String? acquirer;

  /// 转账来源账户名称（可选）
  final String? fromAccount;

  /// 转账目标账户名称（可选）
  final String? toAccount;

  /// 标签列表（可选）
  final List<String>? tags;

  /// 补充明细（可选，如店名、出发到达、订单号）
  final Map<String, dynamic>? details;

  /// 补充明细化文本（优先使用）
  final String? detailsText;

  /// 账本ID
  final int? ledgerId;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  const BillInfo({
    this.amount,
    this.time,
    this.note,
    this.category,
    this.type,
    this.account,
    this.paymentMethod,
    this.paymentChannel,
    this.counterparty,
    this.merchantFullName,
    this.acquirer,
    this.fromAccount,
    this.toAccount,
    this.tags,
    this.details,
    this.detailsText,
    this.ledgerId,
    this.confidence = 0.0,
  });

  /// 是否包含完整信息
  bool get isComplete => amount != null && time != null;

  /// 从JSON创建
  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      amount: json['amount']?.toDouble(),
      time: json['time'] != null ? DateTime.tryParse(json['time']) : null,
      note: json['note'] ?? json['merchant'], // 兼容旧数据
      category: json['category'],
      type: json['type'] != null ? _parseBillType(json['type']) : null,
      account: _parseString(json['account']),
      paymentMethod: _parseString(
        json['payment_method'] ??
            json['paymentMethod'] ??
            json['pay_method'] ??
            json['payMethod'],
      ),
      paymentChannel: _parseString(
        json['payment_channel'] ??
            json['paymentChannel'] ??
            json['channel'] ??
            json['source_app'] ??
            json['sourceApp'],
      ),
      counterparty: _parseString(
        json['counterparty'] ??
            json['trading_partner'] ??
            json['tradingPartner'] ??
            json['merchant_name'] ??
            json['merchantName'] ??
            json['merchant'],
      ),
      merchantFullName: _parseString(
        json['merchant_full_name'] ??
            json['merchantFullName'] ??
            json['merchant_fullname'] ??
            json['merchantFullname'],
      ),
      acquirer: _parseString(
        json['acquirer'] ??
            json['acquiring_institution'] ??
            json['acquiringInstitution'] ??
            json['settlement_institution'] ??
            json['settlementInstitution'],
      ),
      fromAccount: json['from_account'] ?? json['fromAccount'],
      toAccount: json['to_account'] ?? json['toAccount'],
      tags: _parseTags(json['tags'] ?? json['tag']),
      details: _parseDetails(json['details'] ?? json['extra']),
      detailsText: _parseString(json['details_text'] ?? json['detailsText']),
      ledgerId: json['ledgerId'],
      confidence: json['confidence']?.toDouble() ?? 0.8,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'time': time?.toIso8601String(),
        'note': note,
        'category': category,
        'type': type?.toString().split('.').last,
        'account': account,
        'payment_method': paymentMethod,
        'payment_channel': paymentChannel,
        'counterparty': counterparty,
        'merchant_full_name': merchantFullName,
        'acquirer': acquirer,
        'from_account': fromAccount,
        'to_account': toAccount,
        'tags': tags,
        'details': details,
        'details_text': detailsText,
        'ledgerId': ledgerId,
        'confidence': confidence,
      };

  static BillType? _parseBillType(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toLowerCase();
    if (str.contains('income') || str == '收入') return BillType.income;
    if (str.contains('expense') || str == '支出') return BillType.expense;
    if (str.contains('transfer') || str == '转账' || str == '轉帳') {
      return BillType.transfer;
    }
    return null;
  }

  static String? _parseString(dynamic value) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty || str.toLowerCase() == 'null') {
      return null;
    }
    return str;
  }

  static List<String>? _parseTags(dynamic value) {
    if (value == null) return null;

    final tags = <String>[];

    if (value is String) {
      tags.addAll(value
          .split(RegExp(r'[,\n，、;；|]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty));
    } else if (value is List) {
      tags.addAll(value
          .map((item) => item.toString().trim())
          .where((s) => s.isNotEmpty));
    }

    return tags.isEmpty ? null : tags;
  }

  static Map<String, dynamic>? _parseDetails(dynamic value) {
    if (value is! Map) return null;

    final details = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final rawValue = entry.value;
      if (key.isEmpty || rawValue == null) continue;

      if (rawValue is String) {
        final text = rawValue.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          details[key] = text;
        }
      } else {
        details[key] = rawValue;
      }
    }

    return details.isEmpty ? null : details;
  }

  @override
  String toString() {
    return 'BillInfo(amount: $amount, time: $time, note: $note, category: $category, type: $type, account: $account, paymentMethod: $paymentMethod, paymentChannel: $paymentChannel, counterparty: $counterparty, merchantFullName: $merchantFullName, acquirer: $acquirer, fromAccount: $fromAccount, toAccount: $toAccount, tags: $tags, details: $details, detailsText: $detailsText)';
  }
}

/// 账单类型
enum BillType {
  /// 收入
  income,

  /// 支出
  expense,

  /// 转账
  transfer,
}
