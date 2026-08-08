# 数据库架构设计评审版 v3

> 版本: v3.0 | 日期: 2026-08-08 | 阶段: 第三阶段前置评审
> 架构: Spring Boot(业务后端) + Python AI Service + PostgreSQL

---

## 一、最终架构确认

```
Flutter APP (vegetable / fruit)
        │
        │ HTTPS REST
        ▼
Spring Boot Backend (:8080)          ← 业务后端(本阶段新建)
  ├── 用户系统 (Spring Security)
  ├── 知识库 CRUD
  ├── 识别记录管理
  ├── 防控方案管理
  ├── 数据资产管理
  └── API 网关 → Python AI Service
        │
        │ HTTP (内部/gRPC)
        ▼
Python AI Service (:8000)            ← 保留已有代码，独立部署
  ├── AI Provider 抽象层
  ├── AI Response Parser
  ├── Confidence Evaluator
  └── 图片预处理
        │
        ▼
Vision Model API (OpenAI/Claude/Gemini)
```

---

## 二、数据库分库策略

```
┌─────────────────────────────────────────────────────────┐
│                   PostgreSQL 数据库                       │
│                                                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ schema: core (核心业务 — 立即创建)               │     │
│  │                                                 │     │
│  │  user                用户表                     │     │
│  │  crop_category       作物分类                   │     │
│  │  crop                作物列表                   │     │
│  │  disease             病虫害字典                 │     │
│  │  disease_image       病虫害图片(科研核心)        │     │
│  │  prevention_plan     防控方案                   │     │
│  │  prevention_item     防控措施条目               │     │
│  │  recognition_record  识别记录                   │     │
│  │  knowledge_article   知识库文章                 │     │
│  │  language_resource   语言资源(i18n存储)         │     │
│  └────────────────────────────────────────────────┘     │
│                                                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ schema: extension (科研扩展 — 先设计后实现)      │     │
│  │                                                 │     │
│  │  weather_data         天气数据(API采集)          │     │
│  │  label_review_log     标注审核日志              │     │
│  │  data_export_log      数据导出记录              │     │
│  │  model_training_dataset 训练数据集管理           │     │
│  │  enhancement_log      数据增强记录              │     │
│  └────────────────────────────────────────────────┘     │
│                                                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ schema: audit (审计 — 后期)                      │     │
│  │                                                 │     │
│  │  operation_log        操作日志                  │     │
│  │  api_call_stat        API调用统计              │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## 三、核心业务表设计（立即创建）

> 标记: 🔴核心表(必须) | 🟡重要表(建议) | 🟢扩展表(后续)

### 表1: `core.user` — 用户表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | BIGSERIAL | 主键 | PK | ✅ |
| uuid | VARCHAR(36) UNIQUE | 对外ID(UUID) | UK | ✅ |
| phone | VARCHAR(20) | 手机号(老挝格式) | IDX | ✅ |
| nickname | VARCHAR(100) | 昵称 | | ✅ |
| language_pref | VARCHAR(10) DEFAULT 'lo' | 语言偏好 zh/lo | | ✅ |
| region_province | VARCHAR(100) | 省份 | IDX | ✅ |
| region_district | VARCHAR(100) | 地区 | | ✅ |
| crop_preferences | JSONB | 偏好作物类型 | | ✅ |
| role | VARCHAR(30) DEFAULT 'guest' | guest/farmer/technician/admin | IDX | ✅ |
| is_active | BOOLEAN DEFAULT TRUE | 是否启用 | | ✅ |
| created_at | TIMESTAMP | 注册时间 | IDX | ✅ |
| updated_at | TIMESTAMP | 更新时间 | | |
| last_login_at | TIMESTAMP | 最后登录 | | |

**设计说明:** tourist模式不需要注册，用设备UUID标识。手机号可选，降低注册门槛。

---

### 表2: `core.crop_category` — 作物分类表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| name_zh | VARCHAR(100) | 中文名("茄果类") | | ✅ |
| name_lo | VARCHAR(200) | 老挝语名 | | ✅ |
| parent_id | INT | 父分类(支持二级) | IDX | ✅ |
| sort_order | INT DEFAULT 0 | 排序 | | |
| icon_url | VARCHAR(500) | 图标 | | |
| created_at | TIMESTAMP | | | |

---

### 表3: `core.crop` — 作物表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| category_id | INT | FK→crop_category | FK,IDX | ✅ |
| name_zh | VARCHAR(100) | 中文名 | | ✅ |
| name_lo | VARCHAR(200) | 老挝语名 | | ✅ |
| scientific_name | VARCHAR(200) | 学名 | | |
| description_zh | TEXT | 简介 | | |
| description_lo | TEXT | 简介(老挝语) | | |
| planting_info_zh | TEXT | 种植信息 | | |
| planting_info_lo | TEXT | | | |
| icon_url | VARCHAR(500) | 图标 | | |
| image_url | VARCHAR(500) | 大图 | | |
| disease_count | INT DEFAULT 0 | 关联病虫害数(冗余) | | |
| sort_order | INT DEFAULT 0 | | | |
| is_active | BOOLEAN DEFAULT TRUE | | | |
| created_at | TIMESTAMP | | | |
| updated_at | TIMESTAMP | | | |

---

### 表4: `core.disease` — 病虫害字典表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| crop_id | INT | FK→crop | FK,IDX | ✅ |
| name_zh | VARCHAR(200) | 病虫害中文名 | | ✅ |
| name_lo | VARCHAR(300) | 老挝语名 | | ✅ |
| scientific_name | VARCHAR(300) | 病原/虫害学名 | | ✅ |
| type | VARCHAR(20) | disease/pest | IDX | ✅ |
| symptoms_zh | TEXT | 症状描述 | | ✅ |
| symptoms_lo | TEXT | | | ✅ |
| conditions_zh | TEXT | 发病条件 | | |
| conditions_lo | TEXT | | | |
| severity_level | VARCHAR(20) | mild/moderate/severe | | ✅ |
| tags | VARCHAR(500) | 搜索标签 | GIN | |
| image_count | INT DEFAULT 0 | 图片数量(冗余) | | |
| source_type | VARCHAR(30) DEFAULT 'TEACHER_DATA' | TEACHER_DATA/USER_UPLOAD/FIELD_COLLECTION/AI_GENERATED | IDX | ✅ |
| collector_id | INT | 采集者ID(如果是田野采集) | FK | |
| collection_time | TIMESTAMP | 采集时间 | | |
| approval_status | VARCHAR(30) DEFAULT 'approved' | approved/pending/rejected | | ✅ |
| is_active | BOOLEAN DEFAULT TRUE | | | |
| created_at | TIMESTAMP | | IDX | |
| updated_at | TIMESTAMP | | | |

> **source_type 枚举说明:**
> - `TEACHER_DATA`: 老师提供的语料数据
> - `USER_UPLOAD`: 用户拍照上传经审核入库
> - `FIELD_COLLECTION`: 技术员田野采集
> - `AI_GENERATED`: AI生成经人工确认

**全文检索索引:**
```sql
CREATE INDEX idx_disease_search ON core.disease 
USING gin(to_tsvector('simple', 
    COALESCE(name_zh,'') || ' ' || COALESCE(name_lo,'') || ' ' || 
    COALESCE(symptoms_zh,'') || ' ' || COALESCE(tags,'')
));
```

---

### 表5: `core.disease_image` — 病虫害图片表 🔴 (科研数据核心)

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | BIGSERIAL | 主键 | PK | ✅ |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| image_url | VARCHAR(500) | 图片存储URL | | ✅ |
| thumbnail_url | VARCHAR(500) | 缩略图 | | |
| image_hash | VARCHAR(64) | SHA256 (去重) | UK | ✅ |
| file_size_bytes | INT | 文件大小 | | |
| crop_id | INT | FK→crop | FK,IDX | ✅ |
| disease_id | INT | FK→disease | FK,IDX | |
| recognition_record_id | INT | FK→recognition_record | FK | |
| image_type | VARCHAR(30) | symptom/leaf/fruit/stem/root/whole | | ✅ |
| image_source | VARCHAR(30) DEFAULT 'TEACHER_DATA' | TEACHER_DATA/USER_UPLOAD/FIELD_COLLECTION/AI_GENERATED | IDX | ✅ |
| source_type | VARCHAR(30) DEFAULT 'TEACHER_DATA' | ← 数据来源枚举(同disease表) | | ✅ |
| collector_id | INT | 采集者 | FK | ✅ |
| collection_time | TIMESTAMP | 采集时间 | | ✅ |
| approval_status | VARCHAR(30) DEFAULT 'approved' | approved/pending/rejected | IDX | ✅ |
| **GPS信息** |||||
| gps_latitude | DECIMAL(10,7) | GPS纬度 | IDX | ✅ |
| gps_longitude | DECIMAL(10,7) | GPS经度 | IDX | ✅ |
| location_name | VARCHAR(300) | 位置描述 | | |
| taken_at | TIMESTAMP | 拍摄时间 | | ✅ |
| **生长信息** |||||
| growth_stage | VARCHAR(50) | seedling/vegetative/flowering/fruiting/harvest | IDX | ✅ |
| plant_part | VARCHAR(50) | leaf/stem/fruit/flower/root | | ✅ |
| **环境信息** |||||
| weather_condition | VARCHAR(50) | sunny/cloudy/rainy | | ✅ |
| temperature | DECIMAL(5,2) | 温度(°C) | | |
| humidity | DECIMAL(5,2) | 湿度(%) | | |
| **标注信息** |||||
| ai_label | VARCHAR(300) | AI标注结果 | | ✅ |
| ai_confidence | DECIMAL(5,4) | AI置信度 | | ✅ |
| human_label | VARCHAR(300) | 人工修正标注 | | |
| human_label_by | INT | 标注人ID | FK | |
| label_status | VARCHAR(30) DEFAULT 'ai_only' | ai_only/verified/corrected/disputed | IDX | ✅ |
| **质量评估** |||||
| image_quality_score | DECIMAL(3,2) | 质量评分(0-1) | | ✅ |
| is_usable | BOOLEAN DEFAULT TRUE | 是否可用于训练 | IDX | ✅ |
| reject_reason | VARCHAR(300) | 不可用原因 | | |
| **设备与语言** |||||
| device_model | VARCHAR(100) | 设备型号 | | |
| language | VARCHAR(10) DEFAULT 'zh' | 用户语言 | | |
| is_public | BOOLEAN DEFAULT FALSE | 是否公开 | | |
| created_at | TIMESTAMP | | IDX | |
| updated_at | TIMESTAMP | | | |

---

### 表6: `core.prevention_plan` — 防控方案表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| disease_id | INT | FK→disease | FK,IDX | ✅ |
| plan_type | VARCHAR(30) | chemical/biological/physical/cultivation | | ✅ |
| title_zh | VARCHAR(200) | "化学防治" | | ✅ |
| title_lo | VARCHAR(300) | | | ✅ |
| sort_order | INT DEFAULT 0 | | | |
| source_type | VARCHAR(30) DEFAULT 'TEACHER_DATA' | 数据来源 | | |
| created_at | TIMESTAMP | | | |

---

### 表7: `core.prevention_item` — 防控措施条目表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| plan_id | INT | FK→prevention_plan | FK,IDX | ✅ |
| name_zh | VARCHAR(300) | 措施/农药名称 | | ✅ |
| name_lo | VARCHAR(400) | | | ✅ |
| usage_zh | TEXT | 用法说明 | | |
| usage_lo | TEXT | | | |
| notes_zh | TEXT | 注意事项 | | |
| notes_lo | TEXT | | | |
| sort_order | INT DEFAULT 0 | | | |

---

### 表8: `core.recognition_record` — 识别记录表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | BIGSERIAL | 主键 | PK | ✅ |
| task_id | VARCHAR(50) UNIQUE | 任务编号 | UK | ✅ |
| user_id | INT | FK→user (可为NULL) | FK,IDX | |
| device_uuid | VARCHAR(100) | 设备标识(游客) | IDX | |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| image_url | VARCHAR(500) | 原图URL | | ✅ |
| language | VARCHAR(10) | 请求语言 | | ✅ |
| crop_id | INT | 用户指定作物(可选) | FK | |
| status | VARCHAR(20) DEFAULT 'pending' | pending/processing/completed/failed | IDX | ✅ |
| ai_raw_response | JSONB | AI原始响应 | | ✅ |
| parsed_results | JSONB | 解析后标准化结果 | | ✅ |
| top_disease_id | INT | 最佳匹配病虫害 | FK | |
| top_confidence | DECIMAL(5,4) | 最高置信度 | | ✅ |
| confidence_level | VARCHAR(20) | high(≥90%)/medium(70-89%)/low(<70%) | | ✅ |
| provider_used | VARCHAR(50) | 使用的AI Provider | | |
| processing_time_ms | INT | 处理耗时ms | | |
| gps_latitude | DECIMAL(10,7) | GPS(采集用) | | |
| gps_longitude | DECIMAL(10,7) | | | |
| device_info | VARCHAR(300) | 设备信息 | | |
| error_message | TEXT | 错误信息 | | |
| created_at | TIMESTAMP | | IDX | |

---

### 表9: `core.knowledge_article` — 知识库文章表 🔴

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| version | VARCHAR(20) | vegetable/fruit | IDX | ✅ |
| crop_id | INT | FK→crop | FK,IDX | |
| disease_id | INT | FK→disease(可为NULL) | FK | |
| article_type | VARCHAR(30) | disease/crop/general/faq | IDX | ✅ |
| title_zh | VARCHAR(300) | 标题 | | ✅ |
| title_lo | VARCHAR(400) | | | ✅ |
| content_zh | TEXT | 正文 | | ✅ |
| content_lo | TEXT | | | ✅ |
| tags | VARCHAR(500) | 搜索标签 | GIN | |
| source_type | VARCHAR(30) DEFAULT 'TEACHER_DATA' | | | |
| is_published | BOOLEAN DEFAULT FALSE | 发布状态 | | ✅ |
| view_count | INT DEFAULT 0 | 阅读数 | | |
| created_at | TIMESTAMP | | IDX | |
| updated_at | TIMESTAMP | | | |

---

### 表10: `core.language_resource` — 语言资源表 🔴

> 用于管理UI文本的双语映射，支持动态更新而不需要发版。

| 字段 | 类型 | 说明 | 索引 | 核心 |
|------|------|------|:--:|:--:|
| id | SERIAL | 主键 | PK | ✅ |
| resource_key | VARCHAR(200) | 资源键("recognition_title") | UK | ✅ |
| text_zh | VARCHAR(1000) | 中文文本 | | ✅ |
| text_lo | VARCHAR(1000) | 老挝语文本 | | ✅ |
| module | VARCHAR(50) | 所属模块 | IDX | |
| created_at | TIMESTAMP | | | |
| updated_at | TIMESTAMP | | | |

---

## 四、扩展科研数据表（设计预留，第四阶段后实现）

### 表11: `extension.weather_data` 🟢 预留

> 通过GPS+时间从天气API获取的天气数据，与识别记录关联。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGSERIAL | PK |
| recognition_record_id | INT | FK→recognition_record |
| temperature_max | DECIMAL(5,2) | 最高温 |
| temperature_min | DECIMAL(5,2) | 最低温 |
| temperature_avg | DECIMAL(5,2) | 均温 |
| humidity_avg | DECIMAL(5,2) | 平均湿度 |
| rainfall_mm | DECIMAL(7,2) | 降雨量 |
| weather_desc | VARCHAR(200) | 天气描述 |
| recorded_at | TIMESTAMP | |

---

### 表12: `extension.label_review_log` 🟢 预留

> 图片标注审核日志。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGSERIAL | PK |
| disease_image_id | INT | FK→disease_image |
| reviewer_id | INT | 审核人ID |
| action | VARCHAR(30) | verify/correct/reject |
| old_label | VARCHAR(300) | 旧标注 |
| new_label | VARCHAR(300) | 新标注 |
| notes | TEXT | 审核备注 |
| reviewed_at | TIMESTAMP | |

---

### 表13: `extension.data_export_log` 🟢 预留

> 训练数据导出记录，记录每次导出了哪些数据。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | PK |
| export_type | VARCHAR(30) | training_dataset/report/paper |
| export_format | VARCHAR(30) | json/coco/yolo/csv |
| record_count | INT | 导出条数 |
| filters_applied | JSONB | 筛选条件 |
| exported_by | INT | 操作人 |
| file_url | VARCHAR(500) | 导出文件地址 |
| created_at | TIMESTAMP | |

---

## 五、核心实体关系图 (ER)

```
                            ┌──────────────────┐
                            │   core.user      │
                            │  (用户)           │
                            └──────┬───────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
          │recognition  │ │label_review │ │data_export  │
          │_record      │ │_log         │ │_log         │
          │(识别记录)    │ │(标注日志)   │ │(导出记录)   │
          └──────┬──────┘ └──────┬──────┘ └─────────────┘
                 │               │
    ┌────────────┼───────────────┼──────────────┐
    │            │               │              │
    ▼            ▼               ▼              ▼
