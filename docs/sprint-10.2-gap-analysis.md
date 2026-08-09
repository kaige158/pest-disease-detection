# Sprint 10.2 — 战略升级差距分析与执行路线

> **分析日期:** 2026年8月9日
> **角色:** AI产品技术总监
> **依据:** 用户战略Prompt + 完整代码审计
> **上接:** [项目进度总览](./项目进度总览-20260809.md)

---

## 一、当前代码全貌（审计结论）

```
                    代码量              功能状态
┌──────────┐    37 Java实体+仓库    ✅ 表结构完整，查询能力齐全
│ 数据库    │    10张表，1份种子SQL   ✅ 字段设计前瞻（user_feedback，
│           │                          expert_review, data_grade均已有）
├──────────┤
│ Spring   │    7个Controller        ✅ API路由完整
│ Boot     │    2个Service           ⚠️ AiServiceClient能调AI Service
│           │    5个Repository       🔴 RecognitionController有TODO注释，
│           │                          识别结果从未写入数据库
├──────────┤
│ AI       │    5个Provider          ✅ Gemini已验证通过
│ Service  │    Parser+Agent+Prompts ✅ 解析管线完整
│           │                          🔴 SYSTEM_PROMPT_V3从未被使用
│           │                          🔴 models/ 目录完全空白(只有__init__.py)
│           │                          🔴 Claude/Custom Provider是空壳
├──────────┤
│ Flutter  │    5个页面              ✅ 拍照识别/知识库/对话/设置
│           │    3个Model             ✅ 中老双语切换
│           │    离线知识库(16种)      ✅ 双flavor(蔬菜版/果树版)
│           │                          🔴 反馈按钮是假按钮(只弹SnackBar)
│           │                          🔴 ApiClient定义了但从未被使用
│           │                          🔴 所有Model类定义了但从未被实例化
└──────────┘
```

---

## 二、核心问题：能跑但没跑通，能存但没存上

```
当前链路：
  Flutter拍照 → Spring Boot → AI Service → Gemini → 结果返回
                                                      ↓
                                                   ❌ 丢弃！

应该的链路：
  Flutter拍照 → Spring Boot → AI Service → Gemini → 结果入库
                                                      ↓
                                                  Flutter展示
                                                      ↓
                                                 用户反馈(✅/❌)
                                                      ↓
                                                 专家审核
                                                      ↓
                                                 训练数据资产
```

**最大的问题不是缺少功能，而是现有功能没有闭环。**

---

## 三、差距清单（精确到文件和字段）

### Gap 1: 🔴 识别结果不入库 — 最高优先级

| 位置 | 现状 | 应该是 |
|------|------|--------|
| `RecognitionController.java:57` | `// TODO: 第三阶段完整实现` | 完整实现 |
| `diagnosis_record` 表 | 0行数据 | 每次识别1行 |
| `ai_raw_response` 字段 | 从未写入 | 保存完整AI原始响应 |
| `parsed_results` 字段 | 从未写入 | 保存解析后的结构化结果 |
| `provider_used` 字段 | 从未写入 | 记录"gemini"等 |
| `processing_time_ms` 字段 | 从未写入 | 记录实际耗时 |

### Gap 2: 🔴 用户反馈是假闭环

| 位置 | 现状 | 应该是 |
|------|------|--------|
| Flutter `result_page.dart:189-218` | 只弹SnackBar，不发请求 | 调API提交反馈 |
| `user_feedback` 字段 | 从未被写入 | "confirmed"/"disputed" |
| `user_feedback_at` 字段 | 从未被写入 | 反馈时间戳 |
| Spring Boot | 没有feedback API | `POST /api/v1/recognition/{taskId}/feedback` |

### Gap 3: 🟡 专家审核链路缺失

| 位置 | 现状 | 应该是 |
|------|------|--------|
| `expert_reviewed` 字段 | 从未被写入 | 专家审核后更新 |
| `expert_action` 字段 | 从未被写入 | "verified"/"corrected"/"rejected" |
| `expert_disease_id` 字段 | 从未被写入 | 专家指定正确病害 |
| Spring Boot | 没有审核API | `AdminController` 需增加审核接口 |

### Gap 4: 🟡 种子数据未入库

| 位置 | 现状 | 应该是 |
|------|------|--------|
| `seed_data_v1.sql` | 文件存在但未执行 | 已执行，24种病虫害入库 |
| 知识库API | 返回空 | 返回作物+病虫害+防控方案 |

