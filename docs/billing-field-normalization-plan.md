# 图片记账字段归一化统一方案

## 1. 背景

当前图片记账中的字段归一化逻辑分散在规则 parser、`BillRecognitionNormalizer`、页面比较工具和个人规则合成流程中。不同路径可能对同一个 OCR 字段产生不同结果。

例如云闪付账单中的卡号为：

```text
中国银行银联信用卡[2853]
```

用户期望的支付方式为：

```text
中国银行信用卡(2853)
```

公共规则可以提取原始文本。当前工作区已经通过 `paymentMethod` parser 和个人规则合成中的局部适配处理这个样本，同时也补齐了支付方式编辑到学习服务的传递链；但业务归一化仍分散在 parser、`BillRecognitionNormalizer` 和页面工具中，尚未形成统一、版本化的字段语义。

本方案当前只统一 `paymentMethod`。支付渠道、商户、机构和分类不在本次范围内，后续如需统一应单独设计。

支付方式语义收口到唯一的 `PaymentMethodSemantics` 模块。规则引擎必须调用该模块，但规则引擎不是唯一入口：账单创建、用户编辑、历史兼容、导入和同步路径也必须委托同一模块。公共规则、个人规则、用户修改比较、回归样本和规则升级评测统一使用同一个 canonical value。

## 2. 目标

建立以下统一数据流：

```text
图片
  ↓
OCR
  ↓
通用 OCR 文本清洗
  ↓
规则匹配与字段提取
  ↓
字段解析
  ↓
支付方式 canonical 化
  ↓
BillingRuleResult
  ├─ 创建账单
  ├─ 待确认页面
  ├─ 个人规则合成
  ├─ 用户修改比较
  ├─ 回归样本
  └─ 规则升级评测
```

需要满足以下不变量：

> 任何进入 `BillingRuleResult.paymentMethod` 的值都已经由 `PaymentMethodSemantics.canonicalize()` 处理。

canonical value 同时作为支付方式的等价比较值。原始 OCR 和原始字段值只用于证据、审计和排障，不再作为下游业务判断的权威值。详情页和持久化数据使用完整 canonical value；只有主页列表可以使用简化展示值。

## 3. 职责划分

### 3.1 通用 OCR 文本清洗

只处理不改变业务语义的文本问题，例如：

- 换行格式；
- 不可见字符；
- 多余空白；
- 全角和半角空格。

通用文本清洗不能全局删除“银联”等业务词汇，否则可能破坏“银联交易详情”等模板关键词。

### 3.2 字段提取器

只负责从 OCR 文本中定位原始字段，例如：

- `labelNextLine("卡号")`；
- `labelNextLine("支付方式")`；
- 金额和日期正则；
- 标签区间提取。

提取器不负责最终展示格式或业务别名处理。

### 3.3 parser

负责类型解析和提取结果解析，例如：

- 金额字符串转为 `double`；
- 日期字符串转为 `DateTime`；
- 正则捕获组解析；
- 清除提取器固有的尾部符号。

`paymentMethod` parser 保留以兼容现有 TOML 和个人规则，但只负责确认输入是可解析的单行字符串并清理 extractor 固有的首尾空白。它不删除“银联”、不转换括号、不处理银行简称，也不生成主页展示格式。

### 3.4 支付方式语义模块

负责支付方式 canonical value 和主页展示格式：

- canonical 化支付方式格式；
- 以 canonical value 作为修改比较和冲突判断值；
- 仅为主页生成银行简称展示。

### 3.5 下游业务

账单创建、详情展示、个人规则和回归评测只能使用 canonical value，不得自行维护另一套支付方式清洗逻辑。主页列表只能调用 `formatForHome()`，其结果不得写回交易、规则、样本或同步数据。

## 4. 支付方式语义模块

新增一个小接口、深实现的模块：

```dart
class PaymentMethodSemantics {
  const PaymentMethodSemantics();

  NormalizationResult canonicalize(String? value);

  String? formatForHome(String? canonicalValue);
}
```

`NormalizationResult` 必须区分：

- `unchanged`：输入已经是合法 canonical value；
- `normalized`：输入被安全转换为 canonical value；
- `rejected`：输入不是合法支付方式候选；
- 空值：`null` 或空白输入得到 `null` canonical value。

