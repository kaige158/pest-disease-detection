-- ==========================================
-- Sprint 11: 训练数据资产表
-- ==========================================

-- 1. training_dataset — 可训练图片资产主表
CREATE TABLE IF NOT EXISTS extension.training_dataset (
    id              BIGSERIAL PRIMARY KEY,
    -- 唯一标识
    asset_id        VARCHAR(100) UNIQUE NOT NULL,  -- LA_TOMATO_2026_001
    -- 来源关联
    image_id        BIGINT REFERENCES core.disease_image(id),
    diagnosis_id    BIGINT REFERENCES core.diagnosis_record(id),
    -- 农业信息
    crop_id         INT REFERENCES core.crop(id),
    crop_zh         VARCHAR(100),
    crop_lo         VARCHAR(200),
    disease_id      INT REFERENCES core.disease(id),
    disease_zh      VARCHAR(300),                  -- 最终标签（专家确认）
    disease_lo      VARCHAR(300),
    disease_type    VARCHAR(30) DEFAULT 'disease',  -- disease/pest/physiological
    plant_part      VARCHAR(50),                    -- leaf/fruit/stem/root/whole
    severity        VARCHAR(20) DEFAULT 'moderate', -- mild/moderate/severe
    -- 地理信息
    country         VARCHAR(10) DEFAULT 'LA',
    location_name   VARCHAR(300),
    gps_latitude    DECIMAL(10,7),
    gps_longitude   DECIMAL(10,7),
    -- 生长信息
    growth_stage    VARCHAR(50),     -- seedling/vegetative/flowering/fruiting/harvesting
    season          VARCHAR(20),     -- dry/rain
    -- AI预测信息
    ai_prediction   VARCHAR(300),
    ai_confidence   DECIMAL(5,4),
    ai_model        VARCHAR(100),    -- gemini-3.6-flash / kimi-k2.6 等
    ai_raw_response TEXT,            -- AI完整原始响应(JSON)
    -- 专家确认（核心）
    expert_label    VARCHAR(300),    -- 专家标注的正确标签
    expert_label_lo VARCHAR(300),
    expert_confirm  BOOLEAN DEFAULT FALSE,  -- 专家是否确认
    expert_id       BIGINT REFERENCES core."user"(id),
    expert_notes    TEXT,
    reviewed_at     TIMESTAMP,
    -- 训练就绪标记 ⭐
    training_ready  BOOLEAN DEFAULT FALSE,  -- 只有专家确认+质量达标才为true
    training_split  VARCHAR(20),            -- train/val/test (导出时分配)
    -- 图片文件
    image_path      VARCHAR(500),
    image_quality_score DECIMAL(3,1),
    image_width     INT,
    image_height    INT,
    file_size_bytes BIGINT,
    -- 元数据
    export_batch    VARCHAR(100),    -- 导出批次ID
    exported_at     TIMESTAMP,       -- 上次导出时间
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_td_training_ready ON extension.training_dataset(training_ready) WHERE training_ready = TRUE;
CREATE INDEX IF NOT EXISTS idx_td_crop ON extension.training_dataset(crop_id);
CREATE INDEX IF NOT EXISTS idx_td_disease ON extension.training_dataset(disease_id);
CREATE INDEX IF NOT EXISTS idx_td_expert_confirm ON extension.training_dataset(expert_confirm);
CREATE INDEX IF NOT EXISTS idx_td_country ON extension.training_dataset(country);
CREATE INDEX IF NOT EXISTS idx_td_ai_model ON extension.training_dataset(ai_model);
CREATE INDEX IF NOT EXISTS idx_td_export_batch ON extension.training_dataset(export_batch);

COMMENT ON TABLE extension.training_dataset IS '农业AI训练数据资产 — 只有专家确认+质量达标的数据才能导出训练';
COMMENT ON COLUMN extension.training_dataset.training_ready IS '⭐ 核心标记: AI识别默认false → 专家审核通过+质量达标 → true';
COMMENT ON COLUMN extension.training_dataset.expert_confirm IS '专家是否确认标签正确';
COMMENT ON COLUMN extension.training_dataset.training_split IS '数据集分割: train/val/test';

-- 2. 训练数据导出批次表
CREATE TABLE IF NOT EXISTS extension.training_export_job (
    id              BIGSERIAL PRIMARY KEY,
    batch_id        VARCHAR(100) UNIQUE NOT NULL,
    export_format   VARCHAR(20) NOT NULL DEFAULT 'yolo',  -- yolo/coco/classification
    filter_criteria JSONB,               -- 导出筛选条件
    total_images    INT,
    train_count     INT,
    val_count       INT,
    test_count      INT,
    export_path     VARCHAR(500),
    manifest_path   VARCHAR(500),        -- 导出清单文件
    status          VARCHAR(30) DEFAULT 'pending',  -- pending/processing/completed/failed
    error_message   TEXT,
    exported_by     BIGINT REFERENCES core."user"(id),
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tej_batch ON extension.training_export_job(batch_id);
CREATE INDEX IF NOT EXISTS idx_tej_status ON extension.training_export_job(status);

COMMENT ON TABLE extension.training_export_job IS '训练数据导出任务记录';

-- 3. disease_image 表增强 — 新增 training_ready 字段
ALTER TABLE core.disease_image ADD COLUMN IF NOT EXISTS training_ready BOOLEAN DEFAULT FALSE;
ALTER TABLE core.disease_image ADD COLUMN IF NOT EXISTS training_dataset_id BIGINT REFERENCES extension.training_dataset(id);

COMMENT ON COLUMN core.disease_image.training_ready IS '⭐ 可用于模型训练: 需专家确认+质量达标';
COMMENT ON COLUMN core.disease_image.training_dataset_id IS '关联的训练数据资产';

-- 4. 视图：训练就绪数据统计
CREATE OR REPLACE VIEW extension.v_training_stats AS
SELECT
    crop_zh,
    disease_zh,
    disease_type,
    country,
    COUNT(*) as total,
    SUM(CASE WHEN training_ready THEN 1 ELSE 0 END) as ready_count,
    SUM(CASE WHEN expert_confirm THEN 1 ELSE 0 END) as confirmed_count,
    ROUND(AVG(ai_confidence)::numeric, 3) as avg_confidence,
    ROUND(AVG(image_quality_score)::numeric, 1) as avg_quality
FROM extension.training_dataset
WHERE is_active = TRUE
GROUP BY crop_zh, disease_zh, disease_type, country
ORDER BY ready_count DESC;
