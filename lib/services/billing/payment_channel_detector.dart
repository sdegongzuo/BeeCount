import 'dart:io';
import 'dart:ui' as ui;

class PaymentChannelDetection {
  final String channel;
  final double confidence;
  final String detectorId;
  final List<String> evidence;

  const PaymentChannelDetection({
    required this.channel,
    required this.confidence,
    required this.detectorId,
    required this.evidence,
  });

  bool get isHighConfidence => confidence >= 0.85;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'confidence': confidence,
        'detector_id': detectorId,
        'evidence': evidence,
      };
}

class PaymentChannelDetectionContext {
  final String rawText;
  final File? imageFile;

  late final String text = rawText.trim();
  late final String compact = rawText.replaceAll(RegExp(r'\s+'), '');

  PaymentChannelDetectionContext({
    required this.rawText,
    this.imageFile,
  });

  bool contains(String value) => compact.contains(value);

  bool hasPattern(Pattern pattern) => pattern.allMatches(compact).isNotEmpty;
}

abstract class PaymentChannelDetector {
  String get id;

  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  );
}

class PaymentChannelResolver {
  final List<PaymentChannelDetector> detectors;

  const PaymentChannelResolver({this.detectors = defaultDetectors});

  static const defaultDetectors = <PaymentChannelDetector>[
    WechatPaymentChannelDetector(),
    UnionPayPaymentChannelDetector(),
    AlipayPaymentChannelDetector(),
    MeituanPaymentChannelDetector(),
    JdPaymentChannelDetector(),
    PinduoduoPaymentChannelDetector(),
  ];

  Future<PaymentChannelDetection?> resolve(
    String rawText, {
    File? imageFile,
  }) async {
    final detections = await resolveAll(rawText, imageFile: imageFile);
    if (detections.isEmpty) return null;
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections.first;
  }

  Future<List<PaymentChannelDetection>> resolveAll(
    String rawText, {
    File? imageFile,
  }) async {
    final context = PaymentChannelDetectionContext(
      rawText: rawText,
      imageFile: imageFile,
    );
    final result = <PaymentChannelDetection>[];
    for (final detector in detectors) {
      final detection = await detector.detect(context);
      if (detection != null) result.add(detection);
    }
    return result;
  }
}

class AlipayPaymentChannelDetector extends _TextPaymentChannelDetector {
  const AlipayPaymentChannelDetector();

  @override
  String get id => 'payment_channel.alipay.detail_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    if (_addIfContains(context, evidence, '账单详情')) {
      evidence.add('structure:bill_detail');
    }
    if (_addIfPattern(context, evidence, RegExp(r'-\d+\.\d{2}'))) {
      evidence.add('amount:negative_top_amount');
    }
    if (_addIfAnyContains(context, evidence, const [
      '支付成功',
      '交易成功',
      '交易成戌功',
      '付款成功',
      '自动扣款成功',
      '支付咸功',
      '支付成咸功',
    ])) {
      evidence.add('status:success');
    }
    final hasPayTime = _addIfAnyContains(context, evidence, const [
      '支付时间',
      '支付时问',
    ]);
    final hasPayMethod = _addIfAnyContains(context, evidence, const [
      '付款方式',
      '付款万式',
      '付款歉万式',
    ]);

    final detailFields = _countContains(context, evidence, const [
      '支付奖励',
      '订单号',
      '商家订单号',
      '账单管理',
      '账单分类',
      '全部账单',
      '管理自动扣款',
    ]);

    final hasCore = context.contains('账单详情') &&
        hasPayTime &&
        hasPayMethod &&
        (context.hasPattern(RegExp(r'-\d+\.\d{2}')) ||
            context.contains('支付成功') ||
            context.contains('交易成功') ||
            context.contains('交易成戌功') ||
            context.contains('支付咸功') ||
            context.contains('支付成咸功') ||
            context.contains('自动扣款成功') ||
            context.contains('付款成功'));
    if (!hasCore || detailFields < 2) return null;

    return _detection(
      channel: '支付宝',
      confidence: detailFields >= 4 ? 0.94 : 0.88,
      evidence: evidence,
    );
  }
}

