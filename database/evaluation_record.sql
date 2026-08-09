-- ==========================================
-- Sprint 10.2: AI评估体系 — evaluation_record表
-- 用于追踪AI诊断准确率，积累训练数据
-- ==========================================

CREATE TABLE IF NOT EXISTS expert.evaluation_record (
    id              BIGSERIAL PRIMARY KEY,
    diagnosis_id    BIGINT REFERENCES core.diagnosis_record(id),
    ai_prediction   VARCHAR(300),           -- AI预测的病虫害名
    ai_confidence   DECIMAL(5,4),           -- AI置信度
    expert_label     VARCHAR(300),           -- 专家标注的正确病虫害名
    expert_disease_id INT REFERENCES core.disease(id),  -- 正确的病虫害ID
    is_correct      BOOLEAN NOT NULL,        -- AI是否正确
    is_top3_correct BOOLEAN,                 -- Top3中是否包含正确答案
    crop_id         INT REFERENCES core.crop(id),
    provider_used   VARCHAR(50),            -- 使用的AI Provider
    evaluation_batch VARCHAR(100),           -- 评估批次ID
    evaluated_by    BIGINT REFERENCES core.user(id),
    evaluated_at    TIMESTAMP DEFAULT NOW(),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_eval_diagnosis ON expert.evaluation_record(diagnosis_id);
CREATE INDEX IF NOT EXISTS idx_eval_correct ON expert.evaluation_record(is_correct);
CREATE INDEX IF NOT EXISTS idx_eval_provider ON expert.evaluation_record(provider_used);
CREATE INDEX IF NOT EXISTS idx_eval_crop ON expert.evaluation_record(crop_id);

COMMENT ON TABLE expert.evaluation_record IS 'AI诊断质量评估 — 用于衡量模型准确率';
COMMENT ON COLUMN expert.evaluation_record.is_correct IS 'AI第一选择是否正确';
COMMENT ON COLUMN expert.evaluation_record.is_top3_correct IS 'AI前三选择中是否包含正确答案';
COMMENT ON COLUMN expert.evaluation_record.evaluation_batch IS '评估批次，用于按批次统计准确率变化';
