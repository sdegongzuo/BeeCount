package dev.flutter.plugins.integration_test;

import androidx.annotation.Keep;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Stub implementation for release builds.
 * The real integration_test plugin is only available in dev/test builds.
 * This stub allows the GeneratedPluginRegistrant to compile in release mode.
 */
@Keep
public class IntegrationTestPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {}
    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {}
}