canonical value 同时用于存储、详情展示、规则结果、用户修改比较和个人规则冲突判断，不再暴露另一套 equivalence key。

`formatForHome()` 只接收 canonical value，只允许主页列表调用。修改银行简称、截断长度或主页排版不提升 `normalizationVersion`，也不参与个人规则、黄金 expected、同步冲突或回归样本比较。

## 5. 字段结果模型

字段提取结果需要同时保留 extractor 原始值和 canonical value：

```dart
class BillingFieldResult {
  final String field;
  final Object? rawValue;
  final Object? value;
  final String evidence;
  final String extractorType;
  final double confidence;
}
```

字段含义：

- `rawValue`：extractor 直接提取的文本；
- `value`：经过 parser 和支付方式 canonical 化后的权威业务值；
- `evidence`：OCR 中的原始证据；
- `BillingRuleResult.paymentMethod` 等公开字段始终返回 `value`。

parser 的中间结果不进入稳定业务模型，只写入规则 trace 和离线评测报告。这样可以区分“提取错误、解析错误、canonical 化错误”，又不扩大业务接口。

支付方式示例：

```text
evidence: 中国银行银联信用卡[2853]
rawValue: 中国银行银联信用卡[2853]
value:    中国银行信用卡(2853)
```

## 6. 规则引擎接入

支付方式 canonical 化必须由规则引擎强制执行，调用者不能选择是否执行。

统一顺序为：

```text
extractor
→ parser
→ PaymentMethodSemantics.canonicalize()
→ BillingFieldResult
```

公共 TOML 规则和活动个人规则使用同一个规则执行器，因此自动获得相同的归一化行为。

归一化发生在 extractor 候选参与置信度选择之前。`rejected` 候选不参与选择，规则引擎继续尝试该字段的其他 extractor；全部候选失败时 `paymentMethod` 为空。禁止 canonical 化失败后静默使用原始值。

规则 trace 记录：

```text
extracted → parsed → normalized/rejected → selected/skipped
```

规则引擎是强制调用者，但不是唯一入口。`BillRecognitionNormalizer`、用户编辑保存、导入、同步和历史兼容路径在迁移期间都必须委托 `PaymentMethodSemantics`。

## 7. 支付方式归一化规则

`paymentMethod` 第一阶段应支持：

1. 清理首尾空白和尾部箭头；
2. 统一全角和半角括号；
3. 将 `[3610]`、`【3610】`、`（3610）` 统一为 `(3610)`；
4. 只删除卡名称中位于银行名与卡类型之间的支付网络修饰词“银联”；
5. 合并无意义空白；
6. 保留银行名称、卡类型和尾号。

示例：

| 原始字段 | 归一化结果 |
| --- | --- |
| 中国银行银联信用卡[2853] | 中国银行信用卡(2853) |
| 招商银行 银联 信用卡【7549】 | 招商银行信用卡(7549) |
| 工商银行借记卡（4886） | 工商银行借记卡(4886) |
| 平安银行信用卡(2299)> | 平安银行信用卡(2299) |

权威字段不应把“中国银行”缩写成“中行”，也不应删除卡类型或尾号。短名称属于展示格式化，不属于字段归一化。

canonical 化采用保守校验，不维护支付产品白名单：

- `null` 或空白得到 `null`；
- 包含换行、不可见控制字符、明显只是标签（如“支付方式”“卡号”）或长度异常时返回 `rejected`；
- 其他非空文本按已知格式规则处理；未命中规则时原样返回 `unchanged`；
- “财付通(银联云闪付)”等错误标题由 extractor 证据、优先级和规则回归发现，不由 canonical 化器猜测；
- 不全局删除“银联云闪付”“银联商务”等实体词；
- 不补全 OCR 中不存在的银行、卡类型或尾号。

用户清空支付方式时，canonical value 为 `null`，只修改当前交易，不生成个人提取规则。

主页展示只缩短明确的银行名称，并保留卡类型和尾号：

