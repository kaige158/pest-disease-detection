package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.User;
import com.laos.agri.repository.PhoneVerificationRepository;
import com.laos.agri.service.AuthService;
import com.laos.agri.service.PhoneCodec;
import com.laos.agri.service.PhoneVerificationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 用户认证接口 —— 手机号 + 密码，首次登录自动注册
 *
 * <p>APP 端流程：
 * <pre>
 *   POST /api/v1/auth/login     {phone, password, nickname?}
 *     → {token, user, registered}      registered=true 表示本次是自动注册
 *   GET  /api/v1/auth/me        (需 Bearer token)
 *   PUT  /api/v1/auth/profile   (需 Bearer token)
 *   POST /api/v1/auth/password  (需 Bearer token)
 * </pre>
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final PhoneVerificationService verificationService;
    private final PhoneVerificationRepository verificationRepository;

    /** 是否允许通过接口取回验证码（仅开发/演示；生产必须为 false） */
    @Value("${app.sms.expose-code:false}")
    private boolean exposeDemoCode;

    public AuthController(AuthService authService,
                          PhoneVerificationService verificationService,
                          PhoneVerificationRepository verificationRepository) {
        this.authService = authService;
        this.verificationService = verificationService;
        this.verificationRepository = verificationRepository;
    }

    /** 登录请求体 —— countryCode 与 phone 分离，支持多国号码 */
    public record LoginRequest(
            @NotBlank(message = "请输入手机号") String phone,
            @NotBlank(message = "请输入密码") String password,
            String nickname,
            /** 国际区号，如 856(老挝) / 86(中国)；为空则按号码前缀自动识别 */
            String countryCode,
            /** 短信验证码 —— 首次注册或换设备登录时必填 */
            String smsCode,
            /** 设备标识，用于识别"换设备登录"与批量刷号 */
            String deviceUuid
    ) {}

    public record SendCodeRequest(@NotBlank String phone, String countryCode, String deviceUuid) {}

    public record ProfileRequest(String nickname, String language,
                                 String province, String district, String cropPreferences) {}

    public record PasswordRequest(@NotBlank String oldPassword, @NotBlank String newPassword) {}

    /**
     * 发送短信验证码
     *
     * <p>用途：注册新号码 / 换设备登录时证明"号码归本人所有"。
     * 没有这一步，任何人编一个格式合法的号码就能注册，
     * 会造成假账号堆积（用户反馈的"后台拥堵"）。
     */
    @PostMapping("/sms/send")
    public ApiResponse<Map<String, Object>> sendSmsCode(@Valid @RequestBody SendCodeRequest req,
                                                        HttpServletRequest httpReq) {
        try {
            PhoneCodec.ParsedPhone parsed = PhoneCodec.parse(req.countryCode(), req.phone());
            var outcome = verificationService.send(parsed, clientIp(httpReq), req.deviceUuid());
            if (!outcome.success()) {
                return ApiResponse.error(429, outcome.message());
            }
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("message", outcome.message());
            data.put("expires_in_seconds", outcome.expiresInSeconds());
            data.put("country_code", parsed.countryCode());
            data.put("phone", AuthService.maskPhone(parsed.localNumber()));
            // 开发/演示环境回显验证码 —— 没有真实短信通道时，否则 APP 根本走不完验证流程。
            // 生产环境 app.sms.expose-code=false，这个字段不会出现。
            if (exposeDemoCode && outcome.demoCode() != null) {
                data.put("demo_code", outcome.demoCode());
                data.put("demo_notice", "开发/演示环境：短信通道未接入，验证码由接口直接回显");
            }
            return ApiResponse.ok(data);
        } catch (PhoneCodec.InvalidPhoneException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    /**
     * 演示档专用：取回验证码（仅当 app.sms.expose-code=true 时可用）
     *
     * <p>存在的理由：开发/演示环境没有真实短信通道，若不提供此接口，
     * 验证码流程就完全没法测试。生产环境必须保持关闭
     * （application.yml 里 expose-code 默认为 false）。
     */
    @GetMapping("/sms/demo-code")
    public ApiResponse<Map<String, Object>> demoCode(@RequestParam String phone,
                                                     @RequestParam(required = false) String countryCode) {
        if (!exposeDemoCode) {
            return ApiResponse.error(403, "该接口仅用于开发/演示环境，当前已关闭");
        }
        try {
            PhoneCodec.ParsedPhone parsed = PhoneCodec.parse(countryCode, phone);
            String full = parsed.countryCode() + parsed.localNumber();
            var usable = verificationRepository.findUsable(full, java.time.LocalDateTime.now());
            if (usable.isEmpty()) {
                return ApiResponse.error(404, "没有可用的验证码，请先调用发送接口");
            }
            // 演示通道下直接回传验证码，避免开发期必须去看服务端日志
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("phone_full", full);
            data.put("note", "仅演示环境可用，生产环境该接口已关闭");
            data.put("expires_at", usable.get(0).getExpiresAt().toString());
            data.put("code_source", "服务端日志（验证码为明文不落库，此处仅提示去日志查看）");
            return ApiResponse.ok(data);
        } catch (PhoneCodec.InvalidPhoneException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    /**
     * 登录 / 首次自动注册（同一入口，降低农户理解成本）
     */
    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@Valid @RequestBody LoginRequest req,
                                                  HttpServletRequest httpReq) {
        try {
            String ip = clientIp(httpReq);
            AuthService.LoginResult result = authService.loginOrRegister(
                    req.countryCode(), req.phone(), req.password(), req.nickname(),
                    ip, req.smsCode(), req.deviceUuid());

            Map<String, Object> data = new LinkedHashMap<>();
            data.put("token", result.token());
            data.put("registered", result.registered());
            data.put("expires_in_hours", 24);
            data.put("user", AuthService.toPublicView(result.user()));
            return ApiResponse.ok(data);
        } catch (AuthService.InvalidCredentialException e) {
            return ApiResponse.error(401, e.getMessage());
        } catch (AuthService.AccountDisabledException e) {
            return ApiResponse.error(403, e.getMessage());
        } catch (AuthService.SmsCodeRequiredException e) {
            // 428 Precondition Required：前端据此弹出验证码输入框
            return ApiResponse.error(428, e.getMessage());
        }
    }

    /**
     * 支持的国家区号列表 —— 供 APP 与后台渲染国家选择器
     *
     * <p>放在公开接口里：登录前就要用，不能要求先认证。
     */
    @GetMapping("/countries")
    public ApiResponse<List<Map<String, Object>>> countries(@RequestParam(defaultValue = "zh") String language) {
        List<Map<String, Object>> list = PhoneCodec.COUNTRIES.stream()
                .map(c -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("code", c.code());
                    m.put("name", c.name(language));
                    m.put("name_zh", c.zhName());
                    m.put("name_lo", c.loName());
                    m.put("flag", c.flag());
                    m.put("is_default", PhoneCodec.DEFAULT_COUNTRY_CODE.equals(c.code()));
                    return m;
                })
                .toList();
        return ApiResponse.ok(list);
    }

    /**
     * 号码国家识别（不发送短信、不写库、无副作用）
     *
     * <p>用途有两个：
     * <ol>
     *   <li>APP 登录页在用户输完号码后就能提示"这看起来是中国号码，是否切换区号"，
     *       而不是等注册完才发现nationality标错了（这正是"中国号码被标成 +856"的根因）</li>
     *   <li>自动化验证可以稳定检查识别规则 —— 不再依赖"发一条短信看返回的区号"，
     *       那种写法会被 60 秒/条的发送限流拖成不稳定用例</li>
     * </ol>
     */
    @GetMapping("/detect-country")
    public ApiResponse<Map<String, Object>> detectCountry(@RequestParam String phone) {
        try {
            String digits = phone == null ? "" : phone.trim();
            PhoneCodec.CountryDetection d = PhoneCodec.detect(digits, PhoneCodec.DEFAULT_COUNTRY_CODE);
            PhoneCodec.ParsedPhone parsed = PhoneCodec.parse(null, digits);
            PhoneCodec.Country c = PhoneCodec.country(d.countryCode());

            Map<String, Object> data = new LinkedHashMap<>();
            data.put("input", digits);
            data.put("country_code", d.countryCode());
            data.put("country_name_zh", c.zhName());
            data.put("country_name_lo", c.loName());
            data.put("flag", c.flag());
            // explicit=用户写了+86 / matched=号码形态吻合 / guessed=形态对不上，按默认国家兜底
            data.put("confidence", d.confidence());
            data.put("others", d.others());
            data.put("local_number", parsed.localNumber());
            // 是否需要让用户确认国家：识别不出（guessed）或有多个国家形态吻合（others 非空）。
            // 注意不要用 PhoneCodec.isAmbiguous —— 那个方法的语义是"没写出 3 位区号前缀"，
            // 与"界面是否需要追问用户"不是一回事（13900001111 没有前缀但国家是确定的）。
            boolean needConfirm = "guessed".equals(d.confidence()) || !d.others().isEmpty();
            data.put("ambiguous", needConfirm);
            return ApiResponse.ok(data);
        } catch (PhoneCodec.InvalidPhoneException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    /** 当前登录用户信息 */
    @GetMapping("/me")
    public ApiResponse<Map<String, Object>> me(@RequestAttribute(name = "currentUser", required = false) User user) {
        if (user == null) return ApiResponse.error(401, "未登录或登录已过期");
        return ApiResponse.ok(AuthService.toPublicView(user));
    }

    /** 更新个人资料 */
    @PutMapping("/profile")
    public ApiResponse<Map<String, Object>> updateProfile(
            @RequestAttribute(name = "currentUser", required = false) User user,
            @RequestBody ProfileRequest req) {
        if (user == null) return ApiResponse.error(401, "未登录或登录已过期");
        try {
            User saved = authService.updateProfile(user, req.nickname(), req.language(),
                    req.province(), req.district(), req.cropPreferences());
            return ApiResponse.ok(AuthService.toPublicView(saved));
        } catch (AuthService.InvalidCredentialException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    /** 修改密码（成功后其他设备的登录态立即失效） */
    @PostMapping("/password")
    public ApiResponse<String> changePassword(
            @RequestAttribute(name = "currentUser", required = false) User user,
            @Valid @RequestBody PasswordRequest req) {
        if (user == null) return ApiResponse.error(401, "未登录或登录已过期");
        try {
            authService.changePassword(user, req.oldPassword(), req.newPassword());
            return ApiResponse.ok("密码已修改，请重新登录");
        } catch (AuthService.InvalidCredentialException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    private static String clientIp(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return req.getRemoteAddr();
    }
}
