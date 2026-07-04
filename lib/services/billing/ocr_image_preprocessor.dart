import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'rules/billing_rule_models.dart';

export 'rules/billing_rule_models.dart' show BillingImageRegion;

typedef OcrTopTextLineLocator = Future<List<OcrTopTextLine>> Function(
  File imageFile,
  OcrTopScanWindow scanWindow,
);

class OcrTopScanWindow {
  final int imageWidth;
  final int imageHeight;
  final BillingImageRegion region;
  final Duration timeout;

  const OcrTopScanWindow({
    required this.imageWidth,
    required this.imageHeight,
    required this.region,
    required this.timeout,
  });
}

class OcrTopTextLine {
  final String text;
  final BillingImageRegion box;

  const OcrTopTextLine({
    required this.text,
    required this.box,
  });
}

class OcrImagePreprocessor {
  static const _methodNone = 'none';
  static const _methodMaskStatusBar = 'maskStatusBar';

  final OcrTopTextLineLocator? topTextLineLocator;
  final Directory? outputDirectory;
  final Duration topOcrTimeout;
  final double safeAreaRatio;
  final double fallbackMaskRatio;
  final int padding;
  final ui.Color maskColor;

  const OcrImagePreprocessor({
    this.topTextLineLocator,
    this.outputDirectory,
    this.topOcrTimeout = const Duration(milliseconds: 180),
    this.safeAreaRatio = 0.08,
    this.fallbackMaskRatio = 0.06,
    this.padding = 6,
    this.maskColor = const ui.Color(0xFFFFFFFF),
  });

