# 数据库ER设计

> 版本: v1.0 | 数据库: PostgreSQL | 双版本: 蔬菜版/果树版共用表结构，通过version字段区分

---

## 1. ER总图

```
┌──────────┐       ┌──────────────┐       ┌──────────────┐
│   crop   │──┐    │   disease    │──┐    │  prevention  │
│  (作物)   │  │    │  (病虫害)    │  │    │  (防控方案)   │
└──────────┘  │    └──────────────┘  │    └──────────────┘
  │           │          │           │          │
  │ 1:N       │          │ 1:1       │          │
  ↓           │          ↓           │          │
┌──────────┐  │    ┌──────────────┐  │    ┌──────────────┐
│crop_     │  │    │disease_      │  │    │prevention_   │
│category  │  │    │image         │  │    │item          │
│(作物分类) │  │    │(病虫害图片)   │  │    │(防控措施条目) │
└──────────┘  │    └──────────────┘  │    └──────────────┘
              │                      │
              │    ┌──────────────┐  │
              │    │  knowledge   │  │
              │    │  (知识条目)   │──┘
              │    └──────────────┘
              │
              │    ┌──────────────┐       ┌──────────────┐
              └───→│ recognition  │       │  chat_log    │
                   │  _record     │       │  (对话记录)   │
                   │  (识别记录)   │       └──────────────┘
                   └──────────────┘
```

---

## 2. 核心表设计

### 2.1 crop_category（作物分类表）

```sql
CREATE TABLE crop_category (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20)  NOT NULL,   -- 'vegetable' | 'fruit'
    name_zh         VARCHAR(100) NOT NULL,   -- 如: "茄果类"
    name_lo         VARCHAR(200),            -- 老挝语名称
    parent_id       INT REFERENCES crop_category(id), -- 父分类，支持二级
    sort_order      INT DEFAULT 0,           -- 排序
    icon_url        VARCHAR(500),            -- 分类图标
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_category_version ON crop_category(version);
CREATE INDEX idx_category_parent ON crop_category(parent_id);
```

### 2.2 crop（作物表）

```sql
CREATE TABLE crop (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20)  NOT NULL,   -- 'vegetable' | 'fruit'
    category_id     INT NOT NULL REFERENCES crop_category(id),
    name_zh         VARCHAR(100) NOT NULL,   -- "番茄"
    name_lo         VARCHAR(200),            -- "ໝາກເລັ່ນ"
    scientific_name VARCHAR(200),            -- 学名
    description_zh  TEXT,                    -- 作物简介
    description_lo  TEXT,
    planting_info_zh TEXT,                   -- 种植信息
    planting_info_lo TEXT,
    icon_url        VARCHAR(500),
    image_url       VARCHAR(500),
    sort_order      INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_crop_version ON crop(version);
CREATE INDEX idx_crop_category ON crop(category_id);
```

### 2.3 disease（病虫害表）⭐ 核心表

```sql
CREATE TABLE disease (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20)  NOT NULL,   -- 'vegetable' | 'fruit'
    crop_id         INT NOT NULL REFERENCES crop(id),
    name_zh         VARCHAR(200) NOT NULL,   -- "番茄晚疫病"
    name_lo         VARCHAR(300),            -- 老挝语名称
    scientific_name VARCHAR(300),            -- 病原菌学名
    type            VARCHAR(20)  NOT NULL,   -- 'disease'(病害) | 'pest'(虫害)
    
    -- 症状描述
    symptoms_zh     TEXT,
    symptoms_lo     TEXT,
    
    -- 发病条件
    conditions_zh   TEXT,
    conditions_lo   TEXT,
    
    -- 严重程度参考
    severity_level  VARCHAR(20) DEFAULT 'moderate', -- mild/moderate/severe
    
    -- 防控方案（作为JSON冗余存储，也有关联表查询）
    prevention_json JSONB,                  -- 防控方案JSON（冗余，加速查询）
    
    -- 元数据
    tags            VARCHAR(500),           -- 搜索标签，逗号分隔
    source          VARCHAR(200),           -- 数据来源
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_disease_version ON disease(version);
CREATE INDEX idx_disease_crop ON disease(crop_id);
CREATE INDEX idx_disease_type ON disease(type);
CREATE INDEX idx_disease_name_search ON disease USING gin(
    to_tsvector('simple', COALESCE(name_zh, '') || ' ' || COALESCE(name_lo, '') || ' ' || 
                          COALESCE(symptoms_zh, '') || ' ' || COALESCE(tags, ''))
);
```