### Gap 5: 🟡 AI评估体系缺失

| 需要 | 现状 |
|------|------|
| `evaluation_record` 表 | 未创建 |
| 测试图片集 | 不存在 |
| 准确率计算 | 不存在 |

### Gap 6: 🟢 阶段性目标（本次不优先）

| 需求 | 暂时不做 |
|------|----------|
| YOLO训练管线 | 数据<5000张，过早 |
| AI Router | 只有1个API可用，不需要路由 |
| 离线TensorFlow Lite | 数据不够 |
| 农田采集模块 | 先跑通核心闭环 |

---

## 四、Sprint 10.2 执行任务（按优先级）

```
Task-0: 种子数据入库                30分钟  🔴 P0
  ↓
Task-1: 修复识别结果入库             2小时   🔴 P0
  ↓
Task-2: 实现用户反馈闭环             1.5小时 🔴 P0
  ↓
Task-3: 专家审核API                  1小时  🟡 P1
  ↓
Task-4: 端到端验证                   1小时  🔴 P0
  ↓
Task-5: 创建AI评估表+基础统计        1小时  🟡 P1
```

### 详细任务分解

#### Task-0: 种子数据入库 (30分钟)
- 检查PostgreSQL是否运行
- 执行 `database/seed_data_v1.sql`
- 验证: `SELECT COUNT(*) FROM core.disease` 返回24

#### Task-1: 修复识别结果入库 (2小时)
- 修改 `RecognitionController.identify()`:
  1. 创建 `DiagnosisRecord` 实体
  2. 设置 taskId, userId, version, language, imageUrl
  3. status="processing" → 保存 → 调用AI
  4. 解析AI结果 → 填充如下字段:
     - `ai_raw_response` (完整JSON)
     - `parsed_results` (结构化)
     - `top_disease_id` (匹配本地病害库)
     - `top_confidence`, `confidence_level`
     - `provider_used`
     - `processing_time_ms`
  5. status="completed" → 更新保存
  6. 失败时 status="failed" + error_message

#### Task-2: 实现用户反馈闭环 (1.5小时)
- **Spring Boot端:** 新增 `POST /api/v1/recognition/{taskId}/feedback`
  - Request: `{feedback: "confirmed"|"disputed", note: ""}`
  - 更新 `diagnosis_record.user_feedback`
  - 如果是"disputed" → `expert_reviewed=true`
- **Flutter端:** 修改 `result_page.dart`
  - 反馈按钮 → 调API → 真正发送数据
  - 移除假SnackBar

#### Task-3: 专家审核API (1小时)
- 新增 `AdminController` 审核接口:
  - `GET /api/v1/admin/review/pending` — 待审核列表
  - `POST /api/v1/admin/review/{recordId}` — 提交审核
    - Request: `{action, correctDiseaseId, notes}`
    - 更新 expert_reviewed, expert_action, expert_disease_id, expert_notes

#### Task-4: 端到端验证 (1小时)
- 完整跑通: Flutter拍照 → 入库 → 展示 → 反馈 → 审核
- 验证 diagnosis_record 表有完整记录
- 验证 feedback 数据正确写入

#### Task-5: 创建AI评估表 (1小时)
- 执行 `evaluation_record` DDL
- 创建 `EvaluationService` 基础统计方法
- 准备测试框架

---

## 五、执行原则

> 你的目标不是做"答辩项目"，而是把它继续推进成真正可落地农业AI产品。

1. **先闭环，后扩展** — 先让识别→入库→反馈→审核完全跑通
2. **所有AI调用必须留下数据** — 原始响应、解析结果、置信度，一个不丢
3. **所有错误进入训练闭环** — 用户纠正的数据是未来模型的基础
4. **API只是过渡** — 数据积累到一定量才能训练自己的模型

---

## 六、完成标准

```
Sprint 10.2 完成 = 以下全部通过:

✅ 种子数据24种病虫害可在API查询到
✅ 拍一张照片 → 3秒内 diagnosis_record 新增1条完整记录
✅ Flutter反馈按钮 → 真正调API → 数据入库
✅ 专家后台 → 能看到待审核列表 → 能提交审核
✅ recognition_record表有以下完整字段:
   ai_raw_response, parsed_results, top_disease_id,
   top_confidence, provider_used, processing_time_ms
```

---

*报告结束 — 开始执行 Sprint 10.2 Task-0*
