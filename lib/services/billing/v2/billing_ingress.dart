import '../../../data/models/billing_case.dart';
import '../../../data/repositories/billing_case_repository.dart';

/// 一次分享图片记账的入口信封。
///
/// [requestId] 是稳定身份：原生 Ingress Inbox 在复制图片后生成，重复交付
/// 必须命中同一个。文件名不包含商户、金额或来源信息（规格 §8）。
/// [sourceImagePath] 是已复制到应用私有目录的图片绝对路径。
class SharedImageEnvelope {
  final String requestId;
  final String sourceImagePath;
  final int? ledgerId;
  final String? sourceInfoJson;

  const SharedImageEnvelope({
    required this.requestId,
    required this.sourceImagePath,
    this.ledgerId,
    this.sourceInfoJson,
  });

  @override
  String toString() =>
      'SharedImageEnvelope(requestId=$requestId, path=$sourceImagePath)';
}

/// BillingIngress.accept 的结果。
///
/// [caseId] 是命中的 Billing Case id。[created] 区分是本次新建还是命中既有
/// Case（重复交付或 ack 前崩溃后重新交付）。调用方据此决定是否立即
/// acknowledge 原生 Inbox：只有 created 或确认已存在后才 ack。
class BillingIngressAcceptResult {
  final int caseId;
  final bool created;

  const BillingIngressAcceptResult({required this.caseId, required this.created});

  @override
  String toString() => 'BillingIngressAcceptResult(caseId=$caseId, created=$created)';
}

/// 抽象的原生 Inbox acknowledge 回调。
///
/// 实现负责在 SQLite 提交成功后通知原生层释放 delivery lease。规格 §8：
/// ack 前崩溃允许重复交付，request_id UNIQUE 保证只创建一个 Case。
typedef NativeInboxAcknowledger = Future<void> Function(String requestId);

/// 顶层工作流 BillingIngress 的 Interface（规格 §7.1）。
///
/// 接收 [SharedImageEnvelope] 并返回 BillingCaseId。内部隐藏 requestId 去重、
/// Case 创建、初始 OCR/图片转换/Outbox 任务创建和原生 acknowledge 顺序。
/// 主 Flutter Engine 与 Headless 入口调用同一个 Interface。
abstract class BillingIngress {
  Future<BillingIngressAcceptResult> accept(SharedImageEnvelope envelope);
}

/// BillingIngress 的默认实现。
///
/// 在单个短 SQLite 事务内 get-or-create Billing Case 并创建初始任务
/// （recognize_image、prepare_attachment）与初始 Outbox 事件
/// （billing_processing）。事务提交后才 acknowledge 原生 Inbox，保证 ack 前崩溃
/// 不会丢失工作。重复 requestId 返回同一个 Case 且不重复创建任务。
class LocalBillingIngress implements BillingIngress {
  final BillingCaseRepository _repository;
  final NativeInboxAcknowledger? _acknowledge;

  LocalBillingIngress(this._repository, {NativeInboxAcknowledger? acknowledge})
      : _acknowledge = acknowledge;

  @override
  Future<BillingIngressAcceptResult> accept(SharedImageEnvelope envelope) async {
    var created = false;
    final caseRow = await _repository.getOrCreateCaseByRequestId(
      requestId: envelope.requestId,
      sourceImagePath: envelope.sourceImagePath,
      ledgerId: envelope.ledgerId,
      sourceInfoJson: envelope.sourceInfoJson,
      onCreate: (caseId) async {
        // 初始任务：OCR 识别线与图片附件线在 Ingress 后立即分叉并行（规格 §5）。
        await _repository.insertAutomationTaskIfAbsent(
          caseId: caseId,
          kind: BillingAutomationKind.recognizeImage,
        );
        await _repository.insertAutomationTaskIfAbsent(
          caseId: caseId,
          kind: BillingAutomationKind.prepareAttachment,
        );
        // 初始 Outbox：通知前端正在处理。
        await _repository.insertOutboxEvent(
          caseId: caseId,
          eventType: BillingOutboxEventType.billingProcessing,
        );
        created = true;
      },
    );

    // 只有 SQLite 提交成功后才 acknowledge 原生 Inbox。ack 前崩溃允许重复交付，
    // request_id UNIQUE 保证只创建一个 Case（规格 §8）。
    if (_acknowledge != null) {
      await _acknowledge!(envelope.requestId);
    }

    return BillingIngressAcceptResult(caseId: caseRow.id, created: created);
  }
}
