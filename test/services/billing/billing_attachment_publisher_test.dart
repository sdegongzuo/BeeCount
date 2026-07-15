import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_attachment_repository.dart';
import 'package:beecount/services/billing/billing_attachment_identity.dart';
import 'package:beecount/services/billing/billing_attachment_publisher.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late BeeDatabase db;
  late LocalAttachmentRepository repo;
  late BillingAttachmentPublisher publisher;
  late List<int> firstJpeg;
  late List<int> secondJpeg;

  setUp(() async {
    directory = await Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'beecount_publisher_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalAttachmentRepository(db);
    publisher = const BillingAttachmentPublisher();
    firstJpeg = await File('image/单条/京东-单条.jpg').readAsBytes();
    secondJpeg = await File('image/单条/京东-单条2.jpg').readAsBytes();
  });

  tearDown(() async {
    await db.close();
  });

  test('an expired owner cannot publish or write the database', () async {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );
    final oldLease = BillingJobLease(
      jobId: 9,
      leaseUntil: DateTime(2026, 7, 15, 12),
    );
    final newLease = BillingJobLease(
      jobId: 9,
      leaseUntil: DateTime(2026, 7, 15, 13),
    );
    final oldPrepared = await _prepared(directory, 'old.jpg', firstJpeg);
    final newPrepared = await _prepared(directory, 'new.jpg', secondJpeg);
    var oldUpserts = 0;

    await expectLater(
      publisher.publish(
        identity: identity,
        preparedFile: oldPrepared,
        finalFileName: 'tx_61_9_0.jpg',
        lease: oldLease,
        isLeaseOwner: (lease) async => false,
        createOrGet: (originKey, publishedFile, dimensions) async {
          oldUpserts++;
          return _upsert(repo, identity, publishedFile, dimensions);
        },
      ),
      throwsA(isA<BillingAttachmentPublishLeaseLost>()),
    );

    final published = await publisher.publish(
      identity: identity,
      preparedFile: newPrepared,
      finalFileName: 'tx_61_9_0.jpg',
      lease: newLease,
      isLeaseOwner: (lease) async => true,
      createOrGet: (originKey, publishedFile, dimensions) =>
          _upsert(repo, identity, publishedFile, dimensions),
    );

    final stable = File(
      '${directory.path}${Platform.pathSeparator}tx_61_9_0.jpg',
    );
    expect(oldUpserts, 0);
    expect(await stable.readAsBytes(), secondJpeg);
    expect(published.originKey, identity.originKey);
    expect(await repo.getAttachmentsByTransaction(61), hasLength(1));
  });

  test('a complete stable file is adopted after rename-before-insert crash',
      () async {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );
    final lease = BillingJobLease(
      jobId: 9,
      leaseUntil: DateTime(2026, 7, 15, 13),
    );
    final firstPrepared = await _prepared(directory, 'first.jpg', firstJpeg);

    await expectLater(
      publisher.publish(
        identity: identity,
        preparedFile: firstPrepared,
        finalFileName: 'tx_61_9_0.jpg',
        lease: lease,
        isLeaseOwner: (lease) async => true,
        createOrGet: (originKey, publishedFile, dimensions) async {
          throw StateError('simulated crash after rename');
        },
      ),
      throwsA(isA<StateError>()),
    );

    final stable = File(
      '${directory.path}${Platform.pathSeparator}tx_61_9_0.jpg',
    );
    expect(await stable.readAsBytes(), firstJpeg);
    expect(await repo.getAttachmentsByTransaction(61), isEmpty);

    final secondPrepared = await _prepared(directory, 'second.jpg', secondJpeg);
    final recovered = await publisher.publish(
      identity: identity,
      preparedFile: secondPrepared,
      finalFileName: 'tx_61_9_0.jpg',
      lease: lease,
      isLeaseOwner: (lease) async => true,
      createOrGet: (originKey, publishedFile, dimensions) =>
          _upsert(repo, identity, publishedFile, dimensions),
    );

    expect(recovered.originKey, identity.originKey);
    expect(await stable.readAsBytes(), firstJpeg);
    expect(await repo.getAttachmentsByTransaction(61), hasLength(1));
  });

  test('a corrupt stable file is atomically replaced without copy fallback',
      () async {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );
    final stable = File(
      '${directory.path}${Platform.pathSeparator}tx_61_9_0.jpg',
    );
    await stable.writeAsBytes([1, 2, 3, 4], flush: true);
    final prepared = await _prepared(directory, 'replacement.jpg', firstJpeg);
    final lease = BillingJobLease(
      jobId: 9,
      leaseUntil: DateTime(2026, 7, 15, 13),
    );

    await publisher.publish(
      identity: identity,
      preparedFile: prepared,
      finalFileName: 'tx_61_9_0.jpg',
      lease: lease,
      isLeaseOwner: (lease) async => true,
      createOrGet: (originKey, publishedFile, dimensions) =>
          _upsert(repo, identity, publishedFile, dimensions),
    );

    expect(await stable.readAsBytes(), firstJpeg);
    expect(await prepared.exists(), isFalse);
    expect(await repo.getAttachmentsByTransaction(61), hasLength(1));
  });

  test('publishes and decodes a real WebP payload', () async {
    const identity = BillingAttachmentIdentity(
      transactionId: 62,
      billingJobId: 10,
      index: 0,
    );
    final webp = base64Decode(
      'UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAgA0JaQAA3AA/vuUAAA=',
    );
    final prepared = await _prepared(directory, 'prepared.webp', webp);
    final lease = BillingJobLease(
      jobId: 10,
      leaseUntil: DateTime(2026, 7, 15, 13),
    );

    final published = await publisher.publish(
      identity: identity,
      preparedFile: prepared,
      finalFileName: 'tx_62_10_0.webp',
      lease: lease,
      isLeaseOwner: (lease) async => true,
      createOrGet: (originKey, publishedFile, dimensions) =>
          _upsert(repo, identity, publishedFile, dimensions),
    );

    expect(published.width, 1);
    expect(published.height, 1);
    expect(published.fileName, 'tx_62_10_0.webp');
  });
}

Future<File> _prepared(
  Directory directory,
  String name,
  List<int> bytes,
) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<TransactionAttachment> _upsert(
  LocalAttachmentRepository repo,
  BillingAttachmentIdentity identity,
  File file,
  ({int width, int height}) dimensions,
) async {
  final id = await repo.upsertBillingAttachment(
    originKey: identity.originKey,
    transactionId: identity.transactionId,
    fileName: file.uri.pathSegments.last,
    fileSize: await file.length(),
    width: dimensions.width,
    height: dimensions.height,
    sortOrder: identity.index,
  );
  return (await repo.getAttachmentById(id))!;
}
