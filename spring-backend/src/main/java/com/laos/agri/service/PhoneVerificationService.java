package com.laos.agri.service;

import com.laos.agri.entity.PhoneVerification;
import com.laos.agri.repository.PhoneVerificationRepository;
import com.laos.agri.service.sms.SmsSender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.List;

/**
 * 手机号验证服务 —— 证明号码归本人所有
 *
 * <p>解决的问题：早期"手机号 + 自设密码"没有任何归属验证，
 * 任何人编一个格式合法的号码即可注册，导致假账号堆积、后台被无效用户淹没。
 *
 * <p>防刷设计（多层，因为短信是要花钱的）：
 * <table>
 *   <tr><th>维度</th><th>限制</th><th>目的</th></tr>
 *   <tr><td>同一号码</td><td>60 秒 1 条 / 1 小时 5 条 / 1 天 10 条</td><td>防止骚扰与穷举</td></tr>
 *   <tr><td>同一 IP</td><td>1 小时 20 条</td><td>识别批量刷号</td></tr>
 *   <tr><td>全平台</td><td>1 天 2000 条</td><td>兜底：防止恶意刷爆短信费用</td></tr>
 *   <tr><td>校验尝试</td><td>每条码最多 5 次</td><td>6 位码 100 万种，5 次机会 ≈ 二十万分之一</td></tr>
 * </table>
 */
@Service
public class PhoneVerificationService {

    private static final Logger log = LoggerFactory.getLogger(PhoneVerificationService.class);

    /** 验证码有效期（分钟） */
    private static final int CODE_TTL_MINUTES = 5;
    private static final int MAX_ATTEMPTS = 5;
    private static final int RESEND_COOLDOWN_SECONDS = 60;
    private static final int MAX_PER_HOUR_PER_PHONE = 5;
    private static final int MAX_PER_DAY_PER_PHONE = 10;

    /**
     * 同一 IP 每小时的发送上限
     *
     * <p>为什么做成可配置：生产环境要防批量刷号（默认 20 条/小时），
     * 但开发与自动化测试会从同一个 IP 反复注册账号，
     * 固定阈值会让测试全部撞上限流（这本身证明限流有效，但挡住了回归测试）。
     */
    @org.springframework.beans.factory.annotation.Value("${app.sms.max-per-hour-per-ip:20}")
    private int maxPerHourPerIp;

    /** 全平台每日上限 —— 兜底保护，防止被恶意刷爆短信费用 */
    @org.springframework.beans.factory.annotation.Value("${app.sms.max-per-day-global:2000}")
    private int maxPerDayGlobal;

    private final PhoneVerificationRepository repo;
    private final SmsSender smsSender;
    private final SecureRandom random = new SecureRandom();

    public PhoneVerificationService(PhoneVerificationRepository repo, SmsSender smsSender) {
        this.repo = repo;
        this.smsSender = smsSender;
    }

    /**
     * 发送结果：包含给用户看的中文提示
     *
     * @param demoCode 验证码明文 —— **仅用于开发/演示环境把码回显给前端**
     *                 （没有真实短信通道时，否则验证码流程根本没法走通）。
     *                 是否真的回显由 {@code app.sms.expose-code} 决定，
     *                 生产必须为 false；数据库里依旧只存哈希，不留明文。
     */
    public record SendOutcome(boolean success, String message, int expiresInSeconds, String demoCode) {
        public SendOutcome(boolean success, String message, int expiresInSeconds) {
            this(success, message, expiresInSeconds, null);
        }
    }

    /** 校验结果 */
    public record VerifyOutcome(boolean success, String message) {}

