-- ==========================================================
-- 应用启动时确保 schema 存在（跨库通用：H2 / PostgreSQL 都支持）
-- 顺序：本脚本在 JPA 建表之前执行（spring.sql.init.mode=always）
-- ==========================================================
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS extension;
CREATE SCHEMA IF NOT EXISTS audit;
-- 评估记录表（expert.evaluation_record）所在 schema。
-- 表本身由 JPA 实体 EvaluationRecord 建（与其它表一致，避免手写 DDL 与实体脱节）。
CREATE SCHEMA IF NOT EXISTS expert;
