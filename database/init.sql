-- ==========================================
-- 中老双语农业病虫害防控平台 — 数据库初始化
-- 目标: PostgreSQL 16, schema: core
-- 核心业务表 (10张) — 第三阶段立即创建
-- ==========================================

-- 创建schema
CREATE SCHEMA IF NOT EXISTS core;
COMMENT ON SCHEMA core IS '核心业务数据 — 用户、作物、病虫害、诊断、知识库';

-- ==========================================
-- 1. core.user — 用户表
-- ==========================================
CREATE TABLE core."user" (
    id              BIGSERIAL PRIMARY KEY,
    uuid            VARCHAR(36) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    password_hash   VARCHAR(200),
    nickname        VARCHAR(100),
    avatar_url      VARCHAR(500),
    language_pref   VARCHAR(10) DEFAULT 'lo',
    region_province VARCHAR(100),
    region_district VARCHAR(100),
    crop_preferences JSONB DEFAULT '[]',
    role            VARCHAR(30) DEFAULT 'FARMER' CHECK (role IN ('ADMIN','EXPERT','TECHNICIAN','FARMER')),
    organization_id BIGINT,
    is_active       BOOLEAN DEFAULT TRUE,
    last_login_at   TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_user_role ON core."user"(role);
CREATE INDEX idx_user_region ON core."user"(region_province);
CREATE INDEX idx_user_phone ON core."user"(phone);

-- ==========================================
-- 2. core.crop_category — 作物分类
-- ==========================================
CREATE TABLE core.crop_category (
    id          SERIAL PRIMARY KEY,
    version     VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
    name_zh     VARCHAR(100) NOT NULL,
    name_lo     VARCHAR(200),
    name_en     VARCHAR(100),
    parent_id   INT REFERENCES core.crop_category(id),
    sort_order  INT DEFAULT 0,
    icon_url    VARCHAR(500),
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_cc_version ON core.crop_category(version);

-- ==========================================
-- 3. core.crop — 作物表
-- ==========================================
CREATE TABLE core.crop (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
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

-- ==========================================
-- 4. core.disease — 病虫害字典 ⭐
-- ==========================================
CREATE TABLE core.disease (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
    crop_id         INT NOT NULL REFERENCES core.crop(id),
    name_zh         VARCHAR(200) NOT NULL,
    name_lo         VARCHAR(300),
    name_en         VARCHAR(200),
    scientific_name VARCHAR(300),
    type            VARCHAR(20) NOT NULL CHECK (type IN ('disease','pest','physiological')),
    severity_level  VARCHAR(20) DEFAULT 'moderate' CHECK (severity_level IN ('mild','moderate','severe')),
    symptoms_zh     TEXT,
    symptoms_lo     TEXT,
    symptoms_en     TEXT,
    conditions_zh   TEXT,
    conditions_lo   TEXT,
    conditions_en   TEXT,
    source_type     VARCHAR(30) DEFAULT 'TEACHER_DATA' CHECK (source_type IN ('TEACHER_DATA','USER_UPLOAD','FIELD_COLLECTION','AI_GENERATED')),
    collector_id    INT REFERENCES core."user"(id),
    collection_time TIMESTAMP,
    approval_status VARCHAR(30) DEFAULT 'approved' CHECK (approval_status IN ('draft','pending','approved','rejected')),
    reviewed_by     INT REFERENCES core."user"(id),
    reviewed_at     TIMESTAMP,
    tags            VARCHAR(500),
    image_count     INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_disease_version ON core.disease(version);
CREATE INDEX idx_disease_crop ON core.disease(crop_id);
CREATE INDEX idx_disease_type ON core.disease(type);
CREATE INDEX idx_disease_source ON core.disease(source_type);
CREATE INDEX idx_disease_search ON core.disease USING gin(to_tsvector('simple',
    COALESCE(name_zh,'') || ' ' || COALESCE(name_lo,'') || ' ' || COALESCE(symptoms_zh,'') || ' ' || COALESCE(tags,'')));

-- ==========================================
-- 5. core.disease_image — 病虫害图片(数据核心) ⭐⭐⭐
-- ==========================================
CREATE TABLE core.disease_image (
    id              BIGSERIAL PRIMARY KEY,
    image_url       VARCHAR(500) NOT NULL,
    thumbnail_url   VARCHAR(500),
    image_hash      VARCHAR(64),
    file_size_bytes INT,
    version         VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
    crop_id         INT REFERENCES core.crop(id),
    disease_id      INT REFERENCES core.disease(id),
    diagnosis_id    BIGINT,
    image_type      VARCHAR(30) DEFAULT 'symptom',
    image_source    VARCHAR(30) DEFAULT 'TEACHER_DATA',
    source_type     VARCHAR(30) DEFAULT 'TEACHER_DATA' CHECK (source_type IN ('TEACHER_DATA','USER_UPLOAD','FIELD_COLLECTION','AI_GENERATED')),
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    location_name   VARCHAR(300),
    taken_at        TIMESTAMP,
    growth_stage    VARCHAR(50),
    plant_part      VARCHAR(50),
    weather_condition VARCHAR(50),
    temperature     DECIMAL(5,2),
    humidity        DECIMAL(5,2),
    collector_id    INT REFERENCES core."user"(id),
    collection_time TIMESTAMP,
    device_model    VARCHAR(100),
    ai_label        VARCHAR(300),
    ai_confidence   DECIMAL(5,4),
    human_label     VARCHAR(300),
    human_label_by  INT REFERENCES core."user"(id),
    label_status    VARCHAR(30) DEFAULT 'ai_only' CHECK (label_status IN ('ai_only','verified','corrected','disputed','rejected')),
    label_notes     TEXT,
    image_quality_score DECIMAL(3,2),
    is_usable       BOOLEAN DEFAULT TRUE,
    reject_reason   VARCHAR(300),
    data_grade      VARCHAR(5) DEFAULT 'B' CHECK (data_grade IN ('S','A','B','C','D')),
    approval_status VARCHAR(30) DEFAULT 'pending',
    reviewed_by     INT REFERENCES core."user"(id),
    reviewed_at     TIMESTAMP,
    language        VARCHAR(10) DEFAULT 'zh',
    is_public       BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_di_version ON core.disease_image(version);
CREATE INDEX idx_di_disease ON core.disease_image(disease_id);
CREATE INDEX idx_di_label ON core.disease_image(label_status);
CREATE INDEX idx_di_quality ON core.disease_image(data_grade);
CREATE INDEX idx_di_location ON core.disease_image(gps_latitude, gps_longitude);
CREATE INDEX idx_di_hash ON core.disease_image(image_hash);
CREATE INDEX idx_di_created ON core.disease_image(created_at DESC);
CREATE INDEX idx_di_usable ON core.disease_image(is_usable) WHERE is_usable = TRUE;

-- ==========================================
-- 6. core.prevention_plan — 防控方案
-- ==========================================
CREATE TABLE core.prevention_plan (
    id          SERIAL PRIMARY KEY,
    disease_id  INT NOT NULL REFERENCES core.disease(id) ON DELETE CASCADE,
    plan_type   VARCHAR(30) NOT NULL CHECK (plan_type IN ('chemical','biological','physical','cultivation')),
    title_zh    VARCHAR(200) NOT NULL,
    title_lo    VARCHAR(300),
    title_en    VARCHAR(200),
    sort_order  INT DEFAULT 0,
    source_type VARCHAR(30) DEFAULT 'TEACHER_DATA',
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_pp_disease ON core.prevention_plan(disease_id);

-- ==========================================
-- 7. core.prevention_item — 防控措施条目
-- ==========================================
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
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_pi_plan ON core.prevention_item(plan_id);

-- ==========================================
-- 8. core.diagnosis_record — 诊断记录
-- ==========================================
CREATE TABLE core.diagnosis_record (
    id              BIGSERIAL PRIMARY KEY,
    task_id         VARCHAR(50) UNIQUE NOT NULL,
    user_id         BIGINT REFERENCES core."user"(id),
    device_uuid     VARCHAR(100),
    version         VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
    language        VARCHAR(10) DEFAULT 'zh',
    image_url       VARCHAR(500),
    crop_id         INT REFERENCES core.crop(id),
    status          VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed','reviewed')),
    ai_raw_response JSONB,
    parsed_results  JSONB,
    top_disease_id  INT REFERENCES core.disease(id),
    top_confidence  DECIMAL(5,4),
    confidence_level VARCHAR(20) CHECK (confidence_level IN ('high','medium','low')),
    user_feedback   VARCHAR(20) CHECK (user_feedback IN ('confirmed','disputed','ignored')),
    user_feedback_at TIMESTAMP,
    expert_reviewed BOOLEAN DEFAULT FALSE,
    expert_action   VARCHAR(30) CHECK (expert_action IN ('verified','corrected','rejected')),
    expert_disease_id INT REFERENCES core.disease(id),
    expert_notes    TEXT,
    reviewed_by     BIGINT REFERENCES core."user"(id),
    reviewed_at     TIMESTAMP,
    prevention_json JSONB,
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    location_name   VARCHAR(300),
    weather_info    JSONB,
    growth_stage    VARCHAR(50),
    plant_part      VARCHAR(50),
    provider_used   VARCHAR(50),
    processing_time_ms INT,
    error_message   TEXT,
    device_info     VARCHAR(300),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_dr_task ON core.diagnosis_record(task_id);
CREATE INDEX idx_dr_user ON core.diagnosis_record(user_id);
CREATE INDEX idx_dr_version ON core.diagnosis_record(version);
CREATE INDEX idx_dr_status ON core.diagnosis_record(status);
CREATE INDEX idx_dr_reviewed ON core.diagnosis_record(expert_reviewed) WHERE expert_reviewed = FALSE;
CREATE INDEX idx_dr_confidence ON core.diagnosis_record(confidence_level);
CREATE INDEX idx_dr_created ON core.diagnosis_record(created_at DESC);

-- ==========================================
-- 9. core.knowledge_article — 知识库文章
-- ==========================================
CREATE TABLE core.knowledge_article (
    id              SERIAL PRIMARY KEY,
    version         VARCHAR(20) NOT NULL CHECK (version IN ('vegetable','fruit')),
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
    author_id       BIGINT REFERENCES core."user"(id),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_ka_version ON core.knowledge_article(version);
CREATE INDEX idx_ka_crop ON core.knowledge_article(crop_id);
CREATE INDEX idx_ka_type ON core.knowledge_article(article_type);
CREATE INDEX idx_ka_published ON core.knowledge_article(is_published) WHERE is_published = TRUE;
CREATE INDEX idx_ka_search ON core.knowledge_article USING gin(to_tsvector('simple',
    COALESCE(title_zh,'') || ' ' || COALESCE(title_lo,'') || ' ' || COALESCE(content_zh,'') || ' ' || COALESCE(tags,'')));

-- ==========================================
-- 10. core.language_resource — 多语言资源
-- ==========================================
CREATE TABLE core.language_resource (
    id              SERIAL PRIMARY KEY,
    resource_key    VARCHAR(200) NOT NULL,
    module          VARCHAR(50) NOT NULL CHECK (module IN ('ui','knowledge','prevention','system')),
    text_zh         VARCHAR(2000),
    text_lo         VARCHAR(2000),
    text_en         VARCHAR(2000),
    text_th         VARCHAR(2000),
    text_vi         VARCHAR(2000),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(resource_key, module)
);
CREATE INDEX idx_lr_module ON core.language_resource(module);

-- ==========================================
-- 种子数据: 默认管理员
-- ==========================================
INSERT INTO core."user" (uuid, phone, nickname, role, language_pref)
VALUES ('admin-0000-0000-0000-000000000001', 'admin', '平台管理员', 'ADMIN', 'zh')
ON CONFLICT (uuid) DO NOTHING;
