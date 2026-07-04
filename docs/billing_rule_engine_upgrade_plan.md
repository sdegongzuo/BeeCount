# 自动记账规则引擎升级方案

## 背景

当前截图自动记账主要依赖 OCR、代码内硬编码提取逻辑，以及同步 AI 增强。最近日志显示，OCR 和规则提取本身耗时较低，但 AI 增强会占用绝大多数总耗时。

示例耗时：

```text
OCR 文本识别：1340ms
规则提取：86ms
AI 增强：17099ms
总耗时：18526ms
```

目标架构：

```text
规则快速识别
+ AI 后台补全
+ 可版本化、可更新的规则包
+ 可追踪、可测试、可回滚的规则执行体系
```

## 目标

1. 将高置信截图的自动记账感知耗时从约 18 秒降低到 1-3 秒。
2. 微信支付、支付宝等常见账单详情页优先走确定性规则。
3. 支付 App 映射、账单模板、字段提取规则不再长期硬编码在业务代码中。
4. AI 主要用于后台补全、规则质量评估和规则优化建议。
5. 支持内置规则优先，后续扩展远程更新和本地覆盖。

## 非目标

1. 不执行任意远程代码或 AI 生成脚本。
2. 不允许 AI 生成的规则未经验证直接上线。
3. 当规则结果已经高置信时，不让基础自动记账阻塞在 AI 上。
4. 不替代 OCR 引擎，但会增加 OCR 前图片预处理，本方案从预处理后的 OCR 文本可用之后开始设计规则引擎。

## 目标流程

当前流程：

```text
截图
-> OCR
-> 规则提取
-> AI 增强
-> 合并结果
-> 创建交易
-> 保存附件
-> 通知成功
```

目标流程：

```text
图片输入（分享截图 / 手动图片 / 自动截图监听）
-> OCR 前图片预处理
-> OCR
-> 规则提取
-> 置信度判断
   -> 高置信：立即创建交易
   -> 低置信：创建待确认记录或通知用户手动确认
-> AI 后台补全
-> 安全合并 AI 字段
-> 更新交易
-> 通知补全结果
```

## Android 分享记账主流程

Android 默认推荐流程从“用户显式分享截图到 BeeCount”开始，而不是长期依赖后台截图监听。

```text
用户截图
-> 系统分享面板选择 BeeCount 快速记账
-> 轻量分享接收 Activity 提取图片 URI
-> 从原始 content URI 尽量读取 MediaStore DATE_ADDED / DATE_TAKEN / EXIF 时间
-> 立即复制图片到 App 私有 cache
-> 用截图生成时间窗口调用 UsageStats 推断来源 App
   -> 有权限且命中：作为来源支付通道候选
   -> 无权限、时间不可用或距离当前过久：降低置信度或跳过
-> 启动短时前台服务并显示“正在识别账单”通知
-> 精准裁切或屏蔽头部状态栏区域
-> OCR + TOML 规则引擎 + 视觉兜底
-> 高置信：创建交易并更新通知
-> 低置信：创建待确认记录或通知用户手动确认
-> 停止前台服务
-> AI 后台补全独立执行并另发补全通知
```

设计约束：

1. 分享记账使用短时前台服务通知，不使用常驻通知。
2. 前台服务只覆盖本次 URI 读取、图片缓存、OCR、规则提取和基础交易创建。
3. 服务启动后应尽快 `startForeground`，通知用户当前正在处理账单。
4. 成功后将通知更新为“已自动记账”，随后停止服务。
5. 失败后将通知更新为“识别失败，可点开处理”，随后停止服务。
6. UsageStats 只能围绕截图生成时间查询，不能用分享发生时间推断来源 App。
7. 复制到 cache 后生成的文件时间不得用于 UsageStats 推断。
8. AI 补全不能阻塞前台服务停止；补全结果通过后续通知或交易更新体现。
9. “分享后删除原截图”属于系统或 ROM 行为，不能作为 BeeCount 流程成功条件。
10. 长期截图监听如果保留，应作为高级功能，并用独立常驻通知明确告知用户。
11. OCR 前必须裁切或屏蔽头部状态栏区域，避免电量、时间、通知图标等无关文本干扰金额、时间和商户提取。

OCR 前图片预处理要求：