class UnionPayPaymentChannelDetector extends _TextPaymentChannelDetector {
  const UnionPayPaymentChannelDetector();

  @override
  String get id => 'payment_channel.unionpay.detail_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    final hasTitle = _addIfAnyContains(context, evidence, const [
      '银联交易详情',
      '银联交易详倩',
      '银联交易详',
    ]);
    final hasName =
        _addIfAnyContains(context, evidence, const ['云闪付', '银联云闪付']);
    final fieldCount = _countContains(context, evidence, const [
      '卡号',
      '交易时间',
      '交易类别',
      '发卡机构',
      '收单机构',
      '商户编号',
      '商户蝙号',
      '商户骗号',
      '终端编号',
      '终端骗号',
      '终瑞骗号',
      '终端編号',
      '批次号',
      '凭证号',
      '授权号',
      '参考号',
    ]);

    if (hasTitle && fieldCount >= 3) {
      return _detection(
        channel: '云闪付',
        confidence: fieldCount >= 6 ? 0.98 : 0.95,
        evidence: evidence,
      );
    }
    final hasUnionPayMethod = context.contains('银联准贷记卡') ||
        context.contains('银联信用卡') ||
        context.contains('银联卡');

    final hasUnionPayReceiptStructure = context.contains('付款方式') &&
        (context.contains('原价') || context.contains('优惠')) &&
        _addIfAnyContains(context, evidence, const [
          '支付成功',
          '支付咸功',
        ]);

    if ((hasName || hasUnionPayMethod) &&
        (fieldCount >= 2 || hasUnionPayReceiptStructure)) {
      return _detection(
        channel: '云闪付',
        confidence: fieldCount >= 4 ? 0.9 : 0.88,
        evidence: evidence,
      );
    }
    return null;
  }
}

class MeituanPaymentChannelDetector extends _TextPaymentChannelDetector {
  const MeituanPaymentChannelDetector();

  @override
  String get id => 'payment_channel.meituan.detail_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    final hasBillDetail = _addIfAnyContains(context, evidence, const [
      '账单详情',
      '果单详情',
    ]);
    final hasAllBills = _addIfContains(context, evidence, '全部账单');
    final hasFaq = _addIfAnyContains(context, evidence, const [
      '常见问题',
      '常见间题',
      '对订单有疑问',
      '美团账单',
      '美团客服',
    ]);
    final fieldCount = _countContains(context, evidence, const [
      '订单金额',
      '订单金颜',
      '支付优惠',
      '支付方式',
      '支付万式',
      '下单时间',
      '消费场景',
      '交易单号',
      '商家单号',
      '高家单号',
    ]);

    if (hasBillDetail && (hasAllBills || hasFaq) && fieldCount >= 3) {
      return _detection(
        channel: '美团',
        confidence: fieldCount >= 5 ? 0.95 : 0.88,
        evidence: evidence,
      );
    }
    return null;
  }
}

class JdPaymentChannelDetector extends _TextPaymentChannelDetector {
  const JdPaymentChannelDetector();

  @override
  String get id => 'payment_channel.jd.detail_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    final hasBillDetail = _addIfContains(context, evidence, '账单详情');
    final hasJdStructure = _addIfAnyContains(context, evidence, const [
      '京东平台商户',
      '京东服务',
      '京东支付',
      '京东',
    ]);
    final fieldCount = _countContains(context, evidence, const [
      '支付立减',
      '创建时间',
      '总订单编号',
      '商户单号',
      '服务详情',
    ]);
    final hasOrderGroup = _addIfPattern(context, evidence, RegExp(r'共\d+笔订单'));

    if (hasBillDetail && hasJdStructure && (fieldCount >= 2 || hasOrderGroup)) {
      return _detection(
        channel: '京东',
        confidence: fieldCount >= 4 ? 0.95 : 0.88,
        evidence: evidence,
      );
    }
    return null;
  }
}

class PinduoduoPaymentChannelDetector extends _TextPaymentChannelDetector {
  const PinduoduoPaymentChannelDetector();

