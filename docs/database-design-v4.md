# 数据库架构设计 v4 — 农业数据平台最终版

> 版本: v4.0 | 日期: 2026-08-08 | 阶段: 1.6 真实交付场景重构
> 定位: 农业数字化服务平台 — 支持数据闭环、专家运营、多语言国际扩展

---

## 一、设计原则（v4升级要点）

| # | 原则 | 说明 |
|---|------|------|
| 1 | **农业数据生命周期** | 每张图片从采集→AI识别→专家审核→入库→训练数据，全程可追溯 |
| 2 | **四角色权限模型** | 管理员/专家/技术员/农户，数据可见性和操作权限不同 |
| 3 | **多语言第一公民** | 所有文本内容天然多语言，新增语言只需加翻译 |
| 4 | **数据质量分层** | S/A/B/C/D五级，自动分级+人工标注 |
| 5 | **国际化扩展预留** | country_config + language_resource 支持国家扩展 |
| 6 | **不删除原则** | 数据标记状态而非物理删除（除用户隐私请求外） |

---

## 二、数据库Schema分层

```
laos_agri (PostgreSQL 16)

├── core (核心业务 — 第三阶段创建)      10张表
├── expert (专家运营 — 第五阶段创建)     4张表
├── extension (科研扩展 — 第六阶段创建)  3张表
├── i18n (国际化 — 第七阶段创建)         2张表
└── audit (审计日志 — 后期)              2张表
```

---

## 三、core层: 核心业务表

### 表1: `core.user` — 用户

```sql
CREATE TABLE core.user (
    id              BIGSERIAL PRIMARY KEY,
    uuid            VARCHAR(36) UNIQUE NOT NULL,       -- 对外ID
    phone           VARCHAR(20),                       -- 手机号(可选,老挝格式)
    password_hash   VARCHAR(200),                      -- 密码哈希(游客为NULL)
    nickname        VARCHAR(100),
    avatar_url      VARCHAR(500),
    language_pref   VARCHAR(10) DEFAULT 'lo',          -- zh/lo/en
    region_province VARCHAR(100),                      -- 省份(老挝行政区域)
    region_district VARCHAR(100),                      -- 地区
    crop_preferences JSONB DEFAULT '[]',               -- ["白菜","番茄"]
    role            VARCHAR(30) DEFAULT 'farmer',     -- admin/expert/technician/farmer
    organization_id INT,                               -- 所属机构(FK)
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    last_login_at   TIMESTAMP
);

CREATE INDEX idx_user_role ON core.user(role);
CREATE INDEX idx_user_region ON core.user(region_province);
CREATE INDEX idx_user_phone ON core.user(phone);
```

### 表2: `core.crop_category` — 作物分类

```sql
CREATE TABLE core.crop_category (
    id          SERIAL PRIMARY KEY,
    version     VARCHAR(20) NOT NULL,          -- vegetable/fruit
    name_zh     VARCHAR(100) NOT NULL,
    name_lo     VARCHAR(200),
    name_en     VARCHAR(100),                  -- 英文(国际化预留)
    parent_id   INT REFERENCES core.crop_category(id),
    sort_order  INT DEFAULT 0,
    icon_url    VARCHAR(500),
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cc_version ON core.crop_category(version);
```

### 表3: `core.crop` — 作物

```sql
CREATE TABLE core.crop (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL,
    category_id     INT NOT NULL REFERENCES core.crop_category(id),
    name_zh         VARCHAR(100) NOT NULL,
    name_lo         VARCHAR(200),
    name_en         VARCHAR(100),
    scientific_name VARCHAR(200),
    description_zh  TEXT,
    description_lo  TEXT,
    description_en  TEXT,
    planting_info_zh TEXT,
    planting_info_lo TEXT,
    icon_url        VARCHAR(500),
    image_url       VARCHAR(500),
    disease_count   INT DEFAULT 0,
    sort_order      INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_crop_version ON core.crop(version);
CREATE INDEX idx_crop_category ON core.crop(category_id);
```

### 表4: `core.disease` — 病虫害字典 ⭐