| canonical value | 主页显示 |
| --- | --- |
| 中国银行信用卡(2853) | 中行信用卡(2853) |
| 中国建设银行借记卡(1234) | 建行借记卡(1234) |
| 平安银行信用卡(2299) | 平安信用卡(1293) |
| 微信零钱 | 微信零钱 |
| 数字人民币-招商银行钱包(0076) | 数字人民币-招行钱包(0076) |

无法识别的银行名称原样展示。详情页始终显示完整 canonical value。

## 8. 现有重复逻辑迁移

当前支付方式相关逻辑分散在：

- `BillingRuleParsers.paymentMethod`
- `BillRecognitionNormalizer`
- `PaymentMethodUtils`
- 页面修改判断
- 个人规则合成

迁移后：

- `BillingRuleParsers.paymentMethod` 保留兼容名称，但只做单行字符串解析；
- `BillRecognitionNormalizer` 的支付方式分支在迁移期委托 `PaymentMethodSemantics`，其他字段职责不变；
- 页面通过 `PaymentMethodSemantics.canonicalize()` 比较初始值和修改值；
- 主页列表直接调用 `formatForHome()`；
- 最终删除 `PaymentMethodUtils`，不保留同名包装层；
- 禁止新增其他支付方式归一化实现。

仓库审计禁止新增独立的支付方式括号转换、“银联”删除、银行简称表或支付方式比较正则。清理完成后使用 `rg` 审计相关关键词，并由测试锁定唯一入口。

## 9. 个人规则合成改造

### 9.1 待收口问题

当前个人规则合成已能借助 `paymentMethod` parser 处理局部 OCR 格式差异，但这会让 parser 同时承担解析和业务 canonical 化职责。迁移后，候选定位、用户确认值比较和候选重放都必须统一使用 `PaymentMethodSemantics`，不能继续依赖 parser 内的特例。

### 9.2 新流程

个人规则合成调整为：

1. 根据字段类型枚举允许的受约束提取方式；
2. 从 OCR 中提取候选原始值；
3. 使用 `PaymentMethodSemantics` 处理候选值；
4. 同样 canonical 化用户确认值；
5. 比较两个 canonical value；
6. 选择最简单且能够复现确认值的候选规则；
7. 使用规则引擎重新执行候选；
8. 确认最终字段值一致后进入个人回归门禁。

当前云闪付图片的处理过程应为：

```text
候选规则：labelNextLine("卡号")
原始提取：中国银行银联信用卡[2853]
归一化：中国银行信用卡(2853)
用户确认：中国银行信用卡(2853)
结果：一致，可以生成候选规则
```

个人规则保存结构化提取方式，不保存本次归一化结果常量。

每条个人提取规则修订保存 `createdNormalizationVersion`：

- 接收设备版本更低时进入 `pendingValidation`，原因是等待兼容版本；
- 版本相同时运行本机回归门禁；
- 接收设备版本更高时用当前版本重新执行本机回归，通过后才能启用；
- 版本不兼容不能显示为规则冲突或普通回归失败。

## 10. 交易编辑学习链路

`ImageBillEditLearningService.remember()` 已完整接收支付方式，统一升级需要保留并验证这条传递链：

```dart
remember(
  context: context,
  amount: ...,
  time: ...,
  paymentMethod: ...,
  categoryId: ...,
  supplementalNote: ...,
)
```

处理规则：

- 初始值和修改值归一化后相同：不提示更新规则；
- 归一化后不同：显示规则更新提示；
- 用户选择“对类似账单记住”：创建 `PersonalRuleCorrection(field: 'paymentMethod')`；
- 合成失败或回归失败：显示对应的明确状态；
- 不能用“分类或备注偏好已记住”等无关文案表示支付方式学习结果。

反馈语义：

| 状态 | 用户反馈 |
| --- | --- |
| 已启用 | 账单已保存，支付方式规则已启用 |
| 无法安全合成 | 账单已保存；当前支付方式仅用于本次 |
| 回归未通过 | 账单已保存；支付方式规则未通过兼容性验证 |
| 等待兼容版本 | 账单已保存；支付方式规则需更新 App 后验证 |
| 个人规则冲突 | 账单已保存；相似支付方式规则存在冲突 |
| 验证材料不可用 | 账单已保存；本机验证材料暂不可用 |

用户选择“仅本次”时不显示规则失败类提示。文案不暴露 OCR、卡号、样本数量或内部异常。

