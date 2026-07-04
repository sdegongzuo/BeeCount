import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beecount/services/billing/ocr_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrImagePreprocessor', () {
    test('masks detected status bar without overwriting the original image',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr-preprocess-');
      final inputFile = File('${tempDir.path}/wechat.png');
      final inputBytes = await _createPngBytes(
        width: 1080,
        height: 2400,
        statusColor: _rgba(0xDD, 0x22, 0x22),
        bodyColor: _rgba(0xFF, 0xFF, 0xFF),
      );
      await inputFile.writeAsBytes(inputBytes);

      final preprocessor = OcrImagePreprocessor(
        topTextLineLocator: (_, __) async => const [
          OcrTopTextLine(
            text: '12:30 5G 80%',
            box: BillingImageRegion(left: 20, top: 12, width: 360, height: 24),
          ),
        ],
        outputDirectory: tempDir,
      );

      final result = await preprocessor.preprocess(inputFile);

      expect(result.method, 'maskStatusBar');
      expect(result.originalPath, inputFile.path);
      expect(result.outputPath, isNot(inputFile.path));
      expect(result.originalWidth, 1080);
      expect(result.originalHeight, 2400);
      expect(result.outputWidth, 1080);
      expect(result.outputHeight, 2400);
      expect(result.maskedRegions, hasLength(1));
      expect(result.maskedRegions.single.toJson(), {
        'left': 14,
        'top': 6,
        'width': 372,
        'height': 36,
      });
      expect(result.metadata['status_bar_source'], 'top_ocr');
      expect(result.metadata['candidate_text'], '12:30 5G 80%');
      expect(result.metadata['preprocess_duration_ms'], isA<int>());
      expect(await inputFile.readAsBytes(), inputBytes);

      final outputFile = File(result.outputPath!);
      expect(await outputFile.exists(), isTrue);
      expect(await _samplePixel(outputFile, 20, 12), _rgba(0xFF, 0xFF, 0xFF));
    });

    test('keeps original image when top OCR sees only business content',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr-preprocess-');
      final inputFile = File('${tempDir.path}/no_status.png');
      final inputBytes = await _createPngBytes(
        width: 1080,
        height: 2400,
        statusColor: _rgba(0xFF, 0xFF, 0xFF),
        bodyColor: _rgba(0xFF, 0xFF, 0xFF),
      );
      await inputFile.writeAsBytes(inputBytes);

      final preprocessor = OcrImagePreprocessor(
        topTextLineLocator: (_, __) async => const [
          OcrTopTextLine(
            text: '支付成功',
            box: BillingImageRegion(left: 420, top: 70, width: 240, height: 54),
          ),
        ],
        outputDirectory: tempDir,
      );

      final result = await preprocessor.preprocess(inputFile);

      expect(result.method, 'none');
      expect(result.outputPath, inputFile.path);
      expect(result.maskedRegions, isEmpty);
      expect(result.metadata['status_bar_source'], 'top_ocr');
      expect(result.metadata['fallback_reason'], isNull);
    });

    test(
        'adds padding around top OCR status bar candidate and clamps to safe area',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr-preprocess-');
      final inputFile = File('${tempDir.path}/status_edge.png');
      await inputFile.writeAsBytes(
        await _createPngBytes(width: 1080, height: 2400),
      );

      final preprocessor = OcrImagePreprocessor(
        padding: 10,
        topTextLineLocator: (_, __) async => const [
          OcrTopTextLine(
            text: '中国移动 14:05 Wi-Fi 92%',
            box: BillingImageRegion(left: 8, top: 2, width: 500, height: 32),
          ),
        ],
        outputDirectory: tempDir,
      );

      final result = await preprocessor.preprocess(inputFile);

      expect(result.maskedRegions.single.toJson(), {
        'left': 0,
        'top': 0,
        'width': 518,
        'height': 44,
      });
      expect(result.metadata['candidate_box'], {
        'left': 8,
        'top': 2,
        'width': 500,
        'height': 32,
      });
      expect(result.metadata['padding'], 10);
    });

    test('falls back to safe ratio mask when top OCR times out', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr-preprocess-');
      final inputFile = File('${tempDir.path}/timeout.png');
      await inputFile.writeAsBytes(
        await _createPngBytes(width: 1000, height: 2000),
      );

      final preprocessor = OcrImagePreprocessor(
        topOcrTimeout: const Duration(milliseconds: 10),
        topTextLineLocator: (_, __) =>
            Future.delayed(const Duration(milliseconds: 80), () => const []),
        outputDirectory: tempDir,
      );

      final result = await preprocessor.preprocess(inputFile);

      expect(result.method, 'maskStatusBar');
      expect(result.maskedRegions.single.toJson(), {
        'left': 0,
        'top': 0,
        'width': 1000,
        'height': 120,
      });
      expect(result.metadata['status_bar_source'], 'safe_ratio');
      expect(result.metadata['fallback_reason'], 'top_ocr_timeout');
      expect(result.metadata['safe_area_ratio'], 0.08);
      expect(result.metadata['fallback_mask_ratio'], 0.06);
    });

    test('falls back to safe ratio mask when top OCR returns no line boxes',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr-preprocess-');
      final inputFile = File('${tempDir.path}/empty_boxes.png');
      await inputFile.writeAsBytes(
        await _createPngBytes(width: 800, height: 1600),
      );

      final preprocessor = OcrImagePreprocessor(
        topTextLineLocator: (_, __) async => const [],
        outputDirectory: tempDir,
      );

      final result = await preprocessor.preprocess(inputFile);

      expect(result.method, 'maskStatusBar');
      expect(result.maskedRegions.single.toJson(), {
        'left': 0,
        'top': 0,
        'width': 800,
        'height': 96,
      });
      expect(result.metadata['fallback_reason'], 'top_ocr_empty');
    });
  });
}

Future<Uint8List> _createPngBytes({
  required int width,
  required int height,
  int? statusColor,
  int? bodyColor,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..color = ui.Color(bodyColor ?? _rgba(0xFF, 0xFF, 0xFF));
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
  paint.color = ui.Color(statusColor ?? _rgba(0x22, 0x22, 0x22));
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), 64), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<int> _samplePixel(File file, int x, int y) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  final byteData =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * frame.image.width + x) * 4;
  final bytes = byteData!.buffer.asUint8List();
  return _rgba(
      bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]);
}

int _rgba(int red, int green, int blue, [int alpha = 0xFF]) {
  return (alpha << 24) | (red << 16) | (green << 8) | blue;
}
