import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_attachment_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_attachment_identity.dart';
import 'package:beecount/services/billing/billing_attachment_publisher.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'two database connections fence an expired owner before rename and upsert',
      () async {
    final fixture = await _PublicationFixture.create();
    addTearDown(fixture.close);
    final job =
        await fixture.jobs1.createJob(imagePath: fixture.firstJpeg.path);
    final stale = (await fixture.jobs1.claimJobLease(
      job.id,
      const Duration(seconds: -1),
    ))!;
    final current = (await fixture.jobs2.claimJobLease(
      job.id,
      const Duration(minutes: 1),
    ))!;
    final identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: job.id,
      index: 0,
    );
    final stalePrepared =
        await fixture.prepared('stale.jpg', fixture.firstJpeg);
    final currentPrepared =
        await fixture.prepared('current.jpg', fixture.secondJpeg);

    final results = await Future.wait<Object?>([
      fixture
          .publish(
            jobs: fixture.jobs1,
            attachments: fixture.attachments1,
            identity: identity,
            lease: stale,
            prepared: stalePrepared,
          )
          .then<Object?>((value) => value, onError: (Object error) => error),
      fixture.publish(
        jobs: fixture.jobs2,
        attachments: fixture.attachments2,
        identity: identity,
        lease: current,
        prepared: currentPrepared,
      ),
    ]);

    expect(results.first, isA<BillingAttachmentPublishLeaseLost>());
    expect(await stalePrepared.exists(), isTrue);
    expect(await currentPrepared.exists(), isFalse);
    expect(await fixture.stable(identity).readAsBytes(),
        await fixture.secondJpeg.readAsBytes());
    expect(await fixture.attachments1.getAttachmentsByTransaction(61),
        hasLength(1));
  });

  test('two database connections serialize same-token publication actions',
      () async {
    final fixture = await _PublicationFixture.create();
    addTearDown(fixture.close);
    final job =
        await fixture.jobs1.createJob(imagePath: fixture.firstJpeg.path);
    final lease = (await fixture.jobs1.claimJobLease(
      job.id,
      const Duration(minutes: 1),
    ))!;
    final identity = BillingAttachmentIdentity(
      transactionId: 62,
      billingJobId: job.id,
      index: 0,
    );
    final first = await fixture.prepared('first.jpg', fixture.firstJpeg);
    final second = await fixture.prepared('second.jpg', fixture.secondJpeg);
    final events = <String>[];

    await Future.wait([
      fixture.publish(
        jobs: fixture.jobs1,
        attachments: fixture.attachments1,
        identity: identity,
        lease: lease,
        prepared: first,
        label: 'first',
        events: events,
      ),
      fixture.publish(
        jobs: fixture.jobs2,
        attachments: fixture.attachments2,
        identity: identity,
        lease: lease,
        prepared: second,
        label: 'second',
        events: events,
      ),
    ]);

    expect(
      events,
      anyOf(
        equals(['enter:first', 'exit:first', 'enter:second', 'exit:second']),
        equals(['enter:second', 'exit:second', 'enter:first', 'exit:first']),
      ),
    );
    expect(await fixture.attachments1.getAttachmentsByTransaction(62),
        hasLength(1));
    expect(
      await decodeCompleteBillingJobAttachmentBytes(
        await fixture.stable(identity).readAsBytes(),
        extension: '.jpg',
      ),
      isNotNull,
    );
  });
}

final class _PublicationFixture {
  final Directory directory;
  final BeeDatabase db1;
  final BeeDatabase db2;
  final LocalBillingJobRepository jobs1;
  final LocalBillingJobRepository jobs2;
  final LocalAttachmentRepository attachments1;
  final LocalAttachmentRepository attachments2;
  final File firstJpeg;
  final File secondJpeg;

  _PublicationFixture._({
    required this.directory,
    required this.db1,
    required this.db2,
    required this.jobs1,
    required this.jobs2,
    required this.attachments1,
    required this.attachments2,
    required this.firstJpeg,
    required this.secondJpeg,
  });

  static Future<_PublicationFixture> create() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final directory = await Directory.systemTemp.createTemp(
      'beecount_publication_gate_',
    );
    final databaseFile = File(
      '${directory.path}${Platform.pathSeparator}beecount.sqlite',
    );
    final db1 = BeeDatabase.forTesting(
      NativeDatabase.createInBackground(
        databaseFile,
        setup: configureBeeDatabaseConnection,
      ),
    );
    final db2 = BeeDatabase.forTesting(
      NativeDatabase.createInBackground(
        databaseFile,
        setup: configureBeeDatabaseConnection,
      ),
    );
    await db1.customSelect('SELECT 1').get();
    await db2.customSelect('SELECT 1').get();
    return _PublicationFixture._(
      directory: directory,
      db1: db1,
      db2: db2,
      jobs1: LocalBillingJobRepository(db1),
      jobs2: LocalBillingJobRepository(db2),
      attachments1: LocalAttachmentRepository(db1),
      attachments2: LocalAttachmentRepository(db2),
      firstJpeg: File('image/单条/京东-单条.jpg'),
      secondJpeg: File('image/单条/京东-单条2.jpg'),
    );
  }

  Future<File> prepared(String name, File source) async {
    final prepared = File('${directory.path}${Platform.pathSeparator}$name');
    await prepared.writeAsBytes(await source.readAsBytes(), flush: true);
    return prepared;
  }

  File stable(BillingAttachmentIdentity identity) => File(
        '${directory.path}${Platform.pathSeparator}'
        '${identity.baseName}.jpg',
      );

  Future<TransactionAttachment> publish({
    required LocalBillingJobRepository jobs,
    required LocalAttachmentRepository attachments,
    required BillingAttachmentIdentity identity,
    required BillingJobLease lease,
    required File prepared,
    String? label,
    List<String>? events,
  }) {
    return const BillingAttachmentPublisher().publish(
      identity: identity,
      preparedFile: prepared,
      finalFileName: '${identity.baseName}.jpg',
      lease: lease,
      runFencedPublication: jobs.runFencedPublication,
      createOrGet: (originKey, publishedFile, metadata) async {
        if (label != null) events!.add('enter:$label');
        if (label != null) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        final id = await attachments.upsertBillingAttachment(
          originKey: originKey,
          transactionId: identity.transactionId,
          fileName: publishedFile.uri.pathSegments.last,
          fileSize: metadata.fileSize,
          width: metadata.dimensions.width,
          height: metadata.dimensions.height,
          sortOrder: identity.index,
        );
        if (label != null) events!.add('exit:$label');
        return (await attachments.getAttachmentById(id))!;
      },
    );
  }

  Future<void> close() async {
    await db1.close();
    await db2.close();
  }
}