## 11. 公共主规则

云闪付模板建议保留两级支付方式提取：

1. 高置信度：`labelNextLine("卡号")`；
2. 低置信度：银行卡通用正则兜底。

两种提取结果都必须进入 `PaymentMethodSemantics`。

TOML 规则不再负责：

- 删除“银联”；
- 统一括号；
- 银行别名转换；
- 最终展示格式。

这些行为集中在 `PaymentMethodSemantics`，避免每个模板重复实现。

## 12. 规则升级工具

规则升级报告应同时展示原始提取值和归一化值：

```json
{
  "paymentMethod": {
    "raw": "中国银行银联信用卡[2853]",
    "normalized": "中国银行信用卡(2853)",
    "expected": "中国银行信用卡(2853)",
    "evidence": "卡号\n中国银行银联信用卡[2853]"
  }
}
```

验证分为两层：

1. 提取验证：原始 OCR 证据和提取位置是否正确；
2. 业务字段验证：归一化结果是否等于 expected。

正式 expected 中的业务字段统一填写归一化值。候选规则生成只负责定位逻辑，不生成字段归一化规则。

单张图片仍然只能生成候选模板。候选模板必须独立验证并通过现有回归后，才能人工合入主规则。

`rawValue` 和 evidence 需要长期用于个人回归时，直接写入现有加密回归样本的 `sensitiveEvidence`，不新增另一套加密模块、密钥或数据库。普通 `BillingRuleResult.toJson()` 不额外序列化 `rawValue`，避免在 Billing Job 的普通 JSON 中复制明文敏感数据。

`toDebugJson()` 和离线规则升级报告可以显示 raw value；疑似完整卡号、账号等内容默认脱敏，只保留末四位。普通运行日志禁止记录 raw value 或完整 evidence。

## 13. 回归样本、修订与版本

### 13.1 独立版本维度

版本拆分为三个独立维度：

```text
rulePackageVersion       # 发布产物版本，任何重新打包都递增
rulesVersion             # 模板、匹配、extractor 或 parser 配置变化时递增
normalizationVersion     # canonical 语义变化时递增
```

运行时活动快照记录完整组合身份：

```text
package=12
rules=2026.07.22.1
normalization=1
personalRules=revision-37
```

- 只改 canonical 语义：提升 package 和 normalization，不提升 rules；
- 只改 TOML 提取规则：提升 package 和 rules，不提升 normalization；
- 二者同时修改：三个都提升，`changeKind = rule_and_normalization`；
- 只改主页展示：三个都不提升，跟随普通 App 版本发布。

规则包默认与归一化版本精确匹配：

```toml
normalizationVersion = 1
```

只有每个版本都存在评测证据时，才允许显式声明：

```toml
compatibleNormalizationVersions = [1, 2]
```

缺失版本字段的历史规则包按版本 0 处理。App 的活动归一化版本不在兼容列表中时，规则包不得进入激活评测。

### 13.2 样本与 expected 修订分离

重型 OCR 证据只保存一次：

```text
RegressionSample
- sampleId
- encrypted normalizedOcr
- encrypted evidence
- fingerprints
- protection
```

归一化升级只新增较小的 expected 修订：

```text
RegressionExpectedRevision
- revisionId
- sampleId
- normalizationVersion
- encrypted expectedFields
- derivedFromRevisionId
- migrationDecisionId
- state
- createdAt
```

全部复用现有 Android AES-GCM 回归样本存储。`normalizationVersion` 和修订信息加入现有加密载荷及 wire schema；不新增加密系统。

保留策略：

- 保留用户最初确认的原始修订，作为不可变审计锚点；
- 保留当前活动修订；
- 保留上一个活动修订，支持一次快速回滚；
- 保留被活动规则、待验证规则、冲突或未完成迁移引用的修订；
- 更老且不再被引用的中间修订压缩为迁移审计记录，只保留版本、决策、加密摘要、时间和结果；
- 迁移失败或被拒绝的候选只保留审计记录，不成为活动修订；
- 压缩不能影响当前回归、回滚和冲突裁决。

例如活动版本为 v6 时，通常保留完整的 v0、v5、v6；v1～v4 只保留审计记录。仍被引用的旧修订禁止压缩。