```text
输入原图
-> 识别截图尺寸、像素密度和可能的状态栏高度
-> 裁切或遮罩顶部状态栏区域
-> 保留支付 App 页面标题和账单主体
-> 输出预处理图片给 OCR
```

预处理约束：

1. 状态栏裁切高度应基于图片尺寸、设备状态栏高度或安全比例计算，不能写死单一像素值。
2. 裁切只移除系统状态栏，不应裁掉支付页面标题、支付状态、商户名或主金额。
3. 如果无法可靠判断状态栏边界，应优先使用遮罩状态栏区域，避免破坏账单主体布局。
4. Trace 中必须记录预处理方式、裁切区域、原图尺寸和输出图尺寸。
5. 规则评测样本应覆盖带状态栏和无状态栏两类截图。

低置信处理策略：

```text
金额缺失 -> 不创建交易，通知用户手动确认
金额存在但关键字段缺失 -> 创建待确认记录或通知进入确认页
金额、支付通道、时间等关键字段高置信 -> 立即创建正式交易
AI 只做补全和冲突记录，不阻塞基础成功通知
```

## 阶段一：规则 Trace 和快速记账链路

### 任务

1. 新增 `BillingRuleTrace` 模型。

   记录内容包括：

   - 来源包名
   - 来源支付通道
   - OCR 文本
   - OCR 前预处理方式和裁切区域
   - 命中的规则 ID
   - 字段提取证据
   - 字段置信度
   - 提取策略
   - 最终规则结果

2. 拆分 `OcrService` 输出。

   输出应拆为：

   - OCR 前预处理结果
   - OCR 原始文本
   - 规则提取结果
   - 规则 Trace
   - 可选 AI 增强结果

3. 修改 `AutoBillingService`，允许规则结果先于 AI 创建交易。

4. 增加快速记账判定。

建议条件：

```dart
final canCreateFast = result.amount != null &&
    result.amount!.abs() > 0 &&
    result.time != null &&
    (result.paymentChannel != null || sourceInfo?.hasPaymentChannel == true);
```

稍宽松版本：

```dart
final canCreateFast = result.amount != null &&
    result.amount!.abs() > 0 &&
    (result.paymentChannel != null || sourceInfo?.hasPaymentChannel == true);
```

5. 增加关键日志。

   日志应包括：

   - OCR 前预处理方式和裁切区域
   - 规则提取结果
   - 规则置信度
   - 快速记账通过或拒绝原因
   - AI 补全状态

### 验收标准

1. 微信支付详情截图在 OCR 成功时，能在 1-3 秒内创建交易。
2. AI 超时或失败不影响基础交易创建。
3. 日志能说明为什么走快速记账或为什么拒绝快速记账。
4. 规则 Trace 能解释每个字段来自哪里。

## 阶段二：规则包配置化

### 规则包位置

第一版内置规则：

```text
assets/rules/billing_rules.toml
```

未来本地缓存或覆盖规则：

```text
applicationDocuments/rules/billing_rules.active.toml
applicationDocuments/rules/billing_rules.previous.toml
```

### 建议 Schema

规则包使用 TOML。字段提取规则采用数组式结构，每条规则显式声明 `field`，避免 TOML dotted key 与业务字段路径混淆。

```toml
schemaVersion = 1
rulesVersion = "2026.07.01.1"

[[paymentChannels]]
channel = "微信支付"
packages = ["com.tencent.mm"]
appNameKeywords = ["微信"]

[[templates]]
id = "wechat_payment_detail_v1"
enabled = true
priority = 100

[templates.match]
sourcePackages = ["com.tencent.mm"]
keywordsAll = ["当前状态", "支付时间", "交易单号"]

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"
confidence = 0.9

[[templates.extract]]
field = "time"
type = "labelNextLine"
label = "支付时间"
parser = "zhDatetime"

[[templates.extract]]
field = "merchantFullName"
type = "labelNextLine"
label = "商户全称"

[[templates.extract]]
field = "acquirer"
type = "labelNextLine"
label = "收单机构"

[[templates.extract]]
field = "paymentMethod"
type = "labelNextLine"
label = "支付方式"

[[templates.extract]]
field = "details.transaction_no"
type = "labelNextLine"
label = "交易单号"
pattern = '\d{20,}'

[[templates.extract]]
field = "details.merchant_order_no"
type = "labelNextLine"
label = "商户单号"
```

