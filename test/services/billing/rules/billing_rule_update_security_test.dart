import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BillingRuleUpdateConfiguration', () {
    test('missing manifest URL disables updates with a diagnostic reason', () {
      final configuration = BillingRuleUpdateConfiguration.fromValues(
        manifestUrl: '',
        currentAppVersion: '1.2.3',
      );

      expect(configuration.isEnabled, isFalse);
      expect(configuration.disabledReason, contains('未配置'));
    });

    for (final url in <String>[
      'https://example.com/manifest.json',
      'http://rules.beecount.test/manifest.json',
      'https://localhost/manifest.json',
      'https://127.0.0.1/manifest.json',
      'https://0.0.0.0/manifest.json',
      'https://10.0.0.1/manifest.json',
      'https://100.64.0.1/manifest.json',
      'https://169.254.1.1/manifest.json',
      'https://172.16.0.1/manifest.json',
      'https://192.168.0.1/manifest.json',
      'https://192.0.2.1/manifest.json',
      'https://198.18.0.1/manifest.json',
      'https://224.0.0.1/manifest.json',
      'https://240.0.0.1/manifest.json',
      'https://255.255.255.255/manifest.json',
      'https://[::]/manifest.json',
      'https://[::1]/manifest.json',
      'https://[fc00::1]/manifest.json',
      'https://[fe80::1]/manifest.json',
      'https://[2001:db8::1]/manifest.json',
      'https://[2001:2::1]/manifest.json',
      'https://[2002:7f00:1::]/manifest.json',
      'https://[ff00::1]/manifest.json',
      'https://[::ffff:127.0.0.1]/manifest.json',
      'https://127.1/manifest.json',
      'https://2130706433/manifest.json',
      'https://0x7f000001/manifest.json',
      'https://0177.0.0.1/manifest.json',
    ]) {
      test('unsafe manifest URL is disabled: $url', () {
        final configuration = BillingRuleUpdateConfiguration.fromValues(
          manifestUrl: url,
          currentAppVersion: '1.2.3',
        );

        expect(configuration.isEnabled, isFalse);
        expect(configuration.disabledReason, isNotEmpty);
      });
    }
  });

  group('SemanticVersion', () {
    test('compares prerelease identifiers using SemVer precedence', () {
      expect(
        SemanticVersion.parse('1.2.3-beta.2') <
            SemanticVersion.parse('1.2.3-beta.11'),
        isTrue,
      );
      expect(
        SemanticVersion.parse('1.2.3-rc.1') < SemanticVersion.parse('1.2.3'),
        isTrue,
      );
      expect(
        SemanticVersion.parse('1.2.3+build.7') ==
            SemanticVersion.parse('1.2.3+build.9'),
        isTrue,
      );
    });

    test('compares arbitrarily large core and numeric prerelease identifiers',
        () {
      expect(
        SemanticVersion.parse('999999999999999999999999999999.0.0')
            .compareTo(SemanticVersion.parse('10.0.0')),
        isPositive,
      );
      expect(
        SemanticVersion.parse(
          '1.0.0-beta.999999999999999999999999999999',
        ).compareTo(SemanticVersion.parse('1.0.0-beta.10')),
        isPositive,
      );
    });

    test('malformed versions have stable parse diagnostics', () {
      expect(SemanticVersion.tryParse('1.0.0-01'), isNull);
      expect(
        () => SemanticVersion.parse('1.0.0-01'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '无效的语义版本：1.0.0-01',
          ),
        ),
      );
    });
  });

  group('BillingRuleSecureHttpLoader', () {
    test('rejects a host when any DNS result is non-public before connecting',
        () async {
      var connectionAttempts = 0;
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: (_) async => [
          InternetAddress('93.184.216.34'),
          InternetAddress.loopbackIPv4,
        ],
        pinnedClientFactory: (_, __) {
          connectionAttempts++;
          return MockClient((_) async => http.Response('ok', 200));
        },
      );

      await expectLater(
        loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(seconds: 1),
          maxBytes: 1024,
        ),
        throwsA(isA<BillingRuleNetworkPolicyException>()),
      );
      expect(connectionAttempts, 0);
    });

    test('connects only through the exact DNS result that passed validation',
        () async {
      final resolved = InternetAddress('93.184.216.34');
      Uri? pinnedUri;
      List<InternetAddress>? pinnedAddresses;
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: (_) async => [resolved],
        pinnedClientFactory: (uri, addresses) {
          pinnedUri = uri;
          pinnedAddresses = List.of(addresses);
          return MockClient(
            (request) async => http.Response('ok', 200, request: request),
          );
        },
      );

      expect(
        await loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(seconds: 1),
          maxBytes: 1024,
        ),
        'ok',
      );
      expect(pinnedUri?.host, 'rules.beecount.test');
      expect(pinnedAddresses, [resolved]);
    });

    test('wall-clock deadline cancels a slow response stream before retrying',
        () async {
      final tracker = _SlowStreamTracker();
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: _publicAddressResolver,
        clientFactory: () => _SlowStreamingClient(tracker),
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          loader.load(
            Uri.parse('https://rules.beecount.test/manifest.json'),
            timeout: const Duration(milliseconds: 30),
            maxBytes: 1024,
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(tracker.activeSubscriptions, 0);
      }

      expect(tracker.cancellations, 2);
      expect(tracker.maximumActiveSubscriptions, 1);
    });

    test('deadline cancels a shared client request without closing the client',
        () async {
      final tracker = _SlowStreamTracker();
      final sharedClient = _SlowStreamingClient(tracker);
      final loader = BillingRuleSecureHttpLoader(
        client: sharedClient,
        addressResolver: _publicAddressResolver,
      );

      await expectLater(
        loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(milliseconds: 30),
          maxBytes: 1024,
        ),
        throwsA(isA<TimeoutException>()),
      );

      expect(tracker.activeSubscriptions, 0);
      expect(tracker.cancellations, 1);
      expect(tracker.clientCloses, 0);
    });

    test('rejects redirects instead of following an untrusted final URI',
        () async {
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: _publicAddressResolver,
        clientFactory: () => MockClient((request) async => http.Response(
              '',
              302,
              headers: {'location': 'https://evil.test/rules.toml'},
              request: request,
            )),
      );

      await expectLater(
        loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(seconds: 1),
          maxBytes: 1024,
        ),
        throwsA(isA<BillingRuleHttpException>()),
      );
    });

    test('times out a stalled request', () async {
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: _publicAddressResolver,
        clientFactory: () =>
            MockClient((_) => Completer<http.Response>().future),
      );

      await expectLater(
        loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(milliseconds: 10),
          maxBytes: 1024,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('rejects a response body over the configured byte limit', () async {
      final loader = BillingRuleSecureHttpLoader(
        addressResolver: _publicAddressResolver,
        clientFactory: () => MockClient((request) async => http.Response(
              'x' * 1025,
              200,
              request: request,
            )),
      );

      await expectLater(
        loader.load(
          Uri.parse('https://rules.beecount.test/manifest.json'),
          timeout: const Duration(seconds: 1),
          maxBytes: 1024,
        ),
        throwsA(isA<BillingRuleResponseTooLargeException>()),
      );
    });
  });

  group('BillingRuleUpdateService security gates', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rule_security_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('does not call the network when production configuration is disabled',
        () async {
      var calls = 0;
      final service = _service(
        tempDir,
        configuration: BillingRuleUpdateConfiguration.fromValues(
          manifestUrl: '',
          currentAppVersion: '1.2.3',
        ),
        manifestLoader: (_) async {
          calls++;
          return '';
        },
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.disabled);
      expect(result.message, contains('未配置'));
      expect(calls, 0);
    });

    test('rejects a cross-host package before download', () async {
      var packageCalls = 0;
      final service = _service(
        tempDir,
        manifest: _manifest(packageUrl: 'https://evil.test/rules.toml'),
        packageDownloader: (_) async {
          packageCalls++;
          return '';
        },
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.securityPolicyRejected);
      expect(packageCalls, 0);
    });

    test('allows an explicitly trusted package host', () async {
      final toml = _validToml();
      final service = _service(
        tempDir,
        configuration: _configuration(trustedPackageHosts: {'cdn.test'}),
        manifest: _manifest(
          packageUrl: 'https://cdn.test/rules.toml',
          sha: _sha256(toml),
        ),
        packageDownloader: (_) async => toml,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.activated);
    });

    test('rejects an HTTP package before download', () async {
      var packageCalls = 0;
      final service = _service(
        tempDir,
        manifest: _manifest(packageUrl: 'http://rules.test/rules.toml'),
        packageDownloader: (_) async {
          packageCalls++;
          return '';
        },
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.securityPolicyRejected);
      expect(packageCalls, 0);
    });

    test('incompatible minAppVersion prevents package download', () async {
      var packageCalls = 0;
      final service = _service(
        tempDir,
        configuration: _configuration(currentAppVersion: '1.2.3-beta.2'),
        manifest: _manifest(minAppVersion: '1.2.3-beta.11'),
        packageDownloader: (_) async {
          packageCalls++;
          return '';
        },
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.incompatibleAppVersion);
      expect(packageCalls, 0);
    });

    test('oversized injected manifest is rejected before JSON parsing',
        () async {
      final service = _service(
        tempDir,
        configuration: _configuration(maxManifestBytes: 16),
        manifestLoader: (_) async => 'x' * 17,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.responseTooLarge);
    });

    test('oversized injected package is rejected before hashing', () async {
      final service = _service(
        tempDir,
        configuration: _configuration(maxRulePackageBytes: 16),
        manifest: _manifest(),
        packageDownloader: (_) async => 'x' * 17,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.responseTooLarge);
    });

    test('offline failure uses short retry backoff, not the success interval',
        () async {
      var now = DateTime.utc(2026, 7, 17, 10);
      var manifestCalls = 0;
      final service = _service(
        tempDir,
        clock: () => now,
        manifestLoader: (_) async {
          manifestCalls++;
          throw const SocketException('offline');
        },
      );

      expect(
        (await service.checkForUpdateIfDue()).status,
        BillingRuleUpdateStatus.failed,
      );
      expect(
        (await service.checkForUpdateIfDue()).status,
        BillingRuleUpdateStatus.notDue,
      );
      now = now.add(const Duration(minutes: 16));
      expect(
        (await service.checkForUpdateIfDue()).status,
        BillingRuleUpdateStatus.failed,
      );
      expect(manifestCalls, 2);
      final state = jsonDecode(
        await File('${tempDir.path}/billing_rules.last_check.json')
            .readAsString(),
      ) as Map<String, dynamic>;
      expect(state['lastSuccessAt'], isNull);
      expect(state['lastAttemptAt'], '2026-07-17T10:16:00.000Z');
    });
  });
}