### 13.3 区分规则变化和归一化变化

使用固定四象限评测：

| 评测 | 规则 | 归一化 | 说明 |
| --- | --- | --- | --- |
| A | 当前规则 | 当前归一化 | 基线 |
| B | 候选规则 | 当前归一化 | 只测规则变化 |
| C | 当前规则 | 候选归一化 | 只测归一化变化 |
| D | 候选规则 | 候选归一化 | 最终组合及交互影响 |

- A ≠ B、A = C：规则变化；
- A = B、A ≠ C：归一化变化；
- B、C 单独正常但 D 异常：规则与归一化存在交互问题；
- A、B、C、D 相同：行为等价升级。

每次升级声明 `changeKind = rule | normalization | rule_and_normalization`。`rule_and_normalization` 必须执行完整四象限评测。

### 13.4 原子切换与回滚

App 过渡版本同时包含当前归一化器和候选归一化器。候选版本先完成：

1. 四象限评测；
2. 所有可读活动样本的新 expected revision；
3. 公共规则和个人规则回归；
4. 性能与覆盖门禁。

全部准备成功后才原子切换 `activeNormalizationVersion`。切换前运行时始终使用旧版本，不能部分启用。切换后至少保留上一版归一化实现一个发布周期，用于快速回滚。

受保护样本无法解密、迁移失败或回归不通过时阻止切换。普通样本按以下规则处理：

- 本次迁移中新出现的不可读样本阻止切换；
- 迁移前已不可读的普通样本不阻止，但不得删除，且不计入有效覆盖；
- 预先不可读的相关普通样本超过 5%，阻止自动升级；
- 任一结构模板失去最后一条有效样本时，阻止自动升级。

公共黄金中含 `paymentMethod` 的样本、全部可读受保护样本以及全部可读且含 `paymentMethod` 的普通样本必须 100% 通过。没有 `paymentMethod` 的样本仍参加最终组合回归，防止交互退化。

### 13.5 历史交易和 Billing Job

不批量改写历史交易。新识别、新建和用户再次编辑的交易写入当前 canonical value；旧交易保持原值。详情显示当时保存的完整值，主页可以应用当前 `formatForHome()`。

Billing Job 固定规则执行快照：

- `received`、`ocr_done` 且尚未执行规则的任务，恢复时使用最新活动快照；
- 进入 `rule_done` 时记录 rules、normalization 和 personal rules 版本；
- `rule_done` 后重试必须继续使用该快照；
- 旧快照不可用时不得静默改用新版本，应回退到 `ocr_done` 重新执行规则，并记录 `snapshot_migrated`；
- 已展示给用户的待确认草稿不自动重新 canonical 化；
- 新 Billing Job 使用新的活动版本。

## 14. 测试方案

### 14.1 支付方式语义模块测试

覆盖：

- 标准输入；
- OCR 变体；
- 空值和异常输入；
- 不应改变的内容；
- 保守拒绝条件；
- “银联”只在卡名称修饰词位置删除；
- 未知支付方式原样通过；
- 幂等性：

```text
canonicalize(canonicalize(x).value).value == canonicalize(x).value
```

主页 formatter 独立覆盖银行简称、卡类型和尾号保留。详情页测试必须断言完整 canonical value，防止主页简称渗透到业务数据。

### 14.2 规则引擎测试

验证：

- 每个成功提取字段自动经过归一化；
- `rawValue` 和 `evidence` 保持原始内容；
- 公共规则与个人规则结果一致；
- `rejected` 的高置信度候选不会压过低置信度合法候选；
- 无法识别的字段不会被错误改写；
- trace 能区分提取、解析、canonical 化和选择阶段。

### 14.3 当前云闪付图片回归

断言：

```text
matchedTemplate = unionpay...
rawValue = 中国银行银联信用卡[2853]
paymentMethod = 中国银行信用卡(2853)
```

同时断言不会把以下标题提取为支付方式：

```text
财付通(银联云闪付)
```

### 14.4 个人规则闭环测试

覆盖完整路径：

```text
错误识别
→ 用户修改支付方式
→ 选择记住
→ 合成候选规则
→ 归一化比较通过
→ 回归门禁通过
→ 下一张相似图片生效
```

