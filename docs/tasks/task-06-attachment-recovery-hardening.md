# 分享账单附件恢复加固实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让分享账单附件在主进程与 Headless 跨连接并发、租约过期、进程崩溃和坏文件存在时仍能幂等恢复，并且不重跑 OCR、规则或交易创建。

**Architecture:** 使用可空 `origin_key` 的数据库唯一索引表达分享附件身份，普通附件不受影响。附件模块以 `BillingAttachmentIdentity` 统一稳定键，在同目录临时文件中完成压缩和解码校验，再通过跨进程文件锁、lease 复核和原子重命名发布。

**Tech Stack:** Flutter/Dart、Drift/SQLite、`dart:io` 文件锁与原子重命名、现有 Billing Job lease CAS、Flutter Test、Android Gradle 单元测试。

## Global Constraints

- 默认目标平台为 Android，不得改成 Windows/Web 启动。
- 禁止删除、清空或移动任何用户文件；实现不得加入未经用户确认的清理操作。
- 文件压缩、读全文件、解码和缩略图生成不得进入 SQLite 事务。
- 分享附件来源键固定为 `billing:<billingJobId>:<index>`；普通附件 `origin_key` 必须为 `NULL`。
- 只有当前未过期 Billing Job lease owner 可以发布稳定文件和标记 `attachmentDone`。
- 恢复器只恢复附件，不得重跑 OCR、规则、AI 或交易创建。
- 启动时附件目录只枚举一次；每个 job 只做固定扩展名的 `Set.contains`，总复杂度为 `O(F+J)`。
- 真机测试禁止 `flutter test ... -d`、uninstall、`pm clear` 和 `flutter clean`；Patrol 必须使用 `--no-uninstall` 并验证 `run-as` 哨兵。

---

### Task 1: 数据库来源键与跨连接幂等

**Files:**
- Modify: `lib/data/db.dart`
- Modify: `lib/data/repositories/attachment_repository.dart`
- Modify: `lib/data/repositories/local/local_attachment_repository.dart`
- Modify: `lib/data/repositories/local/local_repository.dart`
- Regenerate: `lib/data/db.g.dart`
- Test: `test/data/repositories/attachment_repository_test.dart`
- Test: `test/data/migrations/billing_attachment_origin_key_migration_test.dart`

**Interfaces:**
- Produces: `TransactionAttachments.originKey`，数据库版本 28，非空来源键唯一索引。
- Produces: `Future<int> upsertBillingAttachment({required String originKey, ...})`。
- Preserves: `createAttachment(...)` 始终创建普通附件，不按文件名全局复用。

- [ ] **Step 1: 写跨连接失败测试**

使用同一个临时 SQLite 文件创建两个 `BeeDatabase.forTesting(NativeDatabase(file))` 连接，并发调用：

```dart
final ids = await Future.wait([
  LocalAttachmentRepository(db1).upsertBillingAttachment(
    originKey: 'billing:9:0',
    transactionId: 61,
    fileName: 'tx_61_9_0.avif',
  ),
  LocalAttachmentRepository(db2).upsertBillingAttachment(
    originKey: 'billing:9:0',
    transactionId: 61,
    fileName: 'tx_61_9_0.avif',
  ),
]);
expect(ids.toSet(), hasLength(1));
expect(await repo1.getAttachmentsByTransaction(61), hasLength(1));
```