BillingRuleUpdateConfiguration _configuration({
  String currentAppVersion = '1.2.3',
  Set<String> trustedPackageHosts = const {},
  int maxManifestBytes = 64 * 1024,
  int maxRulePackageBytes = 2 * 1024 * 1024,
}) =>
    BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: 'https://rules.test/manifest.json',
      currentAppVersion: currentAppVersion,
      trustedPackageHosts: trustedPackageHosts,
      maxManifestBytes: maxManifestBytes,
      maxRulePackageBytes: maxRulePackageBytes,
    );

BillingRuleUpdateService _service(
  Directory directory, {
  BillingRuleUpdateConfiguration? configuration,
  String? manifest,
  BillingRuleManifestLoader? manifestLoader,
  BillingRulePackageDownloader? packageDownloader,
  BillingRuleUpdateClock? clock,
}) =>
    BillingRuleUpdateService(
      storageDirectory: directory,
      configuration: configuration ?? _configuration(),
      manifestLoader: manifestLoader ?? (_) async => manifest ?? _manifest(),
      rulePackageDownloader: packageDownloader ?? (_) async => _validToml(),
      smokeTest: (_) async => true,
      upgradeEvaluation: (_) async => true,
      personalRegression: (_) async =>
          const BillingRulePersonalRegressionResult.passed(),
      personalRuleArchiver: (_) async {},
      clock: clock,
    );