```sql
CREATE TABLE core.disease (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL,
    crop_id         INT NOT NULL REFERENCES core.crop(id),
    
    -- 多语言名称
    name_zh         VARCHAR(200) NOT NULL,
    name_lo         VARCHAR(300),
    name_en         VARCHAR(200),
    scientific_name VARCHAR(300),
    
    -- 分类
    type            VARCHAR(20) NOT NULL CHECK (type IN ('disease','pest','physiological')),
    severity_level  VARCHAR(20) DEFAULT 'moderate' CHECK (severity_level IN ('mild','moderate','severe')),
    
    -- 症状 (多语言)
    symptoms_zh     TEXT,
    symptoms_lo     TEXT,
    symptoms_en     TEXT,
    
    -- 发病条件 (多语言)
    conditions_zh   TEXT,
    conditions_lo   TEXT,
    conditions_en   TEXT,
    
    -- 数据来源追踪
    source_type     VARCHAR(30) DEFAULT 'TEACHER_DATA' 
                    CHECK (source_type IN ('TEACHER_DATA','USER_UPLOAD','FIELD_COLLECTION','AI_GENERATED')),
    collector_id    INT REFERENCES core.user(id),
    collection_time TIMESTAMP,
    
    -- 审核状态
    approval_status VARCHAR(30) DEFAULT 'approved' 
                    CHECK (approval_status IN ('draft','pending','approved','rejected')),
    reviewed_by     INT REFERENCES core.user(id),
    reviewed_at     TIMESTAMP,
    
    -- 搜索与元数据
    tags            VARCHAR(500),
    image_count     INT DEFAULT 0,              -- 关联图片数(冗余)
    
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_disease_version ON core.disease(version);
CREATE INDEX idx_disease_crop ON core.disease(crop_id);
CREATE INDEX idx_disease_type ON core.disease(type);
CREATE INDEX idx_disease_source ON core.disease(source_type);
CREATE INDEX idx_disease_approval ON core.disease(approval_status);
CREATE INDEX idx_disease_search ON core.disease USING gin(
    to_tsvector('simple', 
        COALESCE(name_zh,'') || ' ' || COALESCE(name_lo,'') || ' ' || 
        COALESCE(name_en,'') || ' ' || COALESCE(symptoms_zh,'') || ' ' || 
        COALESCE(tags,''))
);
```

### 表5: `core.disease_image` — 病虫害图片（数据资产核心）⭐⭐⭐

```sql
CREATE TABLE core.disease_image (
    id              BIGSERIAL PRIMARY KEY,
    
    -- 图片本身
    image_url       VARCHAR(500) NOT NULL,
    thumbnail_url   VARCHAR(500),
    image_hash      VARCHAR(64),                -- SHA256去重
    file_size_bytes INT,
    
    -- 关联
    version         VARCHAR(20) NOT NULL,
    crop_id         INT REFERENCES core.crop(id),
    disease_id      INT REFERENCES core.disease(id),
    diagnosis_id    INT,                        -- 关联识别记录(FK→diagnosis_record)
    
    -- 图片分类
    image_type      VARCHAR(30) DEFAULT 'symptom',
    image_source    VARCHAR(30) DEFAULT 'TEACHER_DATA',
    source_type     VARCHAR(30) DEFAULT 'TEACHER_DATA',
    
    -- 采集元数据 (科研核心)
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    location_name   VARCHAR(300),
    taken_at        TIMESTAMP,
    
    -- 生长信息
    growth_stage    VARCHAR(50),
    plant_part      VARCHAR(50),
    
    -- 环境信息
    weather_condition VARCHAR(50),
    temperature     DECIMAL(5,2),
    humidity        DECIMAL(5,2),
    
    -- 采集者
    collector_id    INT REFERENCES core.user(id),
    collection_time TIMESTAMP,
    device_model    VARCHAR(100),
    
    -- AI标注
    ai_label        VARCHAR(300),
    ai_confidence   DECIMAL(5,4),
    
    -- 人工标注 (专家审核后)
    human_label     VARCHAR(300),
    human_label_by  INT REFERENCES core.user(id),
    label_status    VARCHAR(30) DEFAULT 'ai_only' 
                    CHECK (label_status IN ('ai_only','verified','corrected','disputed','rejected')),
    label_notes     TEXT,
    
    -- 质量
    image_quality_score DECIMAL(3,2),
    is_usable       BOOLEAN DEFAULT TRUE,
    reject_reason   VARCHAR(300),
    
    -- 数据质量等级
    data_grade      VARCHAR(5) DEFAULT 'B'       -- S/A/B/C/D
                    CHECK (data_grade IN ('S','A','B','C','D')),
    
    -- 审核
    approval_status VARCHAR(30) DEFAULT 'pending',
    reviewed_by     INT REFERENCES core.user(id),
    reviewed_at     TIMESTAMP,
    
    -- 权限
    language        VARCHAR(10) DEFAULT 'zh',
    is_public       BOOLEAN DEFAULT FALSE,
    
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_di_version ON core.disease_image(version);
CREATE INDEX idx_di_crop ON core.disease_image(crop_id);
CREATE INDEX idx_di_disease ON core.disease_image(disease_id);
CREATE INDEX idx_di_label ON core.disease_image(label_status);
CREATE INDEX idx_di_quality ON core.disease_image(data_grade);
CREATE INDEX idx_di_location ON core.disease_image(gps_latitude, gps_longitude);
CREATE INDEX idx_di_hash ON core.disease_image(image_hash);
CREATE INDEX idx_di_created ON core.disease_image(created_at DESC);
CREATE INDEX idx_di_usable ON core.disease_image(is_usable) WHERE is_usable = TRUE;
```