另写普通附件测试：两次 `createAttachment` 使用同一 `fileName`，必须返回不同 ID 并保留两行。

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/data/repositories/attachment_repository_test.dart`

Expected: FAIL；当前不存在 `upsertBillingAttachment`，且通用 `createAttachment` 会错误复用同名记录。

- [ ] **Step 3: 实现 v28 schema 与迁移**

在 `TransactionAttachments` 增加：

```dart
TextColumn get originKey => text().nullable()();
```

把 `schemaVersion` 改为 28，在 `from < 28` 中增加列并创建部分唯一索引：

```sql
ALTER TABLE transaction_attachments ADD COLUMN origin_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS ux_transaction_attachments_origin_key
ON transaction_attachments(origin_key)
WHERE origin_key IS NOT NULL;
```

新数据库在 `beforeOpen` 或 `onCreate` 后也必须拥有相同索引；用 `PRAGMA index_list` 和 `PRAGMA index_info` 测试证明。

- [ ] **Step 4: 实现专用幂等仓储接口**

恢复 `createAttachment` 为无条件 insert。新增 `upsertBillingAttachment`：先尝试带 `originKey` insert；遇到唯一约束冲突时按 `originKey` 回读同一行，再更新文件名、尺寸和大小等元数据并返回已有 ID。不得用文件名作为幂等键。

```dart
Future<int> upsertBillingAttachment({
  required String originKey,
  required int transactionId,
  required String fileName,
  String? originalName,
  int? fileSize,
  int? width,
  int? height,
  int sortOrder = 0,
});
```

- [ ] **Step 5: 生成 Drift 代码并跑 GREEN**

Run: `dart run build_runner build`

Run: `flutter test test/data/repositories/attachment_repository_test.dart test/data/migrations/billing_attachment_origin_key_migration_test.dart`

Expected: PASS；跨连接同来源键一行、普通同名附件两行、v27→v28 数据保留且索引存在。

- [ ] **Step 6: 提交 Task 1**

```powershell
git add lib/data/db.dart lib/data/db.g.dart lib/data/repositories/attachment_repository.dart lib/data/repositories/local/local_attachment_repository.dart lib/data/repositories/local/local_repository.dart test/data/repositories/attachment_repository_test.dart test/data/migrations/billing_attachment_origin_key_migration_test.dart
git commit -m "fix: persist billing attachment identity (#6)"
```

### Task 2: 稳定身份、文件验证与线性恢复索引

**Files:**
- Create: `lib/services/billing/billing_attachment_identity.dart`
- Modify: `lib/services/attachment_service.dart`
- Modify: `lib/services/billing/billing_job_runner.dart`
- Modify: `lib/services/billing/stages/attachment_stage_processor.dart`
- Test: `test/services/billing/billing_attachment_identity_test.dart`
- Test: `test/services/billing/stages/attachment_stage_processor_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `originKey` 与 `upsertBillingAttachment`。
- Produces: `BillingAttachmentIdentity(transactionId, billingJobId, index)`，以及固定候选文件名查询。
- Produces: 数据库附件命中后仍验证实际文件完整性的恢复行为。

- [ ] **Step 1: 写身份与索引 RED 测试**

```dart
const identity = BillingAttachmentIdentity(
  transactionId: 61,
  billingJobId: 9,
  index: 0,
);
expect(identity.originKey, 'billing:9:0');
expect(identity.baseName, 'tx_61_9_0');
expect(identity.findExisting({'other.jpg', 'tx_61_9_0.webp'}),
    'tx_61_9_0.webp');
```

用计数型 `Set` 或等价测试替身证明每个 identity 最多调用支持扩展名数量次 `contains`，不得迭代整个集合。

- [ ] **Step 2: 运行身份测试并确认 RED**

Run: `flutter test test/services/billing/billing_attachment_identity_test.dart`

Expected: FAIL；类型尚不存在，现有实现会遍历全部文件名。

- [ ] **Step 3: 实现 `BillingAttachmentIdentity`**

```dart
final class BillingAttachmentIdentity {
  final int transactionId;
  final int billingJobId;
  final int index;

  const BillingAttachmentIdentity({
    required this.transactionId,
    required this.billingJobId,
    required this.index,
  });

  String get originKey => 'billing:$billingJobId:$index';
  String get baseName => 'tx_${transactionId}_${billingJobId}_$index';
  Iterable<String> get candidateFileNames =>
      ['.avif', '.webp', '.jpg'].map((extension) => '$baseName$extension');
  String? findExisting(Set<String> names) {
    for (final candidate in candidateFileNames) {
      if (names.contains(candidate)) return candidate;
    }
    return null;
  }
}
```

- [ ] **Step 4: 写数据库记录文件验证 RED 测试**

覆盖三种已有记录：文件缺失、文件为非零垃圾字节、文件完整可解码。前两种必须重建并更新同一 `originKey` 记录，第三种直接复用。任何失败都保持 `attachmentDone=false`。

- [ ] **Step 5: 实现记录验证和坏文件重建**

