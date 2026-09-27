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

-- ==========================================================
-- 让后续初始化脚本里「不带 schema 前缀」的表名也能解析
--
-- 踩过的坑：database/seed_data_v1.sql 等种子脚本用的是
--   INSERT INTO crop_category (...)
-- 这种不带 core. 前缀的写法，而表都建在 core 下 ——
-- PostgreSQL 默认 search_path 是 "$user", public，找不到 core.crop_category，
-- 于是 05/06/07 三个种子脚本全部报 relation does not exist 并中断。
--
-- ALTER DATABASE 只对**之后新建的连接**生效，而 postgres 官方镜像
-- 每个 *.sql 文件都是用独立的 psql 连接执行 —— 所以放在 00 里正好能覆盖后面的脚本。
-- ==========================================================
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path TO core, public, extension, expert',
                   current_database());
END $$;
