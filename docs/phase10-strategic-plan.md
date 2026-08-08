# 阶段10：农业AI平台战略规划（修订版）

> 定位：从MVP代码就绪 → 真实可用、可验证的农业AI平台
> 核心原则：**先让现有管线跑通真实数据，再做新功能**

---

## 1. 当前问题分析

### 1.1 已完成的（扎实）

| 模块 | 强度 | 说明 |
|------|:--:|------|
| Flutter双版本APP | 85% | 拍照→结果完整流程、双语切换、离线知识库16种 |
| Spring Boot后端 | 80% | 10表+CRUD+3个Controller+AdminWeb+Security |
| Python AI Service | 75% | Provider抽象+Parser+Mock+诊断Agent+Prompts v3 |
| 专家后台Web | 70% | Dashboard+审核+知识库+统计，4页面可用 |
| 诊断Agent | 70% | 14规则逐步问答 |
| 种子数据 | 60% | 8作物×24病虫害SQL已编写，但**未入库** |

### 1.2 核心问题：能跑但没跑过

```
现在的状态：
  Mock AI ✅  → 模拟返回预设病虫害
  后端CRUD ✅ → 数据库有表但没数据
  Flutter UI ✅ → 页面完整但真实流程没跑通
  
最大的问题不是缺少功能，而是：
  现有管线从未用真实AI API + 真实图片跑通一次端到端
```

### 1.3 重新排序的优先级

| # | 任务 | 为什么优先 | 优先级 |
|---|------|-----------|:--:|
| 1 | **接入真实AI API + 端到端测试** | 没有真实AI能力，平台只是空壳 | 🔴 P0 |
| 2 | **种子数据入库** | 24种病虫害数据入PostgreSQL，知识库可用 | 🔴 P0 |
| 3 | **AI评估体系** | 有了真实AI后必须能衡量准确率 | 🟡 P1 |
| 4 | **用户反馈闭环** | 防治效果追踪 → 数据资产增值 | 🟡 P1 |
| 5 | **训练数据管线** | 数据积累到可训练规模后的出口 | 🟢 P2 |
| 6 | **农田采集模块** | 独立新功能，核心链路跑通后再做 | 🟢 P2 |

---

## 2. 修正后的优先级路线图

```
现在要做的事（按顺序）：

Sprint 10.1 🔴 真实AI接入 + 端到端跑通  (1周)
    │  产出: 真实AI可识别图片 → 结果入库
    │  依赖: 需要一个AI API Key (OpenAI/Gemini)
    │
    ▼
Sprint 10.2 🔴 种子数据入库 + AI评估  (1周)
    │  产出: 24种病虫害入库 + 用测试图片跑AI → 准确率报告
    │  依赖: 10.1完成 + 5-10张测试图片
    │
    ▼
Sprint 10.3 🟡 用户反馈闭环  (1周)
    │  产出: 识别→防治→反馈效果→数据沉淀
    │
    ▼
Sprint 10.4 🟢 训练数据导出管线  (1周)
    │  产出: S/A级数据导出为YOLO/COCO格式
    │
    ▼
Sprint 10.5 🟢 农田采集模块 + API服务化  (2周)
       产出: 结构化采集 + 对外API
```

---

## 3. Sprint 10.1: 真实AI接入 + 端到端跑通 🔴 P0

### 3.1 目标

```
让现有管线真正工作：
  Flutter拍照 → Base64上传 → Spring Boot接收
    → Python AI Service → 真实Vision API
    → Parser标准化 → 结果入库 → Flutter展示
```

### 3.2 具体任务

```
1. 获取API Key (Gemini免费额度优先)
2. 配置 ai-service/.env: AI_PROVIDER=gemini, AI_API_KEY=xxx
3. 测试单个图片识别:
   curl POST /api/v1/recognition/identify → 看返回JSON
4. 用5-10张真实病虫害图片测试
5. 修复链路bug (图片大小/超时/解析错误)
6. 实现Spring Boot到AI Service的HTTP调用
7. 实现recognition_record入库(含AI结果+图片URL)
```

### 3.3 验收标准

```
✅ 拍一张真实病虫害照片 → 3-10秒 → 看到AI识别结果
✅ recognition_record表有新记录
✅ 结果包含: 病虫害名/置信度/症状/防控建议
✅ 支持OpenAI和Gemini两种Provider切换
```

---

## 4. Sprint 10.2: 种子数据入库 + AI评估体系 🟡 P1

### 4.1 种子数据入库

```bash
# 执行已有SQL
psql -U postgres -d laos_agri -f database/seed_data_v1.sql
# 入库：8作物 + 24病虫害 + 防控方案 + 中老双语
```

### 4.2 AI评估：用已知图片测试AI准确率

```
准备: 30张已标注正确答案的病虫害图片
流程: 逐张调用AI识别 → 对比正确答案 → 计算准确率

评估指标:
  Top1准确率: AI的第一选择正确的比例
  Top3准确率: AI前三个选择中包含正确答案的比例
  按作物准确率: 白菜/番茄/辣椒...分别统计
  按病虫害准确率: 炭疽病/霜霉病...分别统计
  置信度可靠性: AI说"92%置信"时实际正确率是多少
```

### 4.3 新增数据库表