数据库命中附件后，读取其稳定文件并调用 `decodeCompleteBillingJobAttachmentBytes`。只有文件存在且解码成功才返回已有记录；否则继续从原始分享图片生成，最终原子替换稳定路径并用 Task 1 接口复用同一记录。

恢复索引只在启动批次调用一次 `indexAttachmentFileNames()`，并向所有附件恢复上下文传同一 `Set<String>`；每个 job 通过 `identity.findExisting(set)` 查询。

- [ ] **Step 6: 跑 Task 2 GREEN**

Run: `flutter test test/services/billing/billing_attachment_identity_test.dart test/services/billing/stages/attachment_stage_processor_test.dart`

Expected: PASS；缺失/损坏文件不会被直接标完成，坏稳定文件可由原图重建，索引查询为固定次数。

- [ ] **Step 7: 提交 Task 2**

```powershell
git add lib/services/billing/billing_attachment_identity.dart lib/services/attachment_service.dart lib/services/billing/billing_job_runner.dart lib/services/billing/stages/attachment_stage_processor.dart test/services/billing/billing_attachment_identity_test.dart test/services/billing/stages/attachment_stage_processor_test.dart
git commit -m "fix: validate recovered billing attachments (#6)"
```

### Task 3: 跨进程文件锁与 lease-fenced 原子发布

**Files:**
- Create: `lib/services/billing/billing_attachment_publisher.dart`
- Modify: `lib/services/attachment_service.dart`
- Modify: `lib/services/billing/stages/attachment_stage_processor.dart`
- Test: `test/services/billing/billing_attachment_publisher_test.dart`
- Test: `test/services/billing/billing_job_service_process_test.dart`

**Interfaces:**
- Consumes: Task 1 的专用仓储接口，Task 2 的 `BillingAttachmentIdentity`，现有 `BillingJobLease` 和 `BillingJobRepository.isLeaseOwner`。
- Produces: 一个深模块 `BillingAttachmentPublisher.publish(...)`，隐藏临时文件、真实解码、文件锁、lease 复核、原子重命名和幂等落库。

- [ ] **Step 1: 写过期 owner 并发发布 RED 测试**

构造两个 publisher 指向同一目录和来源键。旧 owner 先完成压缩但在获取锁后被 `isLeaseOwner` 拒绝；新 owner 发布成功。断言稳定文件来自新 owner、数据库只有一行、旧 owner 不写库且不能标记完成。

```dart
expect(await oldPublish, isA<BillingAttachmentPublishLeaseLost>());
expect(await newPublish, isA<BillingAttachmentPublished>());
expect(await repo.findByOriginKey('billing:9:0'), isNotNull);
expect(await repo.countByOriginKey('billing:9:0'), 1);
```

- [ ] **Step 2: 运行并确认 RED**

Run: `flutter test test/services/billing/billing_attachment_publisher_test.dart`

Expected: FAIL；现有保存流程未使用传入 lease，也没有跨进程锁或独立发布模块。

- [ ] **Step 3: 实现发布模块**

`BillingAttachmentPublisher.publish` 接受已压缩临时文件、稳定目标、附件元数据、lease owner 校验回调和专用落库回调。临时文件必须与目标位于同一目录。

```dart
Future<TransactionAttachment> publish({
  required BillingAttachmentIdentity identity,
  required File preparedFile,
  required String finalFileName,
  required BillingJobLease lease,
  required Future<bool> Function(BillingJobLease) isLeaseOwner,
  required Future<int> Function(String originKey, File publishedFile)
      createOrGet,
});
```

打开 `${identity.baseName}.publish.lock` 后调用 `RandomAccessFile.lock(FileLock.exclusive)`。在持锁状态重新调用 `isLeaseOwner(lease)`；失败时返回 lease-lost，不执行 rename 或数据库写入。

lease 有效时再次完整解码 `preparedFile`，然后用同目录 `File.rename(finalPath)` 原子发布。若稳定文件已存在，先验证；有效则复用，无效则由平台原子替换，不执行显式删除。

发布完成后调用 `upsert(identity.originKey, finalFile)`。数据库冲突必须按来源键回读并更新同一行元数据。释放文件锁后才允许 StageProcessor 使用同一 lease CAS 标记 `attachmentDone`。

