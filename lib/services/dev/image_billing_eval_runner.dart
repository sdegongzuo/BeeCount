import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/base_repository.dart';
import '../ai/bill_extraction_service.dart';
import '../billing/ocr_service.dart';
import '../system/logger_service.dart';

class ImageBillingEvalRunResult {
  final String inputDir;
  final String outputPath;
  final int total;
  final int succeeded;
  final int failed;

  const ImageBillingEvalRunResult({
    required this.inputDir,
    required this.outputPath,
    required this.total,
    required this.succeeded,
    required this.failed,
  });
}

class ImageBillingEvalRunner {
  static const _tag = 'ImageBillingEval';
  static const _evalDirName = 'image_billing_eval';
  static const _inputDirName = 'input';
  static const _outputDirName = 'output';

  static Future<String> getDefaultInputDirPath() async {
    final root = await _getEvalRootDirectory();
    return p.join(root.path, _inputDirName);
  }

  static Future<String> getDefaultOutputDirPath() async {
    final root = await _getEvalRootDirectory();
    return p.join(root.path, _outputDirName);
  }

  static Future<ImageBillingEvalRunResult> run({
    BaseRepository? repo,
    String? inputDirPath,
    String? outputDirPath,
    bool enableAiEnhancement = true,
  }) async {
    final root = inputDirPath == null || outputDirPath == null
        ? await _getEvalRootDirectory()
        : null;
    final inputDir =
        Directory(inputDirPath ?? p.join(root!.path, _inputDirName));
    final outputDir =
        Directory(outputDirPath ?? p.join(root!.path, _outputDirName));
    await inputDir.create(recursive: true);
    await outputDir.create(recursive: true);

    final files = await _listImageFiles(inputDir);
    logger.info(_tag, '开始图片记账评测: ${files.length} 张, input=${inputDir.path}');

    final cases = <Map<String, dynamic>>[];
    var succeeded = 0;
    var failed = 0;

    final ocrService = OcrService();
    for (final file in files) {
      final traces = <BillExtractionTraceEvent>[];
      final caseId = _caseIdForFile(file);
      final startedAt = DateTime.now();

      try {
        final result = await ocrService.recognizePaymentImage(
          file,
          repo: repo,
          traceSink: traces.add,
          enableAiEnhancement: enableAiEnhancement,
        );
        succeeded++;
        cases.add(_buildCaseJson(
          id: caseId,
          file: file,
          startedAt: startedAt,
          traces: traces,
          finalResult: result.toJson(),
        ));
      } catch (e, st) {
        failed++;
        logger.error(_tag, '样本评测失败: ${file.path}', e, st);
        cases.add({
          'id': caseId,
          'image': _goldenImagePathForFile(file),
          'sourcePath': file.path,
          'error': e.toString(),
          'traces': traces.map((event) => event.toJson()).toList(),
        });
      }
    }

    final now = DateTime.now();
    final stamp = _formatTimestamp(now);
    final outputFile = File(p.join(outputDir.path, 'actual-$stamp.json'));
    final latestFile = File(p.join(outputDir.path, 'latest_actual.json'));
    final payload = {
      'schema': 'beecount.image_billing_eval.actual.v1',
      'generatedAt': now.toIso8601String(),
      'inputDir': inputDir.path,
      'cases': cases,
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    await outputFile.writeAsString(json);
    await latestFile.writeAsString(json);

    logger.info(_tag,
        '图片记账评测完成: success=$succeeded failed=$failed output=${outputFile.path}');
    return ImageBillingEvalRunResult(
      inputDir: inputDir.path,
      outputPath: outputFile.path,
      total: files.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  static Map<String, dynamic> _buildCaseJson({
    required String id,
    required File file,
    required DateTime startedAt,
    required List<BillExtractionTraceEvent> traces,
    required Map<String, dynamic> finalResult,
  }) {
    final ocr = _firstTraceData(traces, 'ocr');
    final rule = _firstTraceData(traces, 'rule');
    final prompt = _firstTraceData(traces, 'prompt');
    final aiResponse = _firstTraceData(traces, 'ai_response');
    final ocrEngine = ocr?['engine'] ?? finalResult['ocr_engine'];

    return {
      'id': id,
      'image': _goldenImagePathForFile(file),
      'sourcePath': file.path,
      'startedAt': startedAt.toIso8601String(),
      'ocrText': ocr?['rawText'],
      'ocrEngine': ocrEngine,
      'rule': rule,
      'prompt': prompt?['prompt'],
      'aiResponse': aiResponse?['response'],
      'ai': aiResponse?['parsed'],
      'final': _normalizeFinalResult(finalResult),
      'traces': traces.map((event) => event.toJson()).toList(),
    };
  }

  static Map<String, dynamic> _normalizeFinalResult(Map<String, dynamic> raw) {
    return {
      'amount': raw['amount'],
      'type': raw['aiType'],
      'time': raw['time'],
      'note': raw['note'],
      'category': raw['aiCategoryName'],
      'account': raw['aiAccountName'],
      'payment_method': raw['payment_method'],
      'payment_channel': raw['payment_channel'],
      'counterparty': raw['counterparty'],
      'merchant_full_name': raw['merchant_full_name'],
      'acquirer': raw['acquirer'],
      'details': raw['details'],
      'rawText': raw['rawText'],
      'ocr_engine': raw['ocr_engine'],
      'aiEnhanced': raw['aiEnhanced'],
    };
  }

  static Map<String, dynamic>? _firstTraceData(
    List<BillExtractionTraceEvent> traces,
    String stage,
  ) {
    for (final event in traces) {
      if (event.stage == stage) {
        return event.data;
      }
    }
    return null;
  }

  static Future<Directory> _getEvalRootDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, _evalDirName));
  }

