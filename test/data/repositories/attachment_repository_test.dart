import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_attachment_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing attachment upsert is idempotent across database connections',
      () async {
    final previousWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarningSetting;
    });
    final databaseFile = File(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}beecount_attachment_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final db1 = BeeDatabase.forTesting(NativeDatabase(databaseFile));
    final db2 = BeeDatabase.forTesting(NativeDatabase(databaseFile));
    final repo1 = LocalAttachmentRepository(db1);
    final repo2 = LocalAttachmentRepository(db2);

    addTearDown(() async {
      await db1.close();
      await db2.close();
    });

    final ids = await Future.wait([
      repo1.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: 'tx_61_9_0.avif',
      ),
      repo2.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: 'tx_61_9_0.avif',
      ),
    ]);

    expect(ids.toSet(), hasLength(1));
    expect(await repo1.getAttachmentsByTransaction(61), hasLength(1));
  });

  test('ordinary attachments with the same file name remain separate rows',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalAttachmentRepository(db);
    addTearDown(db.close);

    final first = await repo.createAttachment(
      transactionId: 61,
      fileName: 'receipt.avif',
    );
    final second = await repo.createAttachment(
      transactionId: 61,
      fileName: 'receipt.avif',
    );

    expect(first, isNot(second));
    expect(await repo.getAttachmentsByTransaction(61), hasLength(2));
  });

  test('billing attachment conflict refreshes metadata on the existing row',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalAttachmentRepository(db);
    addTearDown(db.close);

    final first = await repo.upsertBillingAttachment(
      originKey: 'billing:12:3',
      transactionId: 72,
      fileName: 'pending.avif',
      fileSize: 10,
      width: 20,
      height: 30,
    );
    final second = await repo.upsertBillingAttachment(
      originKey: 'billing:12:3',
      transactionId: 72,
      fileName: 'final.avif',
      originalName: 'source.png',
      fileSize: 100,
      width: 200,
      height: 300,
      sortOrder: 3,
    );

    final attachment = await repo.getAttachmentById(first);
    expect(second, first);
    expect(attachment!.fileName, 'final.avif');
    expect(attachment.originalName, 'source.png');
    expect(attachment.fileSize, 100);
    expect(attachment.width, 200);
    expect(attachment.height, 300);
    expect(attachment.sortOrder, 3);
  });
}
