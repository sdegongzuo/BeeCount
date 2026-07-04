class ScreenshotSourceInfo {
  final String? packageName;
  final String? appName;
  final String? paymentChannel;
  final double confidence;
  final String method;
  final int? eventTimeMillis;
  final int? screenshotTimeMillis;
  final int? queryStartMillis;
  final int? queryEndMillis;
  final int eventCount;
  final int foregroundEventCount;
  final int ignoredEventCount;

  const ScreenshotSourceInfo({
    this.packageName,
    this.appName,
    this.paymentChannel,
    this.confidence = 0,
    this.method = 'none',
    this.eventTimeMillis,
    this.screenshotTimeMillis,
    this.queryStartMillis,
    this.queryEndMillis,
    this.eventCount = 0,
    this.foregroundEventCount = 0,
    this.ignoredEventCount = 0,
  });

  factory ScreenshotSourceInfo.fromMap(Map<String, dynamic> map) {
    return ScreenshotSourceInfo(
      packageName: _stringOrNull(map['sourceAppPackage']),
      appName: _stringOrNull(map['sourceAppName']),
      paymentChannel: _stringOrNull(map['sourcePaymentChannel']),
      confidence: _doubleOrZero(map['sourceConfidence']),
      method: _stringOrNull(map['sourceMethod']) ?? 'none',
      eventTimeMillis: _intOrNull(map['sourceEventTimeMillis']),
      screenshotTimeMillis: _intOrNull(map['screenshotTimeMillis']),
      queryStartMillis: _intOrNull(map['sourceQueryStartMillis']),
      queryEndMillis: _intOrNull(map['sourceQueryEndMillis']),
      eventCount: _intOrNull(map['sourceEventCount']) ?? 0,
      foregroundEventCount: _intOrNull(map['sourceForegroundEventCount']) ?? 0,
      ignoredEventCount: _intOrNull(map['sourceIgnoredEventCount']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceAppPackage': packageName,
        'sourceAppName': appName,
        'sourcePaymentChannel': paymentChannel,
        'sourceConfidence': confidence,
        'sourceMethod': method,
        'sourceEventTimeMillis': eventTimeMillis,
        'screenshotTimeMillis': screenshotTimeMillis,
        'sourceQueryStartMillis': queryStartMillis,
        'sourceQueryEndMillis': queryEndMillis,
        'sourceEventCount': eventCount,
        'sourceForegroundEventCount': foregroundEventCount,
        'sourceIgnoredEventCount': ignoredEventCount,
      };

  bool get hasPaymentChannel =>
      paymentChannel != null && paymentChannel!.trim().isNotEmpty;

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _doubleOrZero(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
