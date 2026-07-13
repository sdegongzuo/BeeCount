import 'package:flutter/services.dart';

class ShareBillingConfirmationHandoff {
  static const _channel = MethodChannel('com.tntlikely.beecount/share');

  static Future<void> acknowledgeOpened(int jobId) async {
    try {
      await _channel.invokeMethod<void>(
        'acknowledgeShareBillingConfirmationOpened',
        {'jobId': jobId},
      );
    } on MissingPluginException {
      // Non-Android widget/unit tests do not install the native channel.
    }
  }
}