  @override
  String get id => 'payment_channel.pinduoduo.detail_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    final hasBillDetail = _addIfAnyContains(context, evidence, const [
      '账单详情',
      '账单详惰',
    ]);
    final hasStatus = context.contains('当前状态') && context.contains('支付成功');
    if (hasStatus) evidence.add('field:当前状态=支付成功');
    final hasProduct = _addIfContains(context, evidence, '商品详情');
    final hasOrder = _addIfContains(context, evidence, '订单详情');
    final hasXpOrder = _addIfPattern(context, evidence, RegExp(r'XP\d{16,}'));
    final fieldCount = _countContains(context, evidence, const [
      '支付时间',
      '支付方式',
      '交易单号',
      '商户单号',
    ]);

    if (hasBillDetail &&
        hasStatus &&
        hasProduct &&
        hasOrder &&
        (fieldCount >= 2 || hasXpOrder)) {
      return _detection(
        channel: '拼多多',
        confidence: hasXpOrder || fieldCount >= 4 ? 0.96 : 0.9,
        evidence: evidence,
      );
    }
    return null;
  }
}

class WechatPaymentChannelDetector extends _TextPaymentChannelDetector {
  const WechatPaymentChannelDetector();

  @override
  String get id => 'payment_channel.wechat.visual_and_acquirer_rules';

  @override
  Future<PaymentChannelDetection?> detect(
    PaymentChannelDetectionContext context,
  ) async {
    final evidence = <String>[];
    final hasPaymentDetailText = _hasWechatPaymentDetailText(context);
    if (hasPaymentDetailText) {
      evidence.add('text:收单机构/财付通/富友支付');
    }

    if (hasPaymentDetailText && context.imageFile != null) {
      final hasLogo = await _hasWechatPayGreenLogo(context.imageFile!);
      if (hasLogo) {
        evidence.add('visual:wechat_green_logo');
        return _detection(
          channel: '微信支付',
          confidence: 0.98,
          evidence: evidence,
        );
      }
    }

    final explicitlyWechat = _addIfContains(context, evidence, '微信支付');
    final hasWechatAcquirer =
        context.contains('财付通') || context.contains('富友支付');
    final hasPaymentFields = context.contains('支付时间') &&
        (context.contains('支付方式') || context.contains('付款方式'));
    final looksUnionPay = context.contains('银联交易详情') ||
        context.contains('银联云闪付') ||
        context.contains('云闪付');

    if (!looksUnionPay &&
        (explicitlyWechat || hasWechatAcquirer) &&
        hasPaymentFields) {
      return _detection(
        channel: '微信支付',
        confidence: explicitlyWechat ? 0.9 : 0.86,
        evidence: evidence,
      );
    }

    return null;
  }

  bool _hasWechatPaymentDetailText(PaymentChannelDetectionContext context) {
    return context.contains('收单机构') ||
        context.contains('收單機構') ||
        context.contains('财付通') ||
        context.contains('財付通') ||
        context.contains('富友支付');
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
}

abstract class _TextPaymentChannelDetector implements PaymentChannelDetector {
  const _TextPaymentChannelDetector();

  PaymentChannelDetection _detection({
    required String channel,
    required double confidence,
    required List<String> evidence,
  }) {
    return PaymentChannelDetection(
      channel: channel,
      confidence: confidence,
      detectorId: id,
      evidence: evidence.toSet().toList(),
    );
  }

  bool _addIfContains(
    PaymentChannelDetectionContext context,
    List<String> evidence,
    String value,
  ) {
    if (!context.contains(value)) return false;
    evidence.add('text:$value');
    return true;
  }

  bool _addIfAnyContains(
    PaymentChannelDetectionContext context,
    List<String> evidence,
    List<String> values,
  ) {
    var matched = false;
    for (final value in values) {
      matched = _addIfContains(context, evidence, value) || matched;
    }
    return matched;
  }

  bool _addIfPattern(
    PaymentChannelDetectionContext context,
    List<String> evidence,
    RegExp pattern,
  ) {
    if (!context.hasPattern(pattern)) return false;
    evidence.add('pattern:${pattern.pattern}');
    return true;
  }

  int _countContains(
    PaymentChannelDetectionContext context,
    List<String> evidence,
    List<String> values,
  ) {
    var count = 0;
    for (final value in values) {
      if (_addIfContains(context, evidence, value)) count++;
    }
    return count;
  }
}
