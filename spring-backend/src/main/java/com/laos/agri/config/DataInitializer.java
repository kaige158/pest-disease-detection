package com.laos.agri.config;

import com.laos.agri.entity.AiProviderConfig;
import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.AiProviderConfigRepository;
import com.laos.agri.repository.UserRepository;
import com.laos.agri.service.ApiKeyCipher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.ApplicationArguments;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 首次启动初始化 —— 幂等，已存在则不动
 *
 * <ol>
 *   <li>确保存在可登录的管理员账号（密码来自环境变量 {@code ADMIN_INIT_PASSWORD}）</li>
 *   <li>预置常用 AI 通道占位（不含密钥，密钥由管理员在后台填写）</li>
 * </ol>
 *
 * <p>为什么密码不写在 SQL 里：版本库不该出现任何形式的凭据。
 * 未配置 {@code ADMIN_INIT_PASSWORD} 时生成随机密码并在启动日志中打印一次。
 */
@Component
public class DataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private static final String ADMIN_PHONE = "admin";

    private final UserRepository userRepo;
    private final AiProviderConfigRepository aiConfigRepo;
    private final PasswordEncoder passwordEncoder;
    private final ApiKeyCipher cipher;
    private final String initPassword;

    public DataInitializer(UserRepository userRepo,
                           AiProviderConfigRepository aiConfigRepo,
                           PasswordEncoder passwordEncoder,
                           ApiKeyCipher cipher,
                           @Value("${app.admin-init-password:}") String initPassword) {
        this.userRepo = userRepo;
        this.aiConfigRepo = aiConfigRepo;
        this.passwordEncoder = passwordEncoder;
        this.cipher = cipher;
        this.initPassword = initPassword;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        ensureAdmin();
        ensureAiChannels();
    }

    private void ensureAdmin() {
        var existing = userRepo.findByPhone(ADMIN_PHONE);
        if (existing.isPresent()) {
            User admin = existing.get();
            if (admin.getPasswordHash() != null && !admin.getPasswordHash().isBlank()) {
                log.info("管理员账号已就绪: {}", ADMIN_PHONE);
                return;
            }
            // 账号存在但没有密码（早期 SQL 只建了骨架）→ 补一个密码
            String pwd = resolvePassword();
            admin.setPasswordHash(passwordEncoder.encode(pwd));
            admin.setRole(UserRole.ADMIN);
            admin.setIsActive(true);
            admin.setMustChangePassword(true);   // 初始密码必须提醒修改
            userRepo.save(admin);
            log.warn("已为已存在的管理员账号补设密码，请立即登录后台修改");
            return;
        }

        String pwd = resolvePassword();
        User admin = new User();
        admin.setUuid(UUID.randomUUID().toString());
        admin.setPhone(ADMIN_PHONE);
        admin.setPasswordHash(passwordEncoder.encode(pwd));
        admin.setNickname("平台管理员");
        admin.setLanguagePref("zh");
        admin.setRole(UserRole.ADMIN);
        admin.setSource("SYSTEM");
        admin.setIsActive(true);
        admin.setTokenVersion(0);
        admin.setLoginCount(0);
        admin.setCropPreferences("[]");
        admin.setMustChangePassword(true);   // 首次登录必须提醒修改初始密码
        userRepo.save(admin);
        log.info("已创建默认管理员账号: {} / {}（首次登录会提醒修改密码）", ADMIN_PHONE, pwd);
    }

    /**
     * 管理密码来源优先级：
     *   1. 环境变量 ADMIN_INIT_PASSWORD
     *   2. 未配置则生成随机密码并打印一次（避免出现"默认弱口令"这种生产事故）
     */
    private String resolvePassword() {
        if (initPassword != null && !initPassword.isBlank()) {
            return initPassword.trim();
        }
        String random = "Agri@" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        log.warn("========================================================");
        log.warn(" 未配置 ADMIN_INIT_PASSWORD，已生成随机管理员密码：");
        log.warn("   {} / {}", ADMIN_PHONE, random);
        log.warn(" 该密码只打印这一次，请立即登录后台修改，或设置环境变量后重启");
        log.warn("========================================================");
        return random;
    }

    /** 预置 AI 通道占位 —— 与 database/v5_user_admin_ai_config.sql 的种子保持一致 */
    private void ensureAiChannels() {
        if (aiConfigRepo.count() > 0) {
            log.info("AI 通道配置已存在 {} 条，跳过初始化", aiConfigRepo.count());
            return;
        }

        record Seed(String provider, String display, String model, String baseUrl, String remark) {}
        List<Seed> seeds = List.of(
                new Seed("gemini", "Google Gemini（推荐，有免费额度）", "gemini-3.6-flash", null,
                        "在 https://aistudio.google.com/apikey 申请 Key 后填入"),
                new Seed("deepseek", "DeepSeek（国内直连）", "deepseek-v4-flash-vision-exp",
                        "https://api.deepseek.com/v1/chat/completions",
                        "国内直连；视觉能力需用 vision 系列模型，先点「测试连接」验证"),
                new Seed("kimi", "月之暗面 Kimi（国内可直连）", "moonshot-v1-8k-vision-preview", null,
                        "在 https://platform.moonshot.cn 申请 Key"),
                new Seed("openai", "OpenAI GPT-4o", "gpt-4o", null, "需要海外网络环境"),
                new Seed("claude", "Anthropic Claude", "claude-sonnet-4-20250514", null, "需要海外网络环境"),
                new Seed("custom", "自定义 / 代理（通义千问、智谱等）", "", null,
                        "兼容 OpenAI 协议；填接口地址与模型名即可接入")
        );

        boolean first = true;
        for (Seed s : seeds) {
            AiProviderConfig c = new AiProviderConfig();
            c.setProvider(s.provider());
            c.setDisplayName(s.display());
            c.setModel(s.model());
            c.setBaseUrl(s.baseUrl());
            c.setMaxTokens(2000);
            c.setTemperature(new java.math.BigDecimal("0.30"));
            c.setTimeoutSeconds(60);
            c.setRemark(s.remark());
            c.setIsActive(first);   // 默认启用第一个（gemini）
            first = false;
            aiConfigRepo.save(c);
        }
        log.info("已预置 {} 个 AI 通道占位（密钥待管理员在后台填写）", seeds.size());

        if (cipher.isUsingDevKey()) {
            log.warn("AI_KEY_SECRET 未配置：API Key 将用开发密钥加密，生产环境请务必配置固定密钥");
        }
    }
}