### 表6: `core.prevention_plan` — 防控方案

```sql
CREATE TABLE core.prevention_plan (
    id          SERIAL PRIMARY KEY,
    disease_id  INT NOT NULL REFERENCES core.disease(id) ON DELETE CASCADE,
    plan_type   VARCHAR(30) NOT NULL CHECK (plan_type IN ('chemical','biological','physical','cultivation')),
    title_zh    VARCHAR(200) NOT NULL,
    title_lo    VARCHAR(300),
    title_en    VARCHAR(200),
    sort_order  INT DEFAULT 0,
    source_type VARCHAR(30) DEFAULT 'TEACHER_DATA',
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pp_disease ON core.prevention_plan(disease_id);
```

### 表7: `core.prevention_item` — 防控措施条目

```sql
CREATE TABLE core.prevention_item (
    id          SERIAL PRIMARY KEY,
    plan_id     INT NOT NULL REFERENCES core.prevention_plan(id) ON DELETE CASCADE,
    name_zh     VARCHAR(300) NOT NULL,
    name_lo     VARCHAR(400),
    name_en     VARCHAR(300),
    usage_zh    TEXT,
    usage_lo    TEXT,
    usage_en    TEXT,
    notes_zh    TEXT,
    notes_lo    TEXT,
    sort_order  INT DEFAULT 0,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pi_plan ON core.prevention_item(plan_id);
```

### 表8: `core.diagnosis_record` — 诊断记录（识别记录升级版）

```sql
CREATE TABLE core.diagnosis_record (
    id              BIGSERIAL PRIMARY KEY,
    task_id         VARCHAR(50) UNIQUE NOT NULL,
    user_id         INT REFERENCES core.user(id),
    device_uuid     VARCHAR(100),
    
    version         VARCHAR(20) NOT NULL,
    language        VARCHAR(10) DEFAULT 'zh',
    
    -- 图片
    image_url       VARCHAR(500),
    crop_id         INT REFERENCES core.crop(id),
    
    -- AI结果
    status          VARCHAR(30) DEFAULT 'pending' 
                    CHECK (status IN ('pending','processing','completed','failed','reviewed')),
    ai_raw_response JSONB,
    parsed_results  JSONB,
    
    -- 最佳匹配
    top_disease_id  INT REFERENCES core.disease(id),
    top_confidence  DECIMAL(5,4),
    confidence_level VARCHAR(20)                -- high/medium/low
                    CHECK (confidence_level IN ('high','medium','low')),
    
    -- 用户反馈
    user_feedback   VARCHAR(20),                -- confirmed / disputed / ignored
    user_feedback_at TIMESTAMP,
    
    -- 专家审核
    expert_reviewed  BOOLEAN DEFAULT FALSE,
    expert_action    VARCHAR(30),               -- verified / corrected / rejected
    expert_disease_id INT REFERENCES core.disease(id),  -- 专家修正后的病虫害
    expert_notes     TEXT,
    reviewed_by      INT REFERENCES core.user(id),
    reviewed_at      TIMESTAMP,
    
    -- 防控方案(冗余快照)
    prevention_json JSONB,
    
    -- 采集元数据
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    location_name   VARCHAR(300),
    weather_info    JSONB,                      -- {condition, temperature, humidity}
    growth_stage    VARCHAR(50),
    plant_part      VARCHAR(50),
    
    -- 技术
    provider_used   VARCHAR(50),
    processing_time_ms INT,
    error_message   TEXT,
    device_info     VARCHAR(300),
    
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_dr_task ON core.diagnosis_record(task_id);
CREATE INDEX idx_dr_user ON core.diagnosis_record(user_id);
CREATE INDEX idx_dr_version ON core.diagnosis_record(version);
CREATE INDEX idx_dr_status ON core.diagnosis_record(status);
CREATE INDEX idx_dr_reviewed ON core.diagnosis_record(expert_reviewed) WHERE expert_reviewed = FALSE;
CREATE INDEX idx_dr_confidence ON core.diagnosis_record(confidence_level);
CREATE INDEX idx_dr_created ON core.diagnosis_record(created_at DESC);
```

