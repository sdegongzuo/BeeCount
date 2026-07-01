# 任务 01：OCR 前图片预处理

## 目标

添加 OCR 输入预处理能力，在 OCR 前裁切或遮罩顶部系统状态栏区域，同时保留支付页面标题、支付状态、商户和金额内容。

## 依赖

- 依赖：`docs/tasks/task-00-contracts.md`

## 主要文件

- Create: `lib/services/billing/ocr_image_preprocessor.dart`
- Test: `test/services/billing/ocr_image_preprocessor_test.dart`
- Read only during this task: `lib/services/billing/ocr_service.dart`

## 范围

本任务只把预处理实现成独立服务，不接入 `OcrService`。接入工作放到 Task 05。

## 状态栏定位策略

优先实现“顶部轻量 OCR 行框定位 + 遮罩”的方案：

1. 仅对图片顶部安全区域做一次轻量识别，建议限制在原图高度的 6%-8% 内，并设置最大耗时预算。
2. 从顶部 OCR 行结果中筛选状态栏候选行，候选特征包括：
   - 位置非常靠近图片顶部；
   - 行高小于支付页标题、商户名和主金额字号；
   - 文本包含时间、电量、网络制式、运营商、信号等系统状态栏特征；
   - 文本不包含 `交易详情`、`账单详情`、`支付成功`、商户名、金额等业务内容。
3. 命中候选行时，以该行 bounding box 加少量 padding 生成遮罩区域，遮罩范围必须限制在顶部安全区域内。
4. 不默认删除 OCR 第一行文本；应先用顶部 OCR 行框定位，再对原图遮罩，最后交给正式 OCR。
5. 若顶部轻量 OCR 不可用、超时、没有返回行框，或候选不可信，则降级为图片尺寸和安全比例估算的顶部遮罩。
6. 不确定边界时优先遮罩，不优先裁切，避免改变账单主体布局或误裁支付页面标题。

耗时要求：

- 顶部轻量 OCR 只允许用于定位状态栏，不能替代正式 OCR。
- 预处理耗时应记录到 `OcrPreprocessResult.metadata`。
- 如果顶部轻量 OCR 超过预算，应立即降级，不能拖慢快速记账主链路。

## 步骤

1. 添加带状态栏的长截图测试，验证输出遮罩排除了顶部状态栏。
2. 添加无明显状态栏图片测试，验证预处理保留原始内容边界。
3. 添加顶部 OCR 行框命中测试，验证候选状态栏行会生成带 padding 的 `maskedRegions`。
4. 添加顶部 OCR 超时或无行框测试，验证会降级到图片尺寸和安全比例估算遮罩。
5. 基于顶部轻量 OCR 行框、图片尺寸和安全比例默认值实现 `OcrImagePreprocessor`。
6. 返回包含原图尺寸、输出尺寸、处理方式、裁切或遮罩矩形的 `OcrPreprocessResult`。
7. 确保预处理不会覆盖原始输入文件。
8. 运行 `flutter test test/services/billing/ocr_image_preprocessor_test.dart`。
9. 运行 `flutter analyze`。

## 完成标准

- 预处理结果记录足够写入 `BillingRuleTrace` 的元数据。
- 状态栏噪声在 OCR 前被移除或遮罩。
- 实现不能依赖单一硬编码像素高度。
- 顶部轻量 OCR 失败、超时或无法提供行框时，仍可用尺寸估算遮罩完成预处理。
- Trace 元数据能说明状态栏定位来源、候选行文本、候选行框、padding、降级原因和预处理耗时。

## 并行说明

Task 00 完成后，可与 Task 02、Task 03、Task 04 并行执行。