### 2.4 disease_image（病虫害图片表）

```sql
CREATE TABLE disease_image (
    id              SERIAL PRIMARY KEY,
    disease_id      INT NOT NULL REFERENCES disease(id) ON DELETE CASCADE,
    image_url       VARCHAR(500) NOT NULL,   -- 图片URL
    thumbnail_url   VARCHAR(500),            -- 缩略图URL
    image_type      VARCHAR(20) DEFAULT 'symptom', -- 'symptom'(症状) | 'leaf'(叶片) | 'fruit'(果实) | 'whole'(整株)
    description_zh  VARCHAR(300),
    description_lo  VARCHAR(300),
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_disease_image_disease ON disease_image(disease_id);
```

### 2.5 prevention_plan（防控方案表）

```sql
CREATE TABLE prevention_plan (
    id              SERIAL PRIMARY KEY,
    disease_id      INT NOT NULL REFERENCES disease(id) ON DELETE CASCADE,
    plan_type       VARCHAR(30) NOT NULL,    -- 'chemical'(化学) | 'biological'(生物) | 'physical'(物理) | 'cultivation'(栽培管理)
    title_zh        VARCHAR(200) NOT NULL,   -- "化学防治"
    title_lo        VARCHAR(300),
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_prevention_disease ON prevention_plan(disease_id);
```

### 2.6 prevention_item（防控措施条目表）

```sql
CREATE TABLE prevention_item (
    id              SERIAL PRIMARY KEY,
    plan_id         INT NOT NULL REFERENCES prevention_plan(id) ON DELETE CASCADE,
    name_zh         VARCHAR(300) NOT NULL,   -- "58%甲霜灵锰锌可湿性粉剂500倍液"
    name_lo         VARCHAR(400),
    usage_zh        TEXT,                    -- "每7天喷1次，连喷2-3次"
    usage_lo        TEXT,
    notes_zh        TEXT,                    -- 注意事项
    notes_lo        TEXT,
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_prevention_item_plan ON prevention_item(plan_id);
```

### 2.7 knowledge_entry（知识库条目表）

```sql
CREATE TABLE knowledge_entry (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL,    -- 'vegetable' | 'fruit'
    crop_id         INT REFERENCES crop(id),
    disease_id      INT REFERENCES disease(id), -- 可为NULL（纯知识条目）
    entry_type      VARCHAR(30) NOT NULL,    -- 'disease'(病虫害) | 'crop'(作物介绍) | 'general'(通用知识) | 'faq'(常见问题)
    title_zh        VARCHAR(300) NOT NULL,
    title_lo        VARCHAR(400),
    content_zh      TEXT,
    content_lo      TEXT,
    tags            VARCHAR(500),            -- 搜索标签
    source          VARCHAR(200),
    is_published    BOOLEAN DEFAULT FALSE,
    view_count      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_knowledge_version ON knowledge_entry(version);
CREATE INDEX idx_knowledge_crop ON knowledge_entry(crop_id);
CREATE INDEX idx_knowledge_type ON knowledge_entry(entry_type);
CREATE INDEX idx_knowledge_search ON knowledge_entry USING gin(
    to_tsvector('simple', COALESCE(title_zh, '') || ' ' || COALESCE(title_lo, '') || ' ' ||
                          COALESCE(content_zh, '') || ' ' || COALESCE(tags, ''))
);
```

### 2.8 recognition_record（识别记录表）