  static Future<List<File>> _listImageFiles(Directory inputDir) async {
    if (!await inputDir.exists()) {
      return [];
    }
    final files = <File>[];
    await for (final entity in inputDir.list()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (const {'.jpg', '.jpeg', '.png', '.webp'}.contains(ext)) {
        files.add(entity);
      }
    }
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  static String _caseIdForFile(File file) {
    final name = p.basename(file.path);
    return switch (name) {
      'alipay_etc_single.jpg' => 'alipay_etc_single',
      'alipay_mimo_token_single.jpg' => 'alipay_mimo_token_single',
      'alipay_taobao_flash_single.jpg' => 'alipay_taobao_flash_single',
      'alipay_tmall_single.jpg' => 'alipay_tmall_single',
      'wechat_pinduoduo_single.jpg' => 'wechat_pinduoduo_single',
      'wechat_yangguofu_single.jpg' => 'wechat_yangguofu_single',
      'meituan_xiaoxiang_single.jpg' => 'meituan_xiaoxiang_single',
      'meituan_xiaoxiang_digital_single.jpg' =>
        'meituan_xiaoxiang_digital_single',
      'meituan_xiaoxiang_monthpay_single.jpg' =>
        'meituan_xiaoxiang_monthpay_single',
      'jd_platform_single.jpg' => 'jd_platform_single',
      'jd_multi_order_single.jpg' => 'jd_multi_order_single',
      'pinduoduo_membership_single.jpg' => 'pinduoduo_membership_single',
      'pinduoduo_hardware_single.jpg' => 'pinduoduo_hardware_single',
      'pinduoduo_tool_single.jpg' => 'pinduoduo_tool_single',
      'unionpay_xicha_single.jpg' => 'unionpay_xicha_single',
      'unionpay_pinduoduo_single.jpg' => 'unionpay_pinduoduo_single',
      'unionpay_kfc_single.jpg' => 'unionpay_kfc_single',
      'unionpay_ele_single.jpg' => 'unionpay_ele_single',
      '云闪付-银联优惠-单条.jpg' => 'unionpay_cafacoffee_discount_single',
      '云闪付-银联优惠8.90-单条.jpg' =>
        'unionpay_cafacoffee_discount_890_single',
      '美团-天津测试超市优惠-单条.jpg' =>
        'meituan_xiaoxiang_icbc_discount_single',
      '支付宝-沙沙百货优惠-单条.jpg' => 'alipay_shasha_discount_single',
      '支付宝-友门鹿优惠-单条.jpg' => 'alipay_youmenlu_discount_single',
      '微信-滴滴充电优惠-单条.jpg' => 'wechat_didi_charging_discount_single',
      '微信-抖音生活服务优惠-单条.jpg' =>
        'wechat_douyin_service_discount_single',
      '美团-隆江猪脚饭-单条.jpg' => 'meituan_longjiang_takeout_single',
      '支付宝-MinT商家订单号-单条.jpg' =>
        'alipay_min_t_merchant_order_single',
      '支付宝-单条.jpg' => 'alipay_etc_single',
      '支付宝-单条2.jpg' => 'alipay_mimo_token_single',
      '支付宝-单条3.jpg' => 'alipay_taobao_flash_single',
      '支付宝-单条4.jpg' => 'alipay_tmall_single',
      '微信-单条.jpg' => 'wechat_pinduoduo_single',
      '微信-单条2.jpg' => 'wechat_yangguofu_single',
      '美团-单条.jpg' => 'meituan_xiaoxiang_single',
      '美团-单条2.jpg' => 'meituan_xiaoxiang_digital_single',
      '美团-单条3.jpg' => 'meituan_xiaoxiang_monthpay_single',
      '京东-单条.jpg' => 'jd_platform_single',
      '京东-单条2.jpg' => 'jd_multi_order_single',
      '拼多多-单条.jpg' => 'pinduoduo_membership_single',
      '拼多多-单条2.jpg' => 'pinduoduo_hardware_single',
      '拼多多-单条3.jpg' => 'pinduoduo_tool_single',
      '云闪付-单条.jpg' => 'unionpay_xicha_single',
      '云闪付-单条2.jpg' => 'unionpay_pinduoduo_single',
      '云闪付-单条3.jpg' => 'unionpay_kfc_single',
      '云闪付-单条4.jpg' => 'unionpay_ele_single',
      _ => p.basenameWithoutExtension(name),
    };
  }

  static String _goldenImagePathForFile(File file) {
    final name = p.basename(file.path);
    final goldenName = switch (name) {
      'alipay_etc_single.jpg' => '支付宝-单条.jpg',
      'alipay_mimo_token_single.jpg' => '支付宝-单条2.jpg',
      'alipay_taobao_flash_single.jpg' => '支付宝-单条3.jpg',
      'alipay_tmall_single.jpg' => '支付宝-单条4.jpg',
      'wechat_pinduoduo_single.jpg' => '微信-单条.jpg',
      'wechat_yangguofu_single.jpg' => '微信-单条2.jpg',
      'meituan_xiaoxiang_single.jpg' => '美团-单条.jpg',
      'meituan_xiaoxiang_digital_single.jpg' => '美团-单条2.jpg',
      'meituan_xiaoxiang_monthpay_single.jpg' => '美团-单条3.jpg',
      'jd_platform_single.jpg' => '京东-单条.jpg',
      'jd_multi_order_single.jpg' => '京东-单条2.jpg',
      'pinduoduo_membership_single.jpg' => '拼多多-单条.jpg',
      'pinduoduo_hardware_single.jpg' => '拼多多-单条2.jpg',
      'pinduoduo_tool_single.jpg' => '拼多多-单条3.jpg',
      'unionpay_xicha_single.jpg' => '云闪付-单条.jpg',
      'unionpay_pinduoduo_single.jpg' => '云闪付-单条2.jpg',
      'unionpay_kfc_single.jpg' => '云闪付-单条3.jpg',
      'unionpay_ele_single.jpg' => '云闪付-单条4.jpg',
      '云闪付-银联优惠-单条.jpg' => '云闪付-银联优惠-单条.jpg',
      '云闪付-银联优惠8.90-单条.jpg' => '云闪付-银联优惠8.90-单条.jpg',
      '美团-天津测试超市优惠-单条.jpg' => '美团-天津测试超市优惠-单条.jpg',
      '支付宝-沙沙百货优惠-单条.jpg' => '支付宝-沙沙百货优惠-单条.jpg',
      '支付宝-友门鹿优惠-单条.jpg' => '支付宝-友门鹿优惠-单条.jpg',
      '微信-滴滴充电优惠-单条.jpg' => '微信-滴滴充电优惠-单条.jpg',
      '微信-抖音生活服务优惠-单条.jpg' => '微信-抖音生活服务优惠-单条.jpg',
      '美团-隆江猪脚饭-单条.jpg' => '美团-隆江猪脚饭-单条.jpg',
      '支付宝-MinT商家订单号-单条.jpg' =>
        '支付宝-MinT商家订单号-单条.jpg',
      _ => name,
    };
    return 'image/单条/$goldenName';
  }

  static String _formatTimestamp(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
