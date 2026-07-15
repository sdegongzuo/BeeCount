import 'package:beecount/services/platform/share_billing_c2_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareBillingC2Fixture', () {
    test('both missing ids leave the production path disabled', () {
      expect(
        ShareBillingC2Fixture.resolve(
          compileTimeId: '',
          runtimeId: null,
          isDebug: true,
        ),
        isNull,
      );
    });

    test('runtime id without compile-time authority is rejected', () {
      expect(
        () => ShareBillingC2Fixture.resolve(
          compileTimeId: '',
          runtimeId: 'issue6-c2-20260716',
          isDebug: true,
        ),
        throwsStateError,
      );
    });

    test('compile-time fixture requires runtime correlation', () {
      expect(
        () => ShareBillingC2Fixture.resolve(
          compileTimeId: 'issue6-c2-20260716',
          runtimeId: null,
          isDebug: true,
        ),
        throwsStateError,
      );
    });

    test('release builds reject fixture ids even when both ids match', () {
      expect(
        () => ShareBillingC2Fixture.resolve(
          compileTimeId: 'issue6-c2-20260716',
          runtimeId: 'issue6-c2-20260716',
          isDebug: false,
        ),
        throwsStateError,
      );
    });

    test('invalid compile-time fixture ids are rejected before path derivation',
        () {
      expect(
        () => ShareBillingC2Fixture.resolve(
          compileTimeId: '../beecount',
          runtimeId: '../beecount',
          isDebug: true,
        ),
        throwsFormatException,
      );
    });

    test('runtime id must exactly match the compile-time fixture id', () {
      expect(
        () => ShareBillingC2Fixture.resolve(
          compileTimeId: 'issue6-c2-20260716',
          runtimeId: 'another-fixture',
          isDebug: true,
        ),
        throwsStateError,
      );
    });

    test('main and headless derive the same isolated namespace', () {
      ShareBillingC2Fixture resolveForEngine() => ShareBillingC2Fixture.resolve(
            compileTimeId: 'issue6-c2-20260716',
            runtimeId: 'issue6-c2-20260716',
            isDebug: true,
          )!;

      final main = resolveForEngine();
      final headless = resolveForEngine();

      expect(main, headless);
      expect(
          main.databaseFileName, 'beecount_share_c2_issue6-c2-20260716.sqlite');
      expect(main.attachmentDirectoryName,
          'beecount_share_c2_issue6-c2-20260716_attachments');
      expect(main.fixtureId, 'issue6-c2-20260716');
    });
  });
}
