-- ==========================================================
-- Sprint 13 — 用户系统 + 管理员系统 + AI 配置中心
-- 目标库: PostgreSQL 16 / schema: core
-- 幂等: 全部 IF NOT EXISTS，可重复执行
-- 说明: 本文件给 PostgreSQL 用；H2 演示档由 JPA 实体自动建表（ddl-auto=create）
-- ==========================================================

-- ==========================================================
-- 1. core.ai_provider_config — AI Provider 可视化配置（管理员可改）
-- ----------------------------------------------------------
-- 设计要点:
--   * 一行 = 一个可用的 AI 通道（gemini / kimi / openai / claude / custom）
--   * api_key_enc 存 AES-256-GCM 密文，绝不存明文；接口永不回传明文
--   * is_active 由实体基类提供（TRUE = 当前生效通道），唯一性由应用层保证
--   * 后台改完即生效：AI 服务运行时读取本表，无需重启
-- ==========================================================
CREATE TABLE IF NOT EXISTS core.ai_provider_config (
    id              BIGSERIAL PRIMARY KEY,
    provider        VARCHAR(30)  NOT NULL,               -- gemini/kimi/openai/claude/custom/mock
    display_name    VARCHAR(100),                        -- 展示名，如 "Google Gemini（免费额度）"
    api_key_enc     TEXT,                                -- AES-256-GCM 密文（Base64）
    api_key_masked  VARCHAR(60),                         -- 脱敏展示，如 "AIza****abcd"
    base_url        VARCHAR(300),                        -- 自定义/代理地址，可空
    model           VARCHAR(100),                        -- 模型名，如 gemini-3.6-flash
    max_tokens      INTEGER DEFAULT 2000,
    temperature     NUMERIC(3,2) DEFAULT 0.30,
    timeout_seconds INTEGER DEFAULT 60,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,       -- TRUE 表示当前生效（业务语义）
    last_test_at    TIMESTAMP,
    last_test_ok    BOOLEAN,
    last_test_ms    INTEGER,
    last_test_msg   VARCHAR(500),
    remark          VARCHAR(300),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 只允许一行处于"生效"状态（部分唯一索引，PostgreSQL 支持）
CREATE UNIQUE INDEX IF NOT EXISTS uk_ai_provider_enabled
    ON core.ai_provider_config((is_active)) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_ai_provider_provider ON core.ai_provider_config(provider);

COMMENT ON TABLE  core.ai_provider_config IS 'AI通道配置 — 管理员可在后台可视化修改，改完即生效';
COMMENT ON COLUMN core.ai_provider_config.api_key_enc IS 'API Key 密文（AES-256-GCM），密钥来自环境变量 AI_KEY_SECRET';
COMMENT ON COLUMN core.ai_provider_config.is_active IS 'TRUE=当前生效通道，全表最多一行为 TRUE';

-- ==========================================================
-- 2. core."user" — 用户系统补强
-- ==========================================================
-- 2.1 手机号唯一性 —— 口径是「区号 + 本地号码」组合
--     必须是组合唯一：+856 20xxxx 与 +66 20xxxx 是两个不同用户，
--     早期只对 phone 建唯一索引会导致跨国同号冲突。
DROP INDEX IF EXISTS core.uk_user_phone;
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_country_phone
    ON core."user"(country_code, phone)
    WHERE phone IS NOT NULL AND country_code IS NOT NULL;

COMMENT ON INDEX core.uk_user_country_phone IS '同一国家内本地号码唯一；跨国家允许同号';

-- 2.2 令牌版本号 —— 改密码 / 停用账号后，令已签发的 JWT 立即失效
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS token_version INTEGER DEFAULT 0;

-- 2.3 登录审计
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS last_login_ip VARCHAR(64);
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS login_count INTEGER DEFAULT 0;

-- 2.4 账号来源，区分农户自注册 / 后台开通 / 数据导入
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS source VARCHAR(20) DEFAULT 'APP';

-- 2.5 国际手机号支持
--     country_code: 国家区号（纯数字，如 856 / 86 / 66）
--     phone        : 只存"不带区号"的本地号码，区号与号码分离存储 → 支持多国用户
--     历史数据（存的是完整号码）保持原样，区号为空即视为"未拆分"，不影响老账号登录
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS country_code VARCHAR(6);
COMMENT ON COLUMN core."user".country_code IS '国际区号（856=老挝 86=中国 66=泰国 84=越南），为空表示历史数据未拆分';
COMMENT ON COLUMN core."user".phone IS '本地手机号（不含区号）；历史数据可能含区号，以 country_code 是否为空判断';

-- 2.6 首次登录 / 被重置密码后需提醒改密
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT FALSE;
COMMENT ON COLUMN core."user".must_change_password IS 'TRUE=提醒用户修改密码（初始密码或被管理员重置后置位）';

-- 2.7 最近登录设备标识 —— 换设备登录时要求短信验证
ALTER TABLE core."user" ADD COLUMN IF NOT EXISTS last_device_uuid VARCHAR(64);
COMMENT ON COLUMN core."user".last_device_uuid IS '最近一次登录的设备标识；与本次不同则判定为换设备，需短信验证';

-- 2.8 短信验证码 —— 证明号码归本人所有
--     解决"任何人编一个格式合法的号码就能注册"导致的假账号堆积
CREATE TABLE IF NOT EXISTS core.phone_verification (
    id           BIGSERIAL PRIMARY KEY,
    phone_full   VARCHAR(24) NOT NULL,          -- 区号+本地号码，如 8613900001111
    code_hash    VARCHAR(64) NOT NULL,          -- 验证码 SHA-256（不存明文）
    expires_at   TIMESTAMP   NOT NULL,          -- 有效期 5 分钟
    attempts     INTEGER     NOT NULL DEFAULT 0,-- 已尝试次数（上限 5 次）
    used         BOOLEAN     NOT NULL DEFAULT FALSE,
    client_ip    VARCHAR(64),
    device_uuid  VARCHAR(64),
    created_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_phone_verification_phone
    ON core.phone_verification(phone_full, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_phone_verification_ip
    ON core.phone_verification(client_ip, created_at DESC);

COMMENT ON TABLE core.phone_verification IS '手机号验证码；只存哈希，用于注册与换设备登录的归属验证';

-- 2.9 管理员查看完整手机号的审计日志
--     完整号码属于个人信息，查看行为必须留痕（谁、什么时候、看了谁）
CREATE TABLE IF NOT EXISTS core.audit_log (
    id           BIGSERIAL PRIMARY KEY,
    actor_id     BIGINT       NOT NULL,          -- 操作者（管理员）用户 id
    actor_phone  VARCHAR(32),                    -- 操作者账号，便于直接查日志
    action       VARCHAR(64)  NOT NULL,          -- 动作，如 REVEAL_PHONE
    target_type  VARCHAR(32),                    -- 目标类型，如 USER
    target_id    BIGINT,                         -- 目标 id
    detail       VARCHAR(500),                   -- 说明
    client_ip    VARCHAR(64),
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON core.audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON core.audit_log(actor_id, created_at DESC);

COMMENT ON TABLE core.audit_log IS '敏感操作审计日志（如查看用户完整手机号）';

COMMENT ON COLUMN core."user".token_version IS '令牌版本 — 递增即可让该用户所有已签发令牌失效';

-- ==========================================================
-- 3. 默认管理员账号骨架
-- ==========================================================
-- password_hash 由后端 DataInitializer 首次启动时按环境变量 ADMIN_INIT_PASSWORD
-- 生成 BCrypt 哈希写入，避免把任何形式的密码提交进版本库。
INSERT INTO core."user" (uuid, phone, nickname, role, language_pref, is_active, source)
VALUES ('admin-0000-0000-0000-000000000001', 'admin', '平台管理员', 'ADMIN', 'zh', TRUE, 'SYSTEM')
ON CONFLICT (uuid) DO NOTHING;

-- 注意：AI 通道的默认数据由后端 DataInitializer 写入（H2/PostgreSQL 通用），
--       不在此处硬编码自增 ID。

-- ==========================================================
-- 回滚（需手工执行）
-- ==========================================================
-- DROP TABLE IF EXISTS core.ai_provider_config;
-- DROP INDEX IF EXISTS core.uk_user_phone;
-- ALTER TABLE core."user" DROP COLUMN IF EXISTS token_version;
-- ALTER TABLE core."user" DROP COLUMN IF EXISTS last_login_ip;
-- ALTER TABLE core."user" DROP COLUMN IF EXISTS login_count;
-- ALTER TABLE core."user" DROP COLUMN IF EXISTS source;
