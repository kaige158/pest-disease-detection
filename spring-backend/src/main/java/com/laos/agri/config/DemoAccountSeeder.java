package com.laos.agri.config;

import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.UserRepository;
import com.laos.agri.service.PhoneCodec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 演示账号播种 —— 为四个角色各准备一个可登录的账号
 *
 * <p>为什么需要：交付验收时要验证"不同角色看到的后台不一样"，
 * 但演示档用的是 H2 内存库，**每次重启数据全清空**，
 * 手工去 APP 里注册四个号既慢又得反复收短信。这里在启动时直接建好。
 *
 * <p>安全边界（很重要，别被误开到生产）：
 * <ol>
 *   <li>只在 {@code demo/dev} profile 下生效（{@link Profile}）</li>
 *   <li>还要显式打开 {@code app.demo.seed-accounts=true}（{@link ConditionalOnProperty}）</li>
 *   <li>账号 {@code source=DEMO} 标记来源，后台一眼能看出是演示账号</li>
 *   <li>密码从配置读，不在代码里写死</li>
 * </ol>
 *
 * <p>管理员账号不在这里创建 —— 它由 {@link DataInitializer} 按
 * {@code ADMIN_INIT_PASSWORD} 建立，避免出现两套管理员密码。
 */
@Component
@Profile({"demo", "dev"})
@ConditionalOnProperty(name = "app.demo.seed-accounts", havingValue = "true")
public class DemoAccountSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoAccountSeeder.class);

    /** 演示账号定义：角色 + 老挝本地号码 + 昵称 */
    private record Seed(UserRole role, String phone, String nickname) {}

    private static final List<Seed> SEEDS = List.of(
            new Seed(UserRole.EXPERT, "02055550001", "农业专家（演示）"),
            new Seed(UserRole.TECHNICIAN, "02055550002", "农技员（演示）"),
            new Seed(UserRole.FARMER, "02055550003", "农户（演示）")
    );

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final String demoPassword;
    private final String countryCode;

    public DemoAccountSeeder(UserRepository userRepo,
                             PasswordEncoder passwordEncoder,
                             @Value("${app.demo.password:}") String demoPassword,
                             @Value("${app.demo.country-code:856}") String countryCode) {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.demoPassword = demoPassword;
        this.countryCode = countryCode;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (demoPassword == null || demoPassword.isBlank()) {
            log.warn("app.demo.seed-accounts=true 但未配置 app.demo.password，跳过演示账号播种");
            return;
        }

        List<String> created = new java.util.ArrayList<>();
        for (Seed s : SEEDS) {
            // 号码规范化与注册路径走同一套逻辑，避免"播种出来的号码登录时找不到"
            PhoneCodec.ParsedPhone parsed = PhoneCodec.parse(countryCode, s.phone());
            if (userRepo.findByPhone(parsed.localNumber()).isPresent()) {
                continue;   // 幂等：已存在就不动（也避免重启后改掉用户自己改过的密码）
            }

            User u = new User();
            u.setUuid(UUID.randomUUID().toString());
            u.setPhone(parsed.localNumber());
            u.setCountryCode(parsed.countryCode());
            u.setPasswordHash(passwordEncoder.encode(demoPassword));
            u.setNickname(s.nickname());
            u.setLanguagePref("zh");
            u.setRole(s.role());
            u.setSource("DEMO");
            u.setIsActive(true);
            u.setTokenVersion(0);
            u.setLoginCount(0);
            u.setCropPreferences("[]");
            // 演示账号不弹"请修改初始密码"，否则每次都挡一层
            u.setMustChangePassword(false);
            userRepo.save(u);
            created.add(s.role().name() + " " + PhoneCodec.display(parsed.countryCode(), parsed.localNumber()));
        }

        if (created.isEmpty()) {
            log.info("演示账号已存在，跳过播种");
            return;
        }
        // 只在演示档打印，生产启用会立刻在日志里暴露出来
        log.warn("========================================================");
        log.warn(" 已创建 {} 个演示账号（仅 demo/dev 档，重启后重建）", created.size());
        created.forEach(c -> log.warn("   {}", c));
        log.warn(" 演示账号统一密码见配置 app.demo.password（默认 Laos@2026）");
        log.warn("========================================================");
    }
}