### 表9: `core.knowledge_article` — 知识库文章

```sql
CREATE TABLE core.knowledge_article (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL,
    crop_id         INT REFERENCES core.crop(id),
    disease_id      INT REFERENCES core.disease(id),
    article_type    VARCHAR(30) NOT NULL CHECK (article_type IN ('disease','crop','general','faq','news')),
    
    title_zh        VARCHAR(300) NOT NULL,
    title_lo        VARCHAR(400),
    title_en        VARCHAR(300),
    
    content_zh      TEXT,
    content_lo      TEXT,
    content_en      TEXT,
    
    tags            VARCHAR(500),
    
    source_type     VARCHAR(30) DEFAULT 'TEACHER_DATA',
    is_published    BOOLEAN DEFAULT FALSE,
    published_at    TIMESTAMP,
    view_count      INT DEFAULT 0,
    
    author_id       INT REFERENCES core.user(id),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ka_version ON core.knowledge_article(version);
CREATE INDEX idx_ka_crop ON core.knowledge_article(crop_id);
CREATE INDEX idx_ka_type ON core.knowledge_article(article_type);
CREATE INDEX idx_ka_published ON core.knowledge_article(is_published) WHERE is_published = TRUE;
CREATE INDEX idx_ka_search ON core.knowledge_article USING gin(
    to_tsvector('simple', 
        COALESCE(title_zh,'') || ' ' || COALESCE(title_lo,'') || ' ' || 
        COALESCE(content_zh,'') || ' ' || COALESCE(tags,''))
);
```

### 表10: `core.language_resource` — 多语言资源

```sql
CREATE TABLE core.language_resource (
    id              SERIAL PRIMARY KEY,
    resource_key    VARCHAR(200) NOT NULL,       -- "recognition_title"
    module          VARCHAR(50) NOT NULL,        -- ui/knowledge/prevention/system
    text_zh         VARCHAR(2000),               -- 中文
    text_lo         VARCHAR(2000),              -- 老挝语
    text_en         VARCHAR(2000),              -- 英文(预留)
    text_th         VARCHAR(2000),              -- 泰语(预留)
    text_vi         VARCHAR(2000),              -- 越南语(预留)
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(resource_key, module)
);

CREATE INDEX idx_lr_module ON core.language_resource(module);
```

---

## 四、expert层: 专家运营表（第五阶段创建）

### 表11: `expert.expert_review` — 专家审核记录

```sql
CREATE TABLE expert.expert_review (
    id                  BIGSERIAL PRIMARY KEY,
    diagnosis_record_id INT NOT NULL,               -- FK→core.diagnosis_record
    disease_image_id    INT,                         -- FK→core.disease_image
    reviewer_id         INT NOT NULL,                -- FK→core.user (专家)
    
    -- AI原始结果
    ai_disease_name     VARCHAR(300),
    ai_confidence       DECIMAL(5,4),
    
    -- 专家判断
    review_action       VARCHAR(30) NOT NULL         -- verified / corrected / rejected
                        CHECK (review_action IN ('verified','corrected','rejected')),
    
    -- 如修正，记录正确结果
    corrected_disease_id INT,                        -- FK→core.disease
    corrected_disease_name VARCHAR(300),
    correction_reason   TEXT,                        -- 为什么修正
    
    -- 质量评估
    image_quality_score DECIMAL(3,2),               -- 专家评的图片质量
    severity_assessment VARCHAR(20),                 -- mild/moderate/severe
    is_usable_for_training BOOLEAN DEFAULT TRUE,
    
    -- 元数据
    review_time_seconds INT,                         -- 审核耗时(秒),用于效率统计
    notes               TEXT,
    reviewed_at         TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_er_diagnosis ON expert.expert_review(diagnosis_record_id);
CREATE INDEX idx_er_reviewer ON expert.expert_review(reviewer_id);
CREATE INDEX idx_er_action ON expert.expert_review(review_action);
CREATE INDEX idx_er_reviewed_at ON expert.expert_review(reviewed_at DESC);
```

### 表12: `expert.user_feedback` — 用户反馈