┌────────┐ ┌──────────┐  ┌──────────────┐ ┌──────────┐
│ crop   │ │ disease  │  │disease_image │ │knowledge │
│_category│ │(病虫害) │  │(科研图片核心) │ │_article  │
└───┬────┘ └────┬─────┘  └──────┬───────┘ │(知识库)  │
    │           │               │          └──────────┘
    ▼           │               │
┌────────┐      │               │
│ crop   │◄─────┘               │
│(作物)  │                      │
└────────┘                      │
    │                           │
    └───────────────────────────┘
                │
    ┌───────────┴───────────┐
    │                       │
    ▼                       ▼
┌──────────────┐   ┌──────────────┐
│prevention    │   │weather_data  │
│_plan + _item │   │(天气数据)    │
│(防控方案)    │   │              │
└──────────────┘   └──────────────┘
```

---

## 六、数据流设计

### 6.1 用户拍照识别完整数据流

```
[用户拍照]
    │
    ▼
[Flutter APP] ── 图片压缩(≤300KB) ──→ HTTPS Multipart
    │
    ▼
[Spring Boot] ── 接收 ──→ 保存文件 ──→ 创建recognition_record(status=pending)
    │
    │  HTTP POST /ai/identify
    ▼
[Python AI Service]
    ├──→ 图片预处理
    ├──→ AIProvider.identify() → Vision API
    ├──→ AIResponseParser.parse() → 标准化
    ├──→ ConfidenceEvaluator.evaluate() → 置信度分级
    └──→ 返回标准化结果
    │
    ▼