- [ ] **Step 4: 写崩溃窗口恢复测试**

覆盖：原子重命名后、数据库 insert 前抛错。下一次恢复必须收养完整稳定文件并补写唯一记录，不执行 OCR、规则、AI 或交易创建。

- [ ] **Step 5: 接入 AttachmentStageProcessor**

删除“传入 lease 但不使用”的浅接口。保存阶段必须把 `BillingJobRepository.isLeaseOwner` 交给 publisher；publisher 成功返回有效附件后，StageProcessor 才调用 `markAttachmentDone` CAS。

- [ ] **Step 6: 跑 Task 3 GREEN 与回归**

Run: `flutter test test/services/billing/billing_attachment_publisher_test.dart test/services/billing/billing_job_service_process_test.dart test/services/billing/stages/attachment_stage_processor_test.dart`

Expected: PASS；旧 owner 无法发布，崩溃窗口可恢复，附件恢复不重复主链副作用。

Run: `flutter test`

Expected: 全量 PASS。

Run: `dart analyze lib/data/db.dart lib/data/repositories lib/services/attachment_service.dart lib/services/billing test/data test/services/billing`

Expected: `No issues found!`

Run: `powershell -NoProfile -Command "$env:ANDROID_HOME='D:\app\Android\sdk'; Set-Location android; .\gradlew.bat testDevDebugUnitTest"`

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 7: 提交 Task 3**

```powershell
git add lib/services/billing/billing_attachment_publisher.dart lib/services/attachment_service.dart lib/services/billing/stages/attachment_stage_processor.dart test/services/billing/billing_attachment_publisher_test.dart test/services/billing/billing_job_service_process_test.dart test/services/billing/stages/attachment_stage_processor_test.dart
git commit -m "fix: fence billing attachment publication (#6)"
```

### Task 4: 双审与安全真机 C2

**Files:**
- Modify or Create: `patrol_test/share_billing_confirmation_lifecycle_test.dart`
- Modify: `patrol_test/test_bundle.dart`
- Evidence: GitHub Issue #6 comment

**Interfaces:**
- Consumes: Tasks 1–3 的完整附件恢复实现。
- Produces: Issue #6 的 Standards/Spec 双审通过，以及 Android 分享入口独立验证证据。

- [ ] **Step 1: 两轴代码审查**

Standards 轴重点复核跨连接唯一性、文件锁、lease fencing、坏文件重建、SQLite 临界区和 `O(F+J)`。Spec 轴复核可靠账单快速创建、不可靠账单待确认、仅本次不记规则、记住类似进入生命周期且附件上下文可用。

- [ ] **Step 2: 准备隔离真机 fixture**

Patrol fixture 必须使用独立测试数据库/账本和 fixture ID，不读取或修改用户现有账单。运行前读取既有 `run-as` 哨兵并记录原值。

- [ ] **Step 3: 安全运行 Patrol**

Run:

```powershell
$env:PATH="D:\app\Android\sdk\platform-tools;"+$env:PATH
C:\Users\example\AppData\Local\Pub\Cache\bin\patrol.bat test --no-uninstall --target patrol_test/share_billing_confirmation_lifecycle_test.dart -d DEVICE_SERIAL --flavor dev --no-generate-bundle
```

Expected: 可靠图片恰好创建一条交易；不可靠图片打开正确待确认页；仅本次不生成个人规则；记住类似显示启用结果；下一张相似图片应用该规则。

- [ ] **Step 4: 恢复生产入口并复核哨兵**

```powershell
flutter build apk --debug --flavor dev -t lib/main.dart
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL install -r build\app\outputs\flutter-apk\app-dev-debug.apk
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL shell am start -n com.tntlikely.beecount.dev.debug/com.tntlikely.beecount.MainActivity
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL shell "run-as com.tntlikely.beecount.dev.debug cat files/codex_data_sentinel"
```

Expected: `adb install -r` 返回 `Success`，主入口启动，哨兵与测试前完全一致。

- [ ] **Step 5: 评论并关闭 Issue #6**

GitHub 评论必须列出 commit、定向/全量/Android 测试结果、双审结论、设备序列号、Patrol 命令、前后哨兵值和生产入口恢复结果。证据齐全后关闭 #6。
