package com.laos.agri.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * 生产密钥启动自检 —— 密钥没配好就不能"静默带病运行"
 *
 * <p>要解决的问题：{@code JWT_SECRET} 这类密钥如果没注入成功，
 * 早期实现会回退到一个写死的默认值，后果是**任何人都能用这个公开的默认密钥
 * 伪造登录令牌**。这类问题不会在功能测试中暴露，却足以让整个平台失守。
 *
 * <p>策略：
 * <ul>
 *   <li>{@code app.security.strict=true}（生产）：发现缺失/弱密钥 → **拒绝启动**，
 *       并在日志里给出明确的修复步骤</li>
 *   <li>{@code app.security.strict=false}（开发/演示）：只打印醒目告警，不阻断</li>
 * </ul>
 *
 * <p>运行顺序放在 {@link DataInitializer} 之前：密钥不合格时不该写入任何账号数据。
 */
@Component
@Order(-100)
public class StartupSecurityCheck implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StartupSecurityCheck.class);

    /** 已知的不安全默认值 —— 出现即视为"未配置" */
    private static final List<String> WEAK_VALUES = List.of(
            "change-me-in-production-use-at-least-256-bits",
            "change-me-in-production",
            "change-me-to-a-random-string",
            "laos-agri-dev-only-secret-change-me",
            "laos-agri-dev-only-jwt-secret-please-change-in-production-32bytes",
            "demo-profile-only-secret-not-for-production",
            "local-dev-reset-token",
            "admin123",
            "secret",
            "password"
    );

    /** 密钥最小长度要求 */
    private static final int MIN_SECRET_LENGTH = 32;

    private final String jwtSecret;
    private final String aiKeySecret;
    private final String adminInitPassword;
    private final boolean strict;

    public StartupSecurityCheck(
            @Value("${jwt.secret:}") String jwtSecret,
            @Value("${security.ai-key-secret:}") String aiKeySecret,
            @Value("${app.admin-init-password:}") String adminInitPassword,
            @Value("${app.security.strict:false}") boolean strict) {
        this.jwtSecret = jwtSecret;
        this.aiKeySecret = aiKeySecret;
        this.adminInitPassword = adminInitPassword;
        this.strict = strict;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<String> problems = new ArrayList<>();

        checkSecret("JWT_SECRET", jwtSecret, MIN_SECRET_LENGTH, problems,
                "签发登录令牌的密钥。缺失或过弱会导致任何人都能伪造令牌。");
        checkSecret("AI_KEY_SECRET", aiKeySecret, MIN_SECRET_LENGTH, problems,
                "加密数据库中 AI API Key 的主密钥。**一旦设定不可更改**，改了旧密文将无法解密。");
        checkSecret("ADMIN_INIT_PASSWORD", adminInitPassword, 8, problems,
                "管理员初始密码。留空时启动会随机生成并打印在日志里（仅首次创建账号时使用）。");

        if (problems.isEmpty()) {
            log.info("密钥自检通过：JWT_SECRET / AI_KEY_SECRET / ADMIN_INIT_PASSWORD 均已正确配置");
            return;
        }

        if (strict) {
            // 生产模式：直接拒绝启动，避免带着可被伪造的令牌对外服务
            log.error("=========================================================");
            log.error(" 启动被拒绝：生产模式(app.security.strict=true)下检测到密钥问题");
            problems.forEach(p -> log.error("   ✗ {}", p));
            log.error("");
            log.error(" 修复方式（任选其一）：");
            log.error("   1) 生成 .env 并填写：");
            log.error("      powershell -File scripts\\generate_secrets.ps1");
            log.error("   2) 直接设置环境变量后重启服务");
            log.error(" 详见 docs/生产部署手册.md");
            log.error("=========================================================");
            throw new IllegalStateException("生产环境密钥未正确配置，已拒绝启动");
        }

        log.warn("=========================================================");
        log.warn(" 密钥自检发现 {} 项问题（当前为非严格模式，仅告警不阻断）", problems.size());
        problems.forEach(p -> log.warn("   ! {}", p));
        log.warn("");
        log.warn(" 这可以用于本地开发，但**绝不能这样上生产**。");
        log.warn(" 生成密钥：powershell -File scripts\\generate_secrets.ps1");
        log.warn(" 生产启动时请加：--app.security.strict=true");
        log.warn("=========================================================");
    }

    private void checkSecret(String name, String value, int minLength,
                             List<String> problems, String purpose) {
        if (value == null || value.isBlank()) {
            problems.add(name + " 未配置 —— " + purpose);
            return;
        }
        String v = value.trim();
        if (WEAK_VALUES.stream().anyMatch(weak -> v.equalsIgnoreCase(weak))) {
            problems.add(name + " 仍是示例/开发默认值 —— " + purpose);
            return;
        }
        if (v.length() < minLength) {
            problems.add(name + " 长度不足（当前 " + v.length() + " 位，建议至少 "
                    + minLength + " 位随机字符）");
        }
    }
}