### TOML 规则约束

1. `field` 必须是字符串字段路径，例如 `paymentChannel` 或 `details.transaction_no`。
2. `templates.extract` 必须是数组，不使用 `extract.paymentChannel` 这类嵌套表。
3. 正则建议使用 TOML literal string，例如 `pattern = '\d{20,}'`，减少反斜杠转义。
4. 规则加载后应转换为内部强类型模型，再交给 `BillingRuleEngine` 执行。
5. 远程规则包仍只允许声明式 TOML，不允许脚本、表达式求值或动态代码。

### 代码模块

1. `BillingRuleRepository`

   职责：

   - 加载内置规则
   - 加载当前激活的本地规则
   - 加载调试覆盖规则
   - 解析 TOML
   - 校验 schema 版本、规则 ID 唯一性和字段路径
   - 校验 extractor/parser 白名单和正则可编译性
   - 提供当前激活规则集

2. `BillingRuleEngine`

   职责：

   - 匹配账单模板
   - 执行字段提取器
   - 计算字段置信度
   - 合并模板结果
   - 输出 `BillingRuleTrace`

3. `BillingRuleParsers`

   支持解析器：

   - 金额
   - 中文日期时间
   - ISO 日期时间
   - 正则分组
   - 原始字符串

4. `BillingRuleExtractors`

   支持提取器：

   - `constant`
   - `regex`
   - `labelNextLine`
   - `labelPreviousLine`
   - `betweenLabels`
   - `nearKeyword`

### 验收标准

1. 微信支付详情页字段提取由 TOML 规则驱动。
2. 支付通道包名映射可以通过规则包更新。
3. 新增支付 App 包名映射不需要改业务代码。
4. 规则执行能输出 Trace。

## 阶段三：AI 异步补全

### 交易生命周期

新增或存储这些元数据：

```text
ai_enhance_status: pending | completed | failed | timeout | skipped
ai_enhance_at
rule_version
rule_trace_id
```

如果第一版不方便改数据库 schema，可以先放到 `details` 中。

### 合并策略

AI 可以填充或优化：

- 备注
- 分类
- 支付方式
- 交易对方
- 商户全称
- 收单机构
- 交易单号
- 商户单号
- details

AI 默认不覆盖高置信规则字段：

- 金额
- 支付通道
- 交易时间

建议行为：

```text
规则置信度高 -> 保留规则值
规则置信度低或缺失 -> 允许使用 AI 值
AI 与高置信金额冲突 -> 记录冲突，保留规则金额
```

### 超时策略

截图自动记账场景：

```text
AI 超时：6-8 秒
```

手动图片识别场景：

```text
AI 超时：20-30 秒
```

AI 超时不应回滚已经创建的交易。

### 通知策略

Android 分享记账主流程使用短时前台服务通知：

```text
正在识别账单
BeeCount 正在处理你分享的截图...
```

快速创建成功通知：

```text
已自动记账
-5.07 元 · 微信支付
正在补全商户和分类...
```

AI 补全完成通知：

```text
账单已补全
天津海河测试餐厅甲 · 餐厅
```

AI 失败通知：

```text
已自动记账
AI 补全失败，可稍后手动编辑
```

前台服务停止条件：

```text
基础交易创建成功 -> 更新成功通知 -> 停止前台服务
识别失败 -> 更新失败通知 -> 停止前台服务
```

AI 补全后续处理：

```text
AI 成功 -> 安全合并允许字段 -> 更新交易 -> 发送补全通知
AI 失败 -> 记录 failed -> 保留已创建交易 -> 发送可编辑提示
AI 超时 -> 记录 timeout -> 保留已创建交易
```

### 验收标准

1. 规则高置信时，交易创建不再等待 AI。
2. AI 成功后只更新允许更新的字段。
3. AI 超时被记录，但不会导致自动记账失败。
4. 用户仍可正常编辑交易。

## 阶段四：远程规则更新

### Manifest

远程 manifest 示例：

```json
{
  "latest": {
    "schemaVersion": 1,
    "rulesVersion": "2026.07.01.1",
    "minAppVersion": "0.0.1",
    "url": "https://example.com/rules/billing_rules_2026.07.01.1.toml",
    "sha256": "..."
  }
}
```