    /**
     * 发送验证码
     *
     * @param clientIp   调用方 IP，用于限流
     * @param deviceUuid 设备标识，便于事后追踪刷号来源
     */
    @Transactional
    public SendOutcome send(PhoneCodec.ParsedPhone phone, String clientIp, String deviceUuid) {
        if (phone.countryCode() == null) {
            return new SendOutcome(false, "该账号不支持短信验证", 0);
        }
        String phoneFull = phone.countryCode() + phone.localNumber();
        LocalDateTime now = LocalDateTime.now();

        // ---- 限流检查 ----
        var last = repo.findFirstByPhoneFullOrderByIdDesc(phoneFull);
        if (last.isPresent()) {
            long seconds = java.time.Duration.between(last.get().getCreatedAt(), now).getSeconds();
            if (seconds < RESEND_COOLDOWN_SECONDS) {
                long wait = RESEND_COOLDOWN_SECONDS - seconds;
                return new SendOutcome(false, "请求过于频繁，请 " + wait + " 秒后重试", (int) wait);
            }
        }
        long hourCount = repo.countByPhoneFullAndCreatedAtAfter(phoneFull, now.minusHours(1));
        if (hourCount >= MAX_PER_HOUR_PER_PHONE) {
            return new SendOutcome(false, "该号码 1 小时内发送次数过多，请稍后再试", 0);
        }
        long dayCount = repo.countByPhoneFullAndCreatedAtAfter(phoneFull, now.minusDays(1));
        if (dayCount >= MAX_PER_DAY_PER_PHONE) {
            return new SendOutcome(false, "该号码今日发送次数已达上限，请明天再试", 0);
        }
        if (clientIp != null && !clientIp.isBlank()) {
            long ipCount = repo.countByClientIpAndCreatedAtAfter(clientIp, now.minusHours(1));
            if (ipCount >= maxPerHourPerIp) {
                log.warn("短信发送被 IP 限流: ip={}, count={}", clientIp, ipCount);
                return new SendOutcome(false, "当前网络发送次数过多，请稍后再试", 0);
            }
        }
        long globalCount = repo.countByCreatedAtAfter(now.minusDays(1));
        if (globalCount >= maxPerDayGlobal) {
            log.error("短信发送触发全平台日限额保护: count={}（可能存在刷号行为）", globalCount);
            return new SendOutcome(false, "平台今日短信额度已用完，请稍后再试", 0);
        }

        // ---- 生成并发送 ----
        String code = generateCode();
        SmsSender.SendResult sent = smsSender.send(phone.countryCode(), phone.localNumber(), code);
        if (!sent.success()) {
            return new SendOutcome(false, "短信发送失败：" + sent.message(), 0);
        }

        // 旧码立即作废，避免同时存在多个有效码
        List<PhoneVerification> usable = repo.findUsable(phoneFull, now);
        usable.forEach(v -> v.setUsed(true));
        repo.saveAll(usable);

        PhoneVerification entity = new PhoneVerification();
        entity.setPhoneFull(phoneFull);
        entity.setCodeHash(sha256(code));
        entity.setExpiresAt(now.plusMinutes(CODE_TTL_MINUTES));
        entity.setAttempts(0);
        entity.setUsed(false);
        entity.setClientIp(clientIp);
        entity.setDeviceUuid(deviceUuid);
        entity.setCreatedAt(now);
        repo.save(entity);

        log.info("验证码已生成: phone={}, ip={}, provider={}",
                maskLocal(phone.localNumber()), clientIp, smsSender.providerName());

        return new SendOutcome(true, sent.message(), CODE_TTL_MINUTES * 60, code);
    }

    /**
     * 校验验证码（校验成功即标记已用，防止同一码重复使用）
     */
    @Transactional
    public VerifyOutcome verify(String countryCode, String localNumber, String inputCode) {
        if (countryCode == null || localNumber == null || inputCode == null || inputCode.isBlank()) {
            return new VerifyOutcome(false, "验证码不正确");
        }
        String phoneFull = countryCode + localNumber;
        LocalDateTime now = LocalDateTime.now();

        List<PhoneVerification> usable = repo.findUsable(phoneFull, now);
        if (usable.isEmpty()) {
            return new VerifyOutcome(false, "验证码已失效，请重新获取");
        }

        PhoneVerification v = usable.get(0);
        if (v.getAttempts() != null && v.getAttempts() >= MAX_ATTEMPTS) {
            v.setUsed(true);
            repo.save(v);
            return new VerifyOutcome(false, "验证码错误次数过多，请重新获取");
        }

        v.setAttempts((v.getAttempts() == null ? 0 : v.getAttempts()) + 1);
        if (!sha256(inputCode.trim()).equals(v.getCodeHash())) {
            repo.save(v);
            int left = MAX_ATTEMPTS - v.getAttempts();
            return new VerifyOutcome(false, left > 0
                    ? "验证码不正确，还可尝试 " + left + " 次"
                    : "验证码错误次数过多，请重新获取");
        }

        v.setUsed(true);
        repo.save(v);
        return new VerifyOutcome(true, "验证成功");
    }

    /**
     * 清理过期验证码（每小时一次）
     *
     * <p>验证码本身是短期数据，长期堆积既占空间也拖慢限流统计查询。
     */
    @Scheduled(fixedDelay = 3600_000L, initialDelay = 300_000L)
    @Transactional
    public void cleanupExpired() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(1);
        List<PhoneVerification> old = repo.findAll().stream()
                .filter(v -> v.getCreatedAt() != null && v.getCreatedAt().isBefore(cutoff))
                .toList();
        if (!old.isEmpty()) {
            repo.deleteAll(old);
            log.debug("已清理过期验证码 {} 条", old.size());
        }
    }

    // ==================== 内部工具 ====================

    /** 6 位数字验证码，用密码学安全随机数（避免可预测） */
    private String generateCode() {
        return String.format("%06d", random.nextInt(1_000_000));
    }

    private static String sha256(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("验证码哈希失败", e);
        }
    }

    private static String maskLocal(String local) {
        if (local == null || local.length() < 6) return "***";
        return local.substring(0, 3) + "****" + local.substring(local.length() - 2);
    }
}