```sql
CREATE TABLE expert.user_feedback (
    id                  BIGSERIAL PRIMARY KEY,
    diagnosis_record_id INT NOT NULL,
    user_id             INT,                        -- 可为NULL(游客)
    feedback_type       VARCHAR(30) NOT NULL         -- confirmed/disputed/report_error/suggestion
                        CHECK (feedback_type IN ('confirmed','disputed','report_error','suggestion')),
    message             TEXT,
    status              VARCHAR(30) DEFAULT 'open'   -- open/in_review/resolved
                        CHECK (status IN ('open','in_review','resolved')),
    resolved_by         INT REFERENCES core.user(id),
    resolved_at         TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_uf_diagnosis ON expert.user_feedback(diagnosis_record_id);
CREATE INDEX idx_uf_status ON expert.user_feedback(status);
```

### 表13: `expert.region` — 地区字典

```sql
CREATE TABLE expert.region (
    id              SERIAL PRIMARY KEY,
    country_code    VARCHAR(5) DEFAULT 'LA',         -- LA/TH/VN...
    country_name_zh VARCHAR(100) DEFAULT '老挝',
    division_level  VARCHAR(20) DEFAULT 'province',  -- province/district
    name_zh         VARCHAR(200) NOT NULL,
    name_lo         VARCHAR(200),
    name_en         VARCHAR(200),
    parent_id       INT REFERENCES expert.region(id),
    sort_order      INT DEFAULT 0
);

CREATE INDEX idx_region_country ON expert.region(country_code);
CREATE INDEX idx_region_parent ON expert.region(parent_id);
```

### 表14: `expert.data_export_log` — 数据导出记录

```sql
CREATE TABLE expert.data_export_log (
    id              SERIAL PRIMARY KEY,
    export_type     VARCHAR(30) NOT NULL,           -- training_dataset/report/paper/excel
    export_format   VARCHAR(30) NOT NULL,           -- json/coco/yolo/csv/pdf
    record_count    INT DEFAULT 0,
    filters_applied JSONB,                           -- 筛选条件
    exported_by     INT REFERENCES core.user(id),   -- 操作人
    file_url        VARCHAR(500),
    file_size_bytes BIGINT,
    created_at      TIMESTAMP DEFAULT NOW()
);
```

---

## 五、extension层: 科研扩展表（第六阶段创建）

### 表15: `extension.weather_record` — 天气记录

```sql
CREATE TABLE extension.weather_record (
    id              BIGSERIAL PRIMARY KEY,
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    location_name   VARCHAR(300),
    temperature_max DECIMAL(5,2),
    temperature_min DECIMAL(5,2),
    temperature_avg DECIMAL(5,2),
    humidity_avg    DECIMAL(5,2),
    rainfall_mm     DECIMAL(7,2),
    weather_desc    VARCHAR(200),
    recorded_date   DATE NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_wr_date ON extension.weather_record(recorded_date);
CREATE INDEX idx_wr_location ON extension.weather_record(gps_latitude, gps_longitude);
```

### 表16: `extension.training_dataset` — 训练数据集

```sql
CREATE TABLE extension.training_dataset (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    version_tag     VARCHAR(50),                    -- v1.0, v1.1
    data_grade_filter VARCHAR(20) DEFAULT 'S,A',    -- 包含哪些质量等级
    image_count     INT DEFAULT 0,
    class_count     INT DEFAULT 0,                   -- 病虫害类别数
    export_format   VARCHAR(30),                    -- yolo/coco/classification
    export_url      VARCHAR(500),
    description     TEXT,
    created_by      INT REFERENCES core.user(id),
    created_at      TIMESTAMP DEFAULT NOW()
);
```

### 表17: `extension.model_version` — AI模型版本

```sql
CREATE TABLE extension.model_version (
    id              SERIAL PRIMARY KEY,
    model_name      VARCHAR(200) NOT NULL,          -- "laos_veggie_classifier"
    version_tag     VARCHAR(50) NOT NULL,           -- "v1.0"
    base_architecture VARCHAR(100),                 -- "ResNet50" / "YOLOv8" / "EfficientNet-B3"
    training_dataset_id INT REFERENCES extension.training_dataset(id),
    train_samples   INT DEFAULT 0,
    val_samples     INT DEFAULT 0,
    accuracy        DECIMAL(5,4),
    f1_score        DECIMAL(5,4),
    model_file_url  VARCHAR(500),
    is_deployed     BOOLEAN DEFAULT FALSE,
    deployed_at     TIMESTAMP,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);
```

---

## 六、i18n层: 国际化表（第七阶段创建）