### 更新流程

```text
启动后或每天检查一次
-> 下载 manifest
-> 比较 rulesVersion
-> 下载规则包
-> 校验 sha256
-> 校验 TOML 结构、schemaVersion、字段路径、白名单和正则
-> 运行 smoke test
-> 保存为激活规则
-> 保留上一版用于回滚
```

### 安全要求

1. 必须校验 hash。
2. 正式公开发布前强烈建议加入签名校验。
3. 未知 `schemaVersion` 必须拒绝。
4. 无效规则不能替换当前激活规则。
5. 必须保留上一版规则用于回滚。
6. 内置规则必须始终可用。

### 设置页展示

增加规则诊断区：

```text
规则版本：2026.07.01.1
来源：内置 | 远程 | 本地覆盖
上次更新：2026-07-01 10:00
上次更新状态：成功 | 失败
恢复内置规则
```

### 验收标准

1. 远程更新失败不影响当前激活规则。
2. App 可以回滚到上一版或内置规则。
3. 规则版本能在诊断页和日志里看到。

## 阶段五：AI 规则评估

AI 应评估规则质量，而不是直接发布规则。

### 输入

```json
{
  "sourcePackage": "com.tencent.mm",
  "paymentChannel": "微信支付",
  "ocrText": "...",
  "ruleTrace": {},
  "ruleResult": {},
  "aiResult": {},
  "userFinalResult": {}
}
```

### 输出

```json
{
  "diagnosis": "merchantFullName 提取正确，但 note 应优先取标题商户名。",
  "suggestedRules": [
    {
      "field": "note",
      "strategy": "nearTopMerchantName",
      "reason": "顶部商户标题比商户全称更适合作为备注。"
    }
  ],
  "risk": "medium",
  "needsHumanReview": true
}
```

### 工作流

```text
收集失败样本或用户编辑样本
-> AI 评估规则 Trace
-> AI 生成规则改进建议
-> 开发者审核建议
-> 转换为 TOML 规则
-> 运行 golden 回归测试
-> 发布规则包
```

### 验收标准

1. AI 建议保存为可审核产物。
2. AI 不能自动激活新的生产规则。
3. 建议能关联到规则 ID、字段、证据和样本。

## 阶段六：规则评测和回归测试

### 建议目录

```text
tool/rule_eval/
  samples/
    wechat_payment_detail_001.json
    alipay_payment_detail_001.json
  expected/
    wechat_payment_detail_001.expected.json
```

### 样本格式

```json
{
  "id": "wechat_payment_detail_001",
  "sourcePackage": "com.tencent.mm",
  "ocrText": "...",
  "expected": {
    "amount": -5.07,
    "time": "2026-06-30T12:51:18",
    "paymentChannel": "微信支付",
    "merchantFullName": "东莞市小吉姆餐饮管理有限公司",
    "paymentMethod": "平安银行信用卡(2299)"
  }
}
```

### 命令

```text
dart run tool/rule_eval.dart
```

### 指标

输出内容：

- 模板命中率
- 字段准确率
- 误命中数量
- 提取耗时
- 失败样本 diff

### 验收标准

1. 不运行完整 App 也能测试规则包变更。
2. 微信核心字段在 golden 样本上达到较高准确率。
3. 远程规则包激活前必须通过 smoke test。

## 实施顺序

建议顺序：

1. 增加规则 Trace 和快速记账。
2. 增加 AI 异步补全和安全合并策略。
3. 引入内置 TOML 规则包。
4. 将支付通道映射迁入规则包。
5. 将微信支付详情页提取迁入配置化规则。
6. 增加规则评测 CLI。
7. 增加远程规则更新服务。
8. 增加 AI 规则评估工作流。

## 第一版最小可交付

第一版最小可交付范围：

1. `assets/rules/billing_rules.toml`
2. `BillingRuleRepository`
3. `BillingRuleEngine`
4. 微信支付详情页模板
5. 可配置支付 App 映射
6. 规则 Trace 日志
7. 规则优先自动记账
8. AI 异步补全

完成这个里程碑后，自动记账的感知耗时应明显下降，同时为后续远程规则更新和 AI 辅助规则优化打好基础。