```sql
CREATE TABLE recognition_record (
    id              SERIAL PRIMARY KEY,
    task_id         VARCHAR(50) UNIQUE NOT NULL, -- 任务编号 rec_20260808_001
    version         VARCHAR(20) NOT NULL,         -- 'vegetable' | 'fruit'
    image_url       VARCHAR(500),                 -- 上传的原图URL
    language        VARCHAR(10) DEFAULT 'zh',     -- 请求语言
    status          VARCHAR(20) DEFAULT 'pending', -- pending/processing/completed/failed
    
    -- AI返回的原始结果(JSON)
    ai_raw_response JSONB,
    
    -- 解析后的结果(JSON)
    parsed_results  JSONB,                       -- [{rank, disease_id, name_zh, confidence, ...}]
    
    -- 最匹配的结果(冗余，方便查询)
    top_disease_id  INT REFERENCES disease(id),
    top_confidence  DECIMAL(5,4),
    
    error_message   TEXT,                        -- 失败时的错误信息
    provider_used   VARCHAR(50),                 -- 使用的AI Provider
    processing_time_ms INT,                      -- 处理耗时(毫秒)
    
    device_info     VARCHAR(300),                -- 设备信息
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_rec_task ON recognition_record(task_id);
CREATE INDEX idx_rec_version ON recognition_record(version);
CREATE INDEX idx_rec_status ON recognition_record(status);
CREATE INDEX idx_rec_created ON recognition_record(created_at DESC);
```

### 2.9 chat_log（对话记录表）— 可选

```sql
CREATE TABLE chat_log (
    id              SERIAL PRIMARY KEY,
    session_id      VARCHAR(50) NOT NULL,
    version         VARCHAR(20) NOT NULL,        -- 'vegetable' | 'fruit'
    language        VARCHAR(10) DEFAULT 'zh',
    role            VARCHAR(20) NOT NULL,         -- 'user' | 'assistant'
    message         TEXT NOT NULL,
    related_disease_ids INT[] DEFAULT '{}',      -- AI回复关联的病虫害ID
    provider_used   VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_chat_session ON chat_log(session_id);
CREATE INDEX idx_chat_version ON chat_log(version);
CREATE INDEX idx_chat_created ON chat_log(created_at DESC);
```

---

## 3. 表关系概览

```
crop_category (1) ──→ (N) crop
crop (1) ──→ (N) disease
disease (1) ──→ (N) disease_image
disease (1) ──→ (N) prevention_plan
prevention_plan (1) ──→ (N) prevention_item
disease (1) ──→ (N) knowledge_entry  (optional)
crop (1) ──→ (N) knowledge_entry  (optional)
disease (1) ──→ (N) recognition_record (optional)
```

---

## 4. 蔬菜版 vs 果树版 数据隔离策略

**方案：共表分数据（通过 version 字段）**

```sql
-- 所有业务表都有 version 字段
-- 蔬菜版: version = 'vegetable'
-- 果树版: version = 'fruit'

-- 查询时始终带上 version 条件
SELECT * FROM disease WHERE version = 'vegetable' AND crop_id = 1;

-- 两种版本的数据物理隔离清晰，查询简单
-- 后期如需独立部署，可按 version 导出/迁移
```

**优点：**
- 数据库结构统一，维护一套迁移脚本
- 后端代码一套，只通过参数区分
- 后期可轻松拆分为两个独立数据库

---

## 5. 种子数据规划

由老师提供的语料，需要整理为以下格式导入：

| 数据类型 | 来源 | 导入目标表 |
|----------|------|-----------|
| 作物分类列表 | 老师提供 | crop_category |
| 作物列表 | 老师提供 | crop |
| 病虫害数据(含图片) | 老师提供 | disease + disease_image |
| 防控方案 | 老师提供 | prevention_plan + prevention_item |
| 知识库内容 | 老师提供 | knowledge_entry |

**导入方式：** 提供管理后台页面 or 数据导入脚本（CSV/JSON → PostgreSQL）

---

> 下一步：确认技术选型 → 开发环境准备