[Spring Boot]
    ├──→ 查询本地病虫害库匹配
    ├──→ 组装防控方案
    ├──→ 更新recognition_record(status=completed)
    ├──→ 写入disease_image(如用户同意数据采集)
    └──→ 返回完整结果
    │
    ▼
[Flutter APP] ── 展示识别结果页
```

### 6.2 知识库查询数据流

```
[用户搜索/浏览]
    │
    ▼
[Spring Boot] ── PostgreSQL全文检索 ──→ 返回列表
    │                                    (按version过滤)
    ▼
[Flutter APP] ── 展示列表页 ── 点击详情 ── 展示详情页
                                     (含防控方案)
```

### 6.3 诊断Agent数据流

```
[用户描述症状]
    │
    ▼
[Spring Boot] ── 构建诊断上下文
    │             (作物 + 地区 + 症状关键词 + 常见病虫害)
    │
    │  HTTP POST /ai/diagnose
    ▼
[Python AI Service]
    ├──→ AIProvider.chat() → 引导式问答
    └──→ 返回诊断建议
    │
    ▼
[Spring Boot] ── 匹配本地数据库补充信息 ──→ 返回
    │
    ▼
[Flutter APP] ── 诊断Agent界面展示
```

---

## 七、实施优先级

### 🔴 第三阶段立即创建 (10张核心表)

```
core.user
core.crop_category
core.crop
core.disease
core.disease_image
core.prevention_plan
core.prevention_item
core.recognition_record
core.knowledge_article
core.language_resource
```

### 🟡 第四-六阶段创建 (待语料到位)

```
extension.weather_data        ← 第四阶段(AI集成时)
extension.label_review_log    ← 第七阶段(知识库上线后)
```

### 🟢 第八阶段后创建

```
extension.data_export_log      ← 有足够数据后
extension.model_training_dataset ← 数据积累达标时
```

---

## 八、索引策略总结

| 索引类型 | 适用场景 | 示例 |
|----------|----------|------|
| B-tree (默认) | 等值查询、范围查询 | version, crop_id, status, created_at |
| GIN | 全文检索 | disease.name_zh + symptoms + tags |
| UK | 唯一约束 | user.uuid, disease_image.image_hash, recognition_record.task_id |
| 复合索引 | 高频组合查询 | (version, crop_id), (disease_id, label_status) |

---

## 九、与v1/v2版本的变更记录

| 版本 | 主要变更 |
|------|----------|
| v1 (第一阶段) | 9张表，基础设计 |
| v2 (阶段1.5) | 扩展为13张表，增加科研视角 |
| **v3 (本版本)** | 架构升级Spring Boot+AI Service; 分core/extension/audit三层schema; 10张立即创建+3张预留; 增加source_type/collector_id/approval_status字段; disease_image增加完整科研采集字段 |

---

> **下一步:** 等待确认后，第三阶段开始实现建表SQL + JPA实体类 + Alembic迁移脚本。