```sql
-- 仅新增1张核心表，够用即可
CREATE TABLE expert.evaluation_record (
    id              BIGSERIAL PRIMARY KEY,
    diagnosis_id    BIGINT REFERENCES core.diagnosis_record(id),
    ai_disease_name VARCHAR(300),
    ai_confidence   DECIMAL(5,4),
    expert_disease_id INT REFERENCES core.disease(id),  -- 正确答案
    is_correct      BOOLEAN NOT NULL,         -- AI是否正确
    is_top3_correct BOOLEAN,                  -- Top3中是否包含
    crop_id         INT REFERENCES core.crop(id),
    provider_used   VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW()
);
```

### 4.4 验收标准

```
✅ 种子数据24种病虫害可在知识库API返回
✅ 30张图片测试完成
✅ 产出第一份AI准确率报告:
   - 总体Top1准确率: XX%
   - 总体Top3准确率: XX%
   - 炭疽病准确率: XX%
   - 晚疫病准确率: XX%
```

---

## 5. Sprint 10.3: 用户反馈闭环 🟡 P1

### 5.1 防治效果反馈

```
识别→防治→7天后回访→反馈效果

feedback表(已设计,需实现):
  treatment_feedback
    - effective / partial / ineffective
    - 处理后多少天
    - 是否需要再次处理
```

### 5.2 数据闭环

```
用户点✅"结果正确" → 自动标记高置信度
用户点❌"不正确" → 进入专家审核队列 → 专家修正 → 回写evaluation_record
```

### 5.3 验收标准

```
✅ 用户可以在结果页点"正确/不正确"
✅ 反馈数据入库
✅ 专家后台能看到反馈列表
```

---

## 6. Sprint 10.4: 训练数据导出管线 🟢 P2

### 6.1 导出功能

```python
# ai-service/app/services/training/
POST /api/v1/training/export
  - 筛选: S级+A级数据
  - 格式: YOLO / COCO / 分类目录
  - 质量: image_quality >= 0.7, is_usable = TRUE
  - 输出: 下载链接
```

### 6.2 验收标准

```
✅ 选择S级+A级数据 → 导出为YOLO格式
✅ 导出包含: images/ + labels/ + metadata.csv
✅ 可被YOLOv8训练脚本直接读取
✅ 未来新增数据可增量导出
```

---

## 7. Sprint 10.5: 农田采集模块 + API服务化 🟢 P2

### 7.1 field_observation表

```
完整的结构化农田数据采集(表结构见原版设计)
核心字段: GPS + 生长阶段 + 环境 + 症状描述 + 图片 + AI+专家双验证
```

### 7.2 API服务化

```
对外提供AI诊断API:
  POST /api/v1/public/identify
  Header: X-API-Key: xxx
  请求: {image_base64, version, language}
  响应: {disease_name, confidence, prevention_plan}
```

### 7.3 验收标准

```
✅ 技术员用APP完成一次完整田间采集
✅ 第三方可通过API Key调用识别接口
✅ API调用统计可查
```

---

## 8. 不需要现在做的事

| 任务 | 原因 |
|------|------|
| 离线AI模型(TFLite/ONNX) | 数据量不够，先积累到5000+张再考虑 |
| 老挝农业词库 | 需要老挝本地专家参与，不是纯技术问题 |
| 复杂权限系统 | 当前4角色够用，等用户量上来再加RBAC |
| 多国扩展(泰/越/柬) | 先把老挝跑通 |


---

## 9. 数据库新增总览（Sprint 10.2-10.5 需创建的表）

| Sprint | 表名 | Schema | 用途 |
|--------|------|--------|------|
| 10.2 | evaluation_record | expert | AI诊断质量评估 |
| 10.3 | treatment_feedback | core | 防治效果反馈 |
| 10.4 | training_export_job | extension | 训练数据导出任务 |
| 10.5 | field_observation | core | 农田结构化采集 |

---

## 10. 不需要现在做的事

| 任务 | 原因 |
|------|------|
| 离线AI模型(TFLite/ONNX) | 数据量不够，先积累到5000+张再考虑 |
| 老挝农业词库 | 需老挝本地专家参与，非纯技术问题 |
| 复杂权限系统 | 当前4角色够用 |
| 多国扩展(泰/越/柬) | 先老挝跑通 |
| 复杂数据增强管线 | 先手动导出，验证可行性后再自动化 |

---

## 11. "训练+API调用"能力实现路径

> 这是你特别强调的需求：系统必须能持续训练 + 对外提供API服务

```
当前            Sprint 10.1-10.2     Sprint 10.4        6个月后
─────           ────────────────     ────────────       ────────
Mock AI    →    真实AI接入     →    训练数据导出   →   专属模型
                + 评估体系           (YOLO/COCO)        训练完成
                + 准确率报告                             
                                                       ↓
                                                  API服务化
                                                  对外开放
                                                  
持续训练闭环:
  新品种图片 → AI识别 → 专家审核 → evaluation_record
    → 数据达标(≥5000张) → 导出训练集 → 微调模型
    → 部署新模型 → 替换API Provider → 准确率提升
    → 更多用户使用 → 更多数据 → ...
```

---

## 12. 立即开始 Sprint 10.1

**需要你提供：**
- 1个AI API Key（推荐Gemini，免费额度够测试）：https://aistudio.google.com/apikey
- 或 OpenAI API Key

**有了Key之后，我10分钟内完成：**
1. 配置 `.env` 切换到真实AI
2. 用1张图片测试端到端：拍照 → AI识别 → 结果入库
3. 如果通了，再用10张图片批量测试
4. 产出第一份"AI能跑通"的证据

---
> **当前状态：设计完成，等待API Key启动Sprint 10.1**
