import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final runner = File('scripts/run_share_billing_c2.ps1');
  final fixturePolicy =
      File('lib/services/platform/share_billing_c2_fixture.dart');

  test('runner parses and rejects missing unlock confirmation before tools',
      () async {
    final parse = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('
            "'${runner.absolute.path}', [ref]\$null, [ref]\$errors) | Out-Null; "
            r'if ($errors.Count) { $errors | ForEach-Object Message; exit 1 }',
      ],
    );
    expect(parse.exitCode, 0, reason: '${parse.stdout}\n${parse.stderr}');

    final rejected = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        runner.absolute.path,
        '-DeviceId',
        'not-a-device',
        '-FixtureId',
        'issue6-c2-contract',
        '-Patrol',
        r'Z:\missing\patrol.bat',
        '-Adb',
        r'Z:\missing\adb.exe',
      ],
    );
    expect(rejected.exitCode, isNot(0));
    expect(
      '${rejected.stdout}\n${rejected.stderr}',
      contains('UserConfirmedUnlocked'),
    );
    expect(
      '${rejected.stdout}\n${rejected.stderr}',
      isNot(contains('executable not found')),
    );
  });

  test('runner prebuilds a unique recovery APK before Patrol', () {
    final source = runner.readAsStringSync();
    final prebuild = source.indexOf(
      'flutter build apk --debug --flavor dev -t lib/main.dart',
    );
    final copy = source.indexOf('Copy-Item -LiteralPath');
    final patrol = source.indexOf('& \$Patrol test');

    expect(prebuild, greaterThanOrEqualTo(0));
    expect(copy, greaterThan(prebuild));
    expect(patrol, greaterThan(copy));
    expect(source, contains('.codex_tmp\\c2-recovery'));
    expect(source, contains(r'$recoveryApk'));
    expect(source, contains('Recovery APK hash does not match'));
  });

  test('every restoration action is isolated inside finally', () {
    final source = runner.readAsStringSync();
    final finallyIndex =
        source.indexOf('finally {', source.indexOf('& \$Patrol test'));
    final tail = source.substring(finallyIndex);

    expect(source, contains('function Invoke-RecoveryStep'));
    expect(source, contains('catch {'));
    expect(tail, contains('bundle-bytes-and-markers'));
    expect(tail, contains('install-prebuilt-main-apk'));
    expect(tail, contains('start-production-main-activity'));
    expect(tail, contains('verify-post-run-sentinel'));
    expect(tail, contains('& \$Adb -s \$DeviceId install -r \$recoveryApk'));
    expect(
      tail,
      isNot(contains(
        'flutter build apk --debug --flavor dev -t lib/main.dart',
      )),
    );
    expect(
      source,
      contains('[AllowEmptyCollection()]'),
      reason: 'The first recovery step must accept an empty error list.',
    );
  });

  test('Patrol receives the configured adb directory without leaking PATH', () {
    final source = runner.readAsStringSync();
    final patrol = source.indexOf('& \$Patrol test');
    final pathPrefix = source.indexOf(r'$env:PATH = "$adbDirectory;');
    final pathRestore = source.indexOf(r'$env:PATH = $originalPath');

    expect(pathPrefix, greaterThanOrEqualTo(0));
    expect(pathPrefix, lessThan(patrol));
    expect(pathRestore, greaterThan(patrol));
    expect(source, contains('Split-Path -LiteralPath \$Adb -Parent'));
  });

  test('unlock, device, boot and fixture policies match the safety contract',
      () {
    final source = runner.readAsStringSync();
    final dartSource = fixturePolicy.readAsStringSync();
    const fixturePattern = r'^[a-z0-9][a-z0-9-]{0,63}$';

    expect(source, contains('[switch]\$UserConfirmedUnlocked'));
    expect(
      source.indexOf('if (-not \$UserConfirmedUnlocked)'),
      lessThan(source.indexOf('\$projectRoot =')),
    );
    expect(source, contains('get-state'));
    expect(source, contains('sys.boot_completed'));
    expect(source, contains(fixturePattern));
    expect(dartSource, contains(fixturePattern));
    expect(source, isNot(contains('[a-z0-9_-]')));
  });

  test('runner contains no destructive Android or filesystem command', () {
    final source = runner.readAsStringSync().toLowerCase();

    expect(source, contains('--no-uninstall'));
    expect(source, isNot(contains(' pm clear')));
    expect(source, isNot(contains('flutter clean')));
    expect(source, isNot(contains('remove-item')));
    expect(source, isNot(contains('del ')));
    expect(source, isNot(matches(RegExp(r'(?<!no-)--uninstall(?:\s|$)'))));
  });
}