  Future<OcrPreprocessResult> preprocess(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    final bytes = await imageFile.readAsBytes();
    final image = await _decodeImage(bytes);
    final imageWidth = image.width;
    final imageHeight = image.height;
    final safeAreaHeight = _ratioHeight(imageHeight, safeAreaRatio);
    final metadata = <String, dynamic>{
      'safe_area_ratio': safeAreaRatio,
      'safe_area_height': safeAreaHeight,
      'fallback_mask_ratio': fallbackMaskRatio,
      'top_ocr_timeout_ms': topOcrTimeout.inMilliseconds,
    };

    final decision = await _locateMaskRegion(
      imageFile,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      safeAreaHeight: safeAreaHeight,
      metadata: metadata,
    );

    if (decision.region == null) {
      stopwatch.stop();
      return OcrPreprocessResult(
        method: _methodNone,
        originalPath: imageFile.path,
        outputPath: imageFile.path,
        originalWidth: imageWidth,
        originalHeight: imageHeight,
        outputWidth: imageWidth,
        outputHeight: imageHeight,
        metadata: {
          ...metadata,
          ...decision.extraMetadata,
          'status_bar_source': decision.source,
          if (decision.reason != null) 'skip_reason': decision.reason,
          'preprocess_duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
    }

    final outputFile = await _writeMaskedImage(
      imageFile: imageFile,
      image: image,
      region: decision.region!,
    );

    stopwatch.stop();
    return OcrPreprocessResult(
      method: _methodMaskStatusBar,
      originalPath: imageFile.path,
      outputPath: outputFile.path,
      originalWidth: imageWidth,
      originalHeight: imageHeight,
      outputWidth: imageWidth,
      outputHeight: imageHeight,
      maskedRegions: [decision.region!],
      metadata: {
        ...metadata,
        ...decision.extraMetadata,
        'status_bar_source': decision.source,
        if (decision.fallbackReason != null)
          'fallback_reason': decision.fallbackReason,
        'preprocess_duration_ms': stopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<_MaskDecision> _locateMaskRegion(
    File imageFile, {
    required int imageWidth,
    required int imageHeight,
    required int safeAreaHeight,
    required Map<String, dynamic> metadata,
  }) async {
    final locator = topTextLineLocator;
    if (locator == null) {
      return _fallbackDecision(
        imageWidth,
        imageHeight,
        reason: 'top_ocr_unavailable',
      );
    }

    List<OcrTopTextLine> lines;
    try {
      lines = await locator(
        imageFile,
        OcrTopScanWindow(
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          region: BillingImageRegion(
            left: 0,
            top: 0,
            width: imageWidth,
            height: safeAreaHeight,
          ),
          timeout: topOcrTimeout,
        ),
      ).timeout(topOcrTimeout);
    } on TimeoutException {
      return _fallbackDecision(
        imageWidth,
        imageHeight,
        reason: 'top_ocr_timeout',
      );
    } catch (e) {
      return _fallbackDecision(
        imageWidth,
        imageHeight,
        reason: 'top_ocr_error',
        extraMetadata: {'top_ocr_error': e.toString()},
      );
    }

    metadata['top_ocr_line_count'] = lines.length;
    if (lines.isEmpty) {
      return _fallbackDecision(
        imageWidth,
        imageHeight,
        reason: 'top_ocr_empty',
      );
    }

    final candidate = _bestStatusBarCandidate(
      lines,
      imageHeight: imageHeight,
      safeAreaHeight: safeAreaHeight,
    );
    if (candidate == null) {
      final hasBusinessLine =
          lines.any((line) => _isBusinessContent(line.text));
      if (hasBusinessLine) {
        return const _MaskDecision(
          source: 'top_ocr',
          reason: 'business_content_preserved',
        );
      }
      return _fallbackDecision(
        imageWidth,
        imageHeight,
        reason: 'top_ocr_no_status_candidate',
      );
    }

    final region = _expandAndClamp(
      candidate.box,
      imageWidth: imageWidth,
      safeAreaHeight: safeAreaHeight,
    );
    metadata.addAll({
      'candidate_text': candidate.text,
      'candidate_box': candidate.box.toJson(),
      'padding': padding,
    });

    return _MaskDecision(source: 'top_ocr', region: region);
  }

  OcrTopTextLine? _bestStatusBarCandidate(
    List<OcrTopTextLine> lines, {
    required int imageHeight,
    required int safeAreaHeight,
  }) {
    final sorted = [...lines]..sort((a, b) => a.box.top.compareTo(b.box.top));
    for (final line in sorted) {
      if (_isStatusBarCandidate(
        line,
        imageHeight: imageHeight,
        safeAreaHeight: safeAreaHeight,
      )) {
        return line;
      }
    }
    return null;
  }

  bool _isStatusBarCandidate(
    OcrTopTextLine line, {
    required int imageHeight,
    required int safeAreaHeight,
  }) {
    if (line.box.top < 0 || line.box.top > safeAreaHeight) return false;
    if (line.box.top > math.max(24, (imageHeight * 0.035).round())) {
      return false;
    }
    if (line.box.height > math.max(42, (imageHeight * 0.022).round())) {
      return false;
    }
    if (_isBusinessContent(line.text)) return false;
    return _hasStatusBarText(line.text);
  }

  bool _hasStatusBarText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return false;
    return RegExp(r'\d{1,2}:\d{2}').hasMatch(normalized) ||
        RegExp(r'(?:\d{1,3}%|Wi-?Fi|5G|4G|3G|LTE|HD|电量|信号|中国移动|中国联通|中国电信)',
                caseSensitive: false)
            .hasMatch(normalized);
  }

  bool _isBusinessContent(String text) {
    return RegExp(r'交易详情|账单详情|支付成功|支付失败|付款成功|收款成功|商户|商家|金额|¥|￥|-?\d+\.\d{2}')
        .hasMatch(text);
  }

  _MaskDecision _fallbackDecision(
    int imageWidth,
    int imageHeight, {
    required String reason,
    Map<String, dynamic> extraMetadata = const {},
  }) {
    final height = _ratioHeight(imageHeight, fallbackMaskRatio);
    return _MaskDecision(
      source: 'safe_ratio',
      fallbackReason: reason,
      region: BillingImageRegion(
        left: 0,
        top: 0,
        width: imageWidth,
        height: height,
      ),
      extraMetadata: extraMetadata,
    );
  }

  BillingImageRegion _expandAndClamp(
    BillingImageRegion box, {
    required int imageWidth,
    required int safeAreaHeight,
  }) {
    final left = math.max(0, box.left - padding);
    final top = math.max(0, box.top - padding);
    final right = math.min(imageWidth, box.left + box.width + padding);
    final bottom = math.min(safeAreaHeight, box.top + box.height + padding);
    return BillingImageRegion(
      left: left,
      top: top,
      width: math.max(0, right - left),
      height: math.max(0, bottom - top),
    );
  }

  int _ratioHeight(int imageHeight, double ratio) {
    return math.max(1, (imageHeight * ratio).round()).clamp(1, imageHeight);
  }

  Future<File> _writeMaskedImage({
    required File imageFile,
    required ui.Image image,
    required BillingImageRegion region,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    canvas.drawRect(
      ui.Rect.fromLTWH(
        region.left.toDouble(),
        region.top.toDouble(),
        region.width.toDouble(),
        region.height.toDouble(),
      ),
      ui.Paint()..color = maskColor,
    );
    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(image.width, image.height);
    final byteData =
        await outputImage.toByteData(format: ui.ImageByteFormat.png);
    final outputBytes = byteData!.buffer.asUint8List();
    final directory = await _ensureOutputDirectory();
    final outputFile = File(
      '${directory.path}${Platform.pathSeparator}${_outputFileName(imageFile)}',
    );
    await outputFile.writeAsBytes(outputBytes, flush: true);
    return outputFile;
  }

  Future<Directory> _ensureOutputDirectory() async {
    final directory = outputDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}beecount_ocr_preprocess',
        );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _outputFileName(File imageFile) {
    final name = imageFile.uri.pathSegments.isEmpty
        ? 'image'
        : imageFile.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${stem}_ocr_preprocessed_$timestamp.png';
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _MaskDecision {
  final String source;
  final BillingImageRegion? region;
  final String? fallbackReason;
  final String? reason;
  final Map<String, dynamic> extraMetadata;

  const _MaskDecision({
    required this.source,
    this.region,
    this.fallbackReason,
    this.reason,
    this.extraMetadata = const {},
  });
}
