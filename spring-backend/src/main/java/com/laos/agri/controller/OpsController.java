package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * 运维专用接口 —— 重置管理员密码
 *
 * <p>为什么需要它：本项目首版没有短信/邮件通道，管理员一旦忘记密码就没有自救途径
 * （演示档又是内存库，重启后密码会重新初始化）。这里提供一条**仅限本机**的通道，
 * 由 {@code scripts/reset_admin_password.ps1} 调用。
 *
 * <p>安全设计（三重限制，缺一不可）：
 * <ol>
 *   <li>必须来自 127.0.0.1 / ::1（远程请求直接 403）</li>
 *   <li>必须提供与 {@code app.ops-token} 一致的令牌，该值只在服务器本地配置文件/环境变量中</li>
 *   <li>写操作 + 递增 token_version，改完所有旧登录态立即失效</li>
 * </ol>
 *
 * <p>生产环境建议保持 {@code app.ops-token} 为空（默认即关闭本接口）。
 */
@RestController
@RequestMapping("/api/v1/ops")
public class OpsController {

    private static final Logger log = LoggerFactory.getLogger(OpsController.class);

    /** 允许调用本接口的本地地址 */
    private static final Set<String> LOCAL_ADDRESSES =
            Set.of("127.0.0.1", "0:0:0:0:0:0:0:1", "::1", "localhost");

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.ops-token:}")
    private String opsToken;

    public OpsController(UserRepository userRepo, PasswordEncoder passwordEncoder) {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
    }

    public record ResetRequest(String account, String newPassword, String token) {}

    @PostMapping("/reset-password")
    @Transactional
    public ApiResponse<Map<String, Object>> resetPassword(@RequestBody ResetRequest req,
                                                          HttpServletRequest httpReq) {
        // 限制 1：仅本机
        String remote = httpReq.getRemoteAddr();
        if (remote == null || !LOCAL_ADDRESSES.contains(remote)) {
            log.warn("拒绝非本机的密码重置请求: remote={}", remote);
            return ApiResponse.error(403, "该接口仅允许本机调用");
        }

        // 限制 2：接口未开启时直接拒绝（默认关闭）
        if (opsToken == null || opsToken.isBlank()) {
            return ApiResponse.error(403, "密码重置接口未开启（未配置 app.ops-token）");
        }
        if (req.token() == null || !opsToken.equals(req.token())) {
            log.warn("密码重置令牌不正确");
            return ApiResponse.error(403, "运维令牌不正确");
        }

        String account = (req.account() == null || req.account().isBlank()) ? "admin" : req.account().trim();
        String newPwd = req.newPassword() == null ? "" : req.newPassword().trim();
        if (newPwd.length() < 6) {
            return ApiResponse.error(400, "新密码至少 6 位");
        }

        var found = userRepo.findByPhone(account);
        if (found.isEmpty()) {
            return ApiResponse.error(404, "账号不存在: " + account);
        }

        User user = found.get();
        user.setPasswordHash(passwordEncoder.encode(newPwd));
        user.setTokenVersion((user.getTokenVersion() == null ? 0 : user.getTokenVersion()) + 1);
        user.setIsActive(true);
        user.setMustChangePassword(true);   // 运维重置的密码同样要求用户自己再改一次
        if (user.getRole() == null) {
            user.setRole(UserRole.ADMIN);
        }
        userRepo.save(user);

        log.warn("管理员密码已被本机重置: account={}, role={}", account, user.getRole());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("account", account);
        data.put("role", user.getRole() == null ? null : user.getRole().name());
        data.put("message", "密码已重置，请用新密码登录后台");
        return ApiResponse.ok(data);
    }
}
