-- ==========================================================
-- 00 —— 建 schema（必须在所有建表脚本之前执行）
--
-- 为什么单独一个文件：database/init.sql 只建了 core，
-- 而 training_dataset.sql 用 extension.、evaluation_record.sql 用 expert.，
-- 这两个 schema 谁都没建 —— 直接按顺序跑会在第二步就报
-- "schema extension does not exist"。
--
-- 文件名以 00- 开头，保证被 docker-entrypoint-initdb.d 最先执行（按字典序）。
-- ==========================================================

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS extension;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS expert;