### 14.5 全量验证

至少执行：

- 字段归一化测试；
- 规则引擎测试；
- 个人规则生命周期测试；
- 编辑页学习测试；
- `rule_eval` 全量黄金评测；
- 500 条个人样本性能门禁；
- 静态分析。

### 14.6 版本、迁移与恢复测试

覆盖：

- 规则包默认只与精确 `normalizationVersion` 匹配；
- 显式多版本兼容必须有逐版本评测证据；
- A/B/C/D 四象限能区分规则、归一化和交互变化；
- expected 修订原子切换，失败时旧活动修订保持不变；
- v0 审计锚点、上一版、当前版和被引用版按策略保留；
- 旧中间修订压缩后仍可审计，且不影响当前回归；
- 受保护样本不可读时阻止升级；
- 迁移前已不可读的普通样本按覆盖门槛排除；
- Billing Job 在 `rule_done` 后固定快照；
- 旧快照不可用时显式回退到 `ocr_done` 并记录迁移；
- normalization 切换后可回滚到上一版本。

### 14.7 性能预算

- 500 个支付方式连续 canonicalize：P95 ≤ 25ms；
- 接入 canonical 化后，单次规则评测总耗时相对基线增长不超过 10%；
- 500 次 `formatForHome()`：P95 ≤ 25ms；
- 多轮预热后报告 P50、P95 和 worst；
- 正则和银行简称表使用预编译静态数据；
- 样本修订迁移的加密写入单独计时，不计入完整规则执行的 500ms 预算。

## 15. 实施顺序

1. 新增 `PaymentMethodSemantics`、`NormalizationResult` 和独立契约测试；
2. 让现有 `BillingRuleParsers.paymentMethod`、`BillRecognitionNormalizer` 和页面比较工具委托新模块，同时保持当前生产输出；
3. 增加 shadow 模式：同时计算旧结果和候选 canonical value，只进入本地调试/评测报告，不写普通日志或生产数据库；
4. 增加 package、rules、normalization 三维版本和精确兼容校验；
5. 拆分回归样本 OCR 证据与 expected 修订，升级现有加密 wire schema；
6. 扩展 `BillingRuleFieldResult`，保存 extractor `rawValue`，parser 中间结果进入 trace；
7. 在 extractor 候选选择前接入 `PaymentMethodSemantics`；
8. 更新公共规则评测和黄金 expected，运行四象限评测；
9. 修改个人规则合成，取消“确认值必须原样存在于 OCR”的要求，并保存 `createdNormalizationVersion`；
10. 保留支付方式编辑到 `remember()` 的传递链，并补齐明确反馈状态；
11. 增加当前图片、版本迁移、样本修订、Billing Job 快照的端到端回归；
12. 生成候选 expected 修订并通过覆盖、性能和加密迁移门禁；
13. 原子切换 `activeNormalizationVersion`，保留上一版实现用于回滚；
14. 确认所有调用者完成迁移后删除 `PaymentMethodUtils`，审计并清理重复实现。

## 16. 完成标准

满足以下条件后视为完成：

- 所有权威 `paymentMethod` 都由 `PaymentMethodSemantics` 生成；
- canonical value 同时用于存储、详情、比较和冲突判断；
- 只有主页使用 `formatForHome()`，展示值从不写回业务数据；
- 公共规则和个人规则使用同一条提取、解析和 canonical 化管线；
- 页面与业务模块不存在独立的支付方式清洗、简称或比较规则；
- 个人规则合成不再依赖确认值原样存在于 OCR；
- 原始字段值和证据仍可追溯；
- raw value 长期留存复用现有加密回归样本存储，不进入普通 Billing Job JSON；
- 规则包默认与归一化版本精确匹配；
- rule package、rules、normalization 三个版本可独立追踪；
- 四象限评测能区分规则变化、归一化变化和交互影响；
- expected 修订、活动归一化版本和 Billing Job 快照可以原子切换与回滚；
- 不批量改写历史交易；
- 当前云闪付样本输出“中国银行信用卡(2853)”；
- 全量黄金评测无字段退化和新增误报；
- 支付方式 canonical 化与主页格式化满足独立性能预算；
- 500 条个人回归样本满足既定性能预算。