String _manifest({
  String packageUrl = 'https://rules.test/rules.toml',
  String minAppVersion = '1.0.0',
  String? sha,
}) =>
    jsonEncode({
      'latest': {
        'schemaVersion': 1,
        'rulesVersion': 'remote',
        'minAppVersion': minAppVersion,
        'url': packageUrl,
        'sha256': sha ?? _sha256(_validToml()),
      },
    });

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

Future<List<InternetAddress>> _publicAddressResolver(String _) async =>
    [InternetAddress('93.184.216.34')];

String _validToml() => r'''
schemaVersion = 1
rulePackageVersion = 2
rulesVersion = "remote"
normalizationVersion = 1

[[templates]]
id = "secure_remote"
enabled = true
priority = 100

[templates.match]
keywordsAll = ["支付时间"]

[[templates.extract]]
field = "amount"
type = "regex"
pattern = '\d+'
parser = "signedAmount"
''';

class _SlowStreamTracker {
  int activeSubscriptions = 0;
  int maximumActiveSubscriptions = 0;
  int cancellations = 0;
  int clientCloses = 0;
}

class _SlowStreamingClient extends http.BaseClient {
  final _SlowStreamTracker tracker;

  _SlowStreamingClient(this.tracker);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    late StreamController<List<int>> controller;
    Timer? timer;
    controller = StreamController<List<int>>(
      onListen: () {
        tracker.activeSubscriptions++;
        if (tracker.activeSubscriptions > tracker.maximumActiveSubscriptions) {
          tracker.maximumActiveSubscriptions = tracker.activeSubscriptions;
        }
        timer = Timer.periodic(
          const Duration(milliseconds: 10),
          (_) => controller.add(const [120]),
        );
      },
      onCancel: () {
        timer?.cancel();
        tracker.activeSubscriptions--;
        tracker.cancellations++;
      },
    );
    return http.StreamedResponse(controller.stream, 200, request: request);
  }

  @override
  void close() {
    tracker.clientCloses++;
  }
}
