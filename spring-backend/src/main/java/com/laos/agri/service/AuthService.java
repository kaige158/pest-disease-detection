package com.laos.agri.service;

import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 用户认证服务 —— "手机号 + 密码，首次登录自动注册"
 *
 * <p>为什么不做短信验证码：老挝本地短信通道不稳定且需额外采购，
 * 首版先用手机号+密码把用户体系跑通，验证码能力后续可平滑替换
 * （只需把 {@link #loginOrRegister} 的凭据校验换成验证码校验）。
 *
 * <p>安全设计：
 * <ul>
 *   <li>密码 BCrypt 加盐哈希，绝不存明文</li>
 *   <li>账号被停用（isActive=false）时拒绝登录，并递增 tokenVersion 踢下线</li>
 *   <li>首次注册自动登录，减少农户操作步骤</li>
 * </ul>
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** 用户资料字段的默认值（注册时使用） */
    private static final int MIN_PASSWORD_LENGTH = 6;
    private static final int MAX_PASSWORD_LENGTH = 64;

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final PhoneVerificationService verificationService;

    /** 是否强制短信验证码（生产必须为 true） */
    @org.springframework.beans.factory.annotation.Value("${app.sms.require-code:false}")
    private boolean requireSmsCode;

    public AuthService(UserRepository userRepo, PasswordEncoder passwordEncoder, JwtService jwtService,
                       PhoneVerificationService verificationService) {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.verificationService = verificationService;
    }

    /** 登录结果 */
    public record LoginResult(boolean registered, String token, User user) {}

    /** 参数非法（手机号/密码不符合规则） */
    public static class InvalidCredentialException extends RuntimeException {
        public InvalidCredentialException(String message) { super(message); }
    }

    /** 账号被停用 */
    public static class AccountDisabledException extends RuntimeException {
        public AccountDisabledException(String message) { super(message); }
    }

    /**
     * 需要短信验证码才能继续
     *
     * <p>返回给客户端时用 HTTP 428（Precondition Required），
     * 前端据此弹出验证码输入框，而不是当成普通登录失败。
     */
    public static class SmsCodeRequiredException extends RuntimeException {
        public SmsCodeRequiredException(String message) { super(message); }
    }

    /**
     * 首次登录即注册；手机号已存在则校验密码。
     *
     * <p>短信验证码策略（解决"任何人都能编个号码注册"的问题）：
     * <ul>
     *   <li><b>新号码注册</b> → 必须验证码（这是假账号的主要来源）</li>
     *   <li>老账号 + 密码正确 + <b>同一台设备</b> → 直接登录
     *       （农户日常使用不能每次都收短信，老挝短信还可能要钱）</li>
     *   <li>老账号 + 密码正确 + <b>换了设备</b> → 必须验证码</li>
     * </ul>
     *
     * @param rawCountryCode 国际区号；为空则按号码前缀自动识别
     * @param smsCode        短信验证码，按上述策略决定是否必填
     * @param deviceUuid     设备标识，用于判断"是否换设备登录"
     */
    @Transactional
    public LoginResult loginOrRegister(String rawCountryCode, String rawPhone, String rawPassword,
                                       String nickname, String clientIp,
                                       String smsCode, String deviceUuid) {
        PhoneCodec.ParsedPhone parsed;
        try {
            parsed = PhoneCodec.parse(rawCountryCode, rawPhone);
        } catch (PhoneCodec.InvalidPhoneException e) {
            throw new InvalidCredentialException(e.getMessage());
        }

        // 查找顺序很关键：
        //   第 1 轮 只认「目标国家」的账号 —— 避免不同国家的同号互相串号
        //   第 2 轮 才回退到未拆分国家的历史数据（country_code 为空）
        String password = rawPassword == null ? "" : rawPassword.trim();
        validatePassword(password);

        User user = null;
        boolean credentialMismatch = false;

        for (String candidate : PhoneCodec.lookupCandidates(parsed)) {
            Optional<User> found = userRepo.findByPhone(candidate);
            if (found.isEmpty()) continue;
            User cu = found.get();
            if (parsed.countryCode() != null
                    && cu.getCountryCode() != null && !cu.getCountryCode().isBlank()
                    && !parsed.countryCode().equals(cu.getCountryCode())) {
                continue;   // 属于其它国家的同号账号，跳过
            }
            if (cu.getPasswordHash() != null
                    && passwordEncoder.matches(password, cu.getPasswordHash())) {
                user = cu;
                break;
            }
            credentialMismatch = true;
        }

        if (user == null && parsed.countryCode() != null) {
            for (String candidate : PhoneCodec.lookupCandidates(parsed)) {
                Optional<User> found = userRepo.findByPhone(candidate);
                if (found.isEmpty()) continue;
                User cu = found.get();
                // 第二轮只认"历史遗留"（未记录区号）的账号
                if (cu.getCountryCode() != null && !cu.getCountryCode().isBlank()) continue;
                if (cu.getPasswordHash() != null
                        && passwordEncoder.matches(password, cu.getPasswordHash())) {
                    user = cu;
                    credentialMismatch = false;
                    break;
                }
                credentialMismatch = true;
            }
        }

        // ==================== 短信验证码闸门 ====================
        // 需要验证码的两种情况：新号码注册 / 换设备登录
        boolean needSmsCode = false;
        String needReason = "";
        if (requireSmsCode) {
            if (user == null) {
                needSmsCode = true;
                needReason = "首次使用该号码，需要短信验证";
            } else if (deviceChanged(user, deviceUuid)) {
                needSmsCode = true;
                needReason = "检测到在新设备登录，需要短信验证";
            }
        }

        if (needSmsCode) {
            if (smsCode == null || smsCode.isBlank()) {
                throw new SmsCodeRequiredException(needReason + "，请获取验证码");
            }
            var verified = verificationService.verify(
                    parsed.countryCode(), parsed.localNumber(), smsCode);
            if (!verified.success()) {
                throw new InvalidCredentialException(verified.message());
            }
        }

        boolean registered;
        if (user == null) {
            if (credentialMismatch) {
                log.info("登录失败(凭据不匹配): phone={}", maskPhone(parsed.localNumber()));
                throw new InvalidCredentialException("手机号或密码不正确");
            }
            user = createUser(parsed, password, nickname);
            registered = true;
            log.info("新用户自动注册: phone={}, country={}, uuid={}, ip={}",
                    maskPhone(parsed.localNumber()), parsed.countryCode(), user.getUuid(), clientIp);
        } else {
            registered = false;
            if (Boolean.FALSE.equals(user.getIsActive())) {
                throw new AccountDisabledException("账号已被停用，请联系管理员");
            }
            // 历史数据补全区号，后续展示与统计才能按国家区分
            if ((user.getCountryCode() == null || user.getCountryCode().isBlank())
                    && parsed.countryCode() != null) {
                user.setCountryCode(parsed.countryCode());
            }
        }

        // 记录设备，供下次判断"是否换设备"
        if (deviceUuid != null && !deviceUuid.isBlank()) {
            user.setLastDeviceUuid(deviceUuid);
        }

        // 更新登录审计
        user.setLastLoginAt(LocalDateTime.now());
        user.setLastLoginIp(clientIp);
        user.setLoginCount((user.getLoginCount() == null ? 0 : user.getLoginCount()) + 1);
        userRepo.save(user);

        return new LoginResult(registered, jwtService.issue(user), user);
    }

    /**
     * 是否换了设备
     *
     * <p>仅在"此前记录过设备号"且"本次设备号不同"时判定为换设备 ——
     * 老数据没有设备号，不应因此把正常用户挡在门外。
     */
    private static boolean deviceChanged(User user, String deviceUuid) {
        if (deviceUuid == null || deviceUuid.isBlank()) return false;
        String last = user.getLastDeviceUuid();
        if (last == null || last.isBlank()) return false;
        return !last.equals(deviceUuid);
    }

    /** 兼容旧调用：不带验证码与设备号（内部/测试用） */
    @Transactional
    public LoginResult loginOrRegister(String rawPhone, String rawPassword, String nickname, String clientIp) {
        return loginOrRegister(null, rawPhone, rawPassword, nickname, clientIp, null, null);
    }

    /** 按 id 取用户（令牌验签后使用） */
    public Optional<User> findById(Long id) {
        return userRepo.findById(id);
    }

    /** 用户对象 → 对外安全视图（绝不包含 passwordHash） */
    public static java.util.Map<String, Object> toPublicView(User u) {
        java.util.Map<String, Object> m = new java.util.LinkedHashMap<>();
        m.put("id", u.getId());
        m.put("uuid", u.getUuid());
        // 手机号只回传脱敏串，并带区号，便于界面直接展示 +856 0205****234
        m.put("phone", maskPhone(u.getPhone()));
        m.put("country_code", u.getCountryCode() == null ? "" : u.getCountryCode());
        m.put("phone_display", maskWithCountry(u.getCountryCode(), u.getPhone()));
        m.put("nickname", u.getNickname());
        m.put("avatar_url", u.getAvatarUrl());
        m.put("role", u.getRole() == null ? "FARMER" : u.getRole().name());
        m.put("language", u.getLanguagePref());
        m.put("region_province", u.getRegionProvince());
        m.put("region_district", u.getRegionDistrict());
        m.put("crop_preferences", u.getCropPreferences());
        m.put("is_active", u.getIsActive());
        m.put("must_change_password", u.getMustChangePassword());
        m.put("login_count", u.getLoginCount());
        m.put("last_login_at", u.getLastLoginAt() == null ? null : u.getLastLoginAt().toString());
        m.put("created_at", u.getCreatedAt() == null ? null : u.getCreatedAt().toString());
        return m;
    }

    /** 更新个人资料（只允许改这几个字段，角色/状态只能由管理员改） */
    @Transactional
    public User updateProfile(User user, String nickname, String language,
                              String province, String district, String cropPreferences) {
        if (nickname != null && !nickname.isBlank()) user.setNickname(nickname.trim());
        if (language != null && !language.isBlank()) {
            String lang = language.trim().toLowerCase();
            if (!lang.equals("zh") && !lang.equals("lo")) {
                throw new InvalidCredentialException("语言只支持 zh 或 lo");
            }
            user.setLanguagePref(lang);
        }
        if (province != null) user.setRegionProvince(province.trim());
        if (district != null) user.setRegionDistrict(district.trim());
        if (cropPreferences != null) user.setCropPreferences(cropPreferences.trim());
        return userRepo.save(user);
    }

    /** 修改密码 —— 改完递增 tokenVersion，其他设备上的登录态立即失效 */
    @Transactional
    public void changePassword(User user, String oldPassword, String newPassword) {
        if (user.getPasswordHash() == null || !passwordEncoder.matches(oldPassword, user.getPasswordHash())) {
            throw new InvalidCredentialException("原密码不正确");
        }
        validatePassword(newPassword);
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setTokenVersion((user.getTokenVersion() == null ? 0 : user.getTokenVersion()) + 1);
        user.setMustChangePassword(false);   // 用户已自行改密，清掉提醒标记
        userRepo.save(user);
    }

    // ==================== 内部工具 ====================

    private User createUser(PhoneCodec.ParsedPhone parsed, String password, String nickname) {
        // 唯一性口径是「区号 + 本地号码」组合：同号不同国是两个用户
        if (parsed.countryCode() != null) {
            Optional<User> dup = userRepo.findFirstByCountryCodeAndPhone(parsed.countryCode(), parsed.localNumber());
            if (dup.isPresent()) {
                throw new InvalidCredentialException("该号码已注册，请直接登录或找回密码");
            }
        }

        User u = new User();
        u.setUuid(UUID.randomUUID().toString());
        u.setPhone(parsed.localNumber());       // 只存本地号码，区号单独存
        u.setCountryCode(parsed.countryCode());
        u.setPasswordHash(passwordEncoder.encode(password));
        u.setNickname(nickname == null || nickname.isBlank()
                ? defaultNickname(parsed.localNumber()) : nickname.trim());
        u.setLanguagePref("lo");   // 目标用户是老挝农户，默认老挝语
        u.setRole(UserRole.FARMER);
        u.setSource("APP");
        u.setIsActive(true);
        u.setTokenVersion(0);
        u.setLoginCount(0);
        u.setCropPreferences("[]");
        u.setMustChangePassword(false);
        return userRepo.save(u);
    }

    private static String defaultNickname(String phone) {
        return "农户" + phone.substring(Math.max(0, phone.length() - 4));
    }

    private static void validatePassword(String password) {
        if (password == null || password.length() < MIN_PASSWORD_LENGTH) {
            throw new InvalidCredentialException("密码至少 " + MIN_PASSWORD_LENGTH + " 位");
        }
        if (password.length() > MAX_PASSWORD_LENGTH) {
            throw new InvalidCredentialException("密码不能超过 " + MAX_PASSWORD_LENGTH + " 位");
        }
    }

    /** 脱敏展示：只保留前 4 位与后 3 位 */
    public static String maskPhone(String phone) {
        if (phone == null || phone.length() < 8) return phone;
        return phone.substring(0, 4) + "****" + phone.substring(phone.length() - 3);
    }

    /** 带区号的脱敏展示，如 +856 0205****234 */
    public static String maskWithCountry(String countryCode, String phone) {
        if (phone == null || phone.isBlank()) return "";
        if (countryCode == null || countryCode.isBlank()) return maskPhone(phone);
        return "+" + countryCode + " " + maskPhone(phone);
    }
}
