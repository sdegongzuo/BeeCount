import 'package:beecount/services/ai/ai_provider_factory.dart';
import 'package:beecount/services/ai/bill_extraction_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects webp mime type for vision uploads', () {
    expect(
      AIProviderFactory.imageMimeTypeForPath('/tmp/beecount_ai_vision/bill.webp'),
      'image/webp',
    );
  });

  test('detects jpeg mime type for vision uploads', () {
    expect(
      AIProviderFactory.imageMimeTypeForPath('/tmp/beecount_ai_vision/bill.jpg'),
      'image/jpeg',
    );
  });

  test('uses webp for compressed vision uploads', () {
    expect(BillExtractionService.visionCompressFormat, CompressFormat.webp);
    expect(BillExtractionService.visionCompressExtension, '.webp');
  });

}