### 表18: `i18n.country_config` — 国家配置

```sql
CREATE TABLE i18n.country_config (
    id              SERIAL PRIMARY KEY,
    country_code    VARCHAR(5) UNIQUE NOT NULL,     -- LA/TH/VN/KH/MM
    country_name_zh VARCHAR(100),
    country_name_en VARCHAR(100),
    default_language VARCHAR(10) DEFAULT 'lo',
    supported_languages TEXT[] DEFAULT '{}',        -- {zh,lo,en}
    default_crops   TEXT[] DEFAULT '{}',            -- 默认作物列表
    currency        VARCHAR(10),                    -- LAK/THB/VND
    timezone        VARCHAR(50),                    -- Asia/Vientiane
    is_active       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW()
);
```

### 表19: `i18n.translation_audit` — 翻译审计

```sql
CREATE TABLE i18n.translation_audit (
    id              SERIAL PRIMARY KEY,
    resource_id     INT REFERENCES core.language_resource(id),
    language_code   VARCHAR(10),                    -- lo/en/th/vi
    action          VARCHAR(20),                    -- added/updated/reviewed
    old_text        VARCHAR(2000),
    new_text        VARCHAR(2000),
    changed_by      INT REFERENCES core.user(id),
    changed_at      TIMESTAMP DEFAULT NOW()
);
```

---

## 七、完整ER图

```
                          ┌────────────────────┐
                          │   core.user        │
                          │  (用户-4角色)       │
                          └─────────┬──────────┘
                                    │
     ┌──────────┬──────────┬───────┼───────┬──────────┬──────────┐
     │          │          │       │       │          │          │
     ▼          ▼          ▼       ▼       ▼          ▼          ▼
┌─────────┐ ┌─────────┐ ┌─────────────┐ ┌──────────┐ ┌──────────────┐
│ crop    │ │ disease │ │diagnosis    │ │knowledge │ │disease_image │
│_category│ │(病虫害) │ │_record      │ │_article  │ │(⭐数据核心)   │
└────┬────┘ └────┬────┘ │(诊断记录)   │ │(知识库)  │ └──────┬───────┘
     │          │       └──────┬──────┘ └──────────┘        │
     ▼          │              │                            │
┌─────────┐    │       ┌──────┴──────┐                     │
│ crop    │◄───┘       │             │                     │
│(作物)   │            ▼             ▼                     │
└─────────┘     ┌──────────┐  ┌──────────┐                │
                │prevention│  │ expert   │                │
                │_plan+item│  │_review   │◄───────────────┘
                │(防控方案)│  │(专家审核) │
                └──────────┘  └──────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
         ▼                          ▼                          ▼
  ┌──────────────┐         ┌──────────────┐          ┌──────────────┐
  │ user_feedback│         │ data_export  │          │ training     │
  │ (用户反馈)   │         │ _log (导出)  │          │ _dataset     │
  └──────────────┘         └──────────────┘          │ (训练集)     │
                                                      └──────────────┘
```

---

## 八、实施计划

### 🔴 第三阶段立即创建 (core层, 10张表)

```
core.user
core.crop_category
core.crop
core.disease
core.disease_image
core.prevention_plan
core.prevention_item
core.diagnosis_record
core.knowledge_article
core.language_resource
```

### 🟡 第五阶段创建 (expert层, 4张表)

```
expert.expert_review
expert.user_feedback
expert.region
expert.data_export_log
```

### 🟢 第六阶段创建 (extension层, 3张表)

```
extension.weather_record
extension.training_dataset
extension.model_version
```

### 第七阶段创建 (i18n层, 2张表)

```
i18n.country_config
i18n.translation_audit
```

---

## 九、v3 → v4 变更总结

| 变更项 | v3 | v4 |
|--------|-----|-----|
| **表数量** | 13张 | 19张(分4层,渐进创建) |
| **多语言字段** | _zh/_lo | _zh/_lo/_en (国际化预留) |
| **diagnosis_record** | recognition_record | 诊断记录(含用户反馈+专家审核字段) |
| **数据质量** | label_status | + data_grade(S/A/B/C/D) |
| **用户角色** | role字段 | role(4角色) + 专家审核链路 |
| **国际化** | 无 | country_config + translation_audit |
| **训练数据** | 无 | training_dataset + model_version |
| **新增表** | - | expert_review/user_feedback/region/country_config |

---

> **下一步: 确认 → 第三阶段实现 (建表SQL + JPA实体 + Spring Boot项目初始化)**
