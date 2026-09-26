package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.dto.PageData;
import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.UserRepository;
import com.laos.agri.service.AuditService;
import com.laos.agri.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 用户管理 —— 管理后台运营用户用
 *
 * <pre>
 *   GET    /api/v1/admin/users?keyword=&role=&page=&size=   用户列表（分页+检索）
 *   GET    /api/v1/admin/users/{id}                          用户详情
 *   POST   /api/v1/admin/users/{id}/toggle                   启用/停用（停用会踢下线）
 *   POST   /api/v1/admin/users/{id}/role                     调整角色
 *   POST   /api/v1/admin/users/{id}/reset-password           重置密码
 *   GET    /api/v1/admin/users/stats                         用户统计
 * </pre>
 *
 * <p>安全：所有接口限管理员；响应走 {@link AuthService#toPublicView} 脱敏，不含密码哈希。
 */
@RestController
@RequestMapping("/api/v1/admin/users")
/**
 * 权限：
 *  - 查看列表：ADMIN / EXPERT / TECHNICIAN（都允许进后台）
 *  - 停用/改角色/重置密码：仅 ADMIN（账号安全相关，职责分离）
 *  - 查看完整手机号：仅 ADMIN + 二次验证密码 + 审计留痕
 */
@PreAuthorize("hasAnyRole('ADMIN','EXPERT','TECHNICIAN')")
public class AdminUserController {

    private static final Logger log = LoggerFactory.getLogger(AdminUserController.class);

    private final UserRepository userRepo;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;
    private final AuditService auditService;
    private final com.laos.agri.service.UserDeletionService deletionService;

    public AdminUserController(UserRepository userRepo,
                               org.springframework.security.crypto.password.PasswordEncoder passwordEncoder,
                               AuditService auditService,
                               com.laos.agri.service.UserDeletionService deletionService) {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.auditService = auditService;
        this.deletionService = deletionService;
    }

    /** 当前登录管理员（二次验证与审计需要） */
    private User currentAdmin() {
        String username = com.laos.agri.config.AdminViewAdvice.resolveUsername();
        if (username == null) return null;
        return userRepo.findByPhone(username).orElse(null);
    }

    public record RoleRequest(String role) {}
    public record ResetPasswordRequest(String newPassword) {}

    /**
     * 查看完整手机号请求体
     *
     * <p>必须再次输入**当前管理员自己的登录密码**：
     * 手机号是个人信息，即便管理员也不应随手可见，
     * 二次验证能确保是"本人主动操作"，而不是别人借用了已登录的浏览器。
     */
    public record RevealPhoneRequest(@jakarta.validation.constraints.NotBlank String password) {}

    /**
     * 查看某用户的完整手机号（需二次验证密码 + 审计留痕）
     *
     * <p>安全设计：
     * <ol>
     *   <li>必须是 ADMIN 角色（类级 @PreAuthorize 已限制）</li>
     *   <li>必须提供该管理员自己的登录密码，密码错误一律拒绝</li>
     *   <li>无论成功失败都写审计日志，可追溯"谁看了谁"</li>
     *   <li>只返回这一个用户的号码，不支持批量导出</li>
     * </ol>
     */
    @PostMapping("/{id}/reveal-phone")
    @Transactional
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> revealPhone(@PathVariable Long id,
                                                        @Valid @RequestBody RevealPhoneRequest req,
                                                        HttpServletRequest httpReq) {
        User admin = currentAdmin();
        if (admin == null) {
            return ApiResponse.error(401, "未登录或登录已过期");
        }

        // 校验管理员自己的密码 —— 失败的尝试也要留痕，便于发现异常探测
        boolean passwordOk = admin.getPasswordHash() != null
                && passwordEncoder.matches(req.password(), admin.getPasswordHash());
        if (!passwordOk) {
            auditService.record(admin, "REVEAL_PHONE_FAILED", "USER", id,
                    "二次验证密码错误，拒绝查看完整手机号", clientIp(httpReq));
            log.warn("管理员查看手机号时密码校验失败: actorId={}, targetId={}", admin.getId(), id);
            return ApiResponse.error(403, "密码不正确，无法查看完整手机号");
        }

        return userRepo.findById(id).map(target -> {
            auditService.record(admin, "REVEAL_PHONE", "USER", id,
                    "查看用户完整手机号", clientIp(httpReq));

            Map<String, Object> data = new LinkedHashMap<>();
            data.put("id", target.getId());
            data.put("nickname", target.getNickname());
            data.put("country_code", target.getCountryCode() == null ? "" : target.getCountryCode());
            // 本次是明确的“查看完整号码”操作，返回拼接后的完整号码
            data.put("phone_full", com.laos.agri.service.PhoneCodec.display(
                    target.getCountryCode(), target.getPhone()));
            data.put("phone_raw", target.getPhone());
            data.put("revealed_at", java.time.LocalDateTime.now().toString());
            data.put("notice", "本次查看已记录到审计日志");
            log.warn("管理员查看了用户完整手机号: actorId={}, actor={}, targetId={}",
                    admin.getId(), admin.getPhone(), id);
            return ApiResponse.ok(data);
        }).orElseGet(() -> ApiResponse.error(404, "用户不存在: " + id));
    }

    private static String clientIp(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return req.getRemoteAddr();
    }

    @GetMapping
    public ApiResponse<PageData<Map<String, Object>>> list(            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String role,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        UserRole roleEnum = null;
        if (role != null && !role.isBlank()) {
            try {
                roleEnum = UserRole.valueOf(role.trim().toUpperCase());
            } catch (IllegalArgumentException e) {
                return ApiResponse.error(400, "未知角色：" + role);
            }
        }
        String kw = (keyword == null || keyword.isBlank()) ? null : keyword.trim();

        // 停用账号也允许翻到，方便管理员复查
        Page<User> result = userRepo.search(kw, roleEnum, PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size))));

        List<Map<String, Object>> items = result.getContent().stream()
                .map(AuthService::toPublicView)
                .toList();

        return ApiResponse.ok(new PageData<>(items, result.getTotalElements(), page, size));
    }

    @GetMapping("/stats")
    public ApiResponse<Map<String, Object>> stats() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("total", userRepo.count());
        Map<String, Long> byRole = new LinkedHashMap<>();
        for (UserRole r : UserRole.values()) {
            byRole.put(r.name(), userRepo.countByRole(r));
        }
        m.put("by_role", byRole);
        return ApiResponse.ok(m);
    }

    @GetMapping("/{id}")
    public ApiResponse<Map<String, Object>> detail(@PathVariable Long id) {
        return userRepo.findById(id)
                .map(u -> ApiResponse.ok(AuthService.toPublicView(u)))
                .orElseGet(() -> ApiResponse.error(404, "用户不存在: " + id));
    }

    /**
     * 启用 / 停用账号
     *
     * <p>停用时递增 token_version —— 该用户已签发的所有 JWT 立即失效，实现"踢下线"。
     */
    @PostMapping("/{id}/toggle")
    @Transactional
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> toggle(@PathVariable Long id) {
        return userRepo.findById(id).map(u -> {
            boolean nowActive = !Boolean.TRUE.equals(u.getIsActive());
            u.setIsActive(nowActive);
            if (!nowActive) {
                u.setTokenVersion((u.getTokenVersion() == null ? 0 : u.getTokenVersion()) + 1);
            }
            userRepo.save(u);
            log.info("管理员{}用户: id={}, phone={}", nowActive ? "启用" : "停用", id, u.getPhone());
            Map<String, Object> resp = AuthService.toPublicView(u);
            resp.put("message", nowActive ? "账号已启用" : "账号已停用，该用户所有设备需重新登录");
            return ApiResponse.ok(resp);
        }).orElseGet(() -> ApiResponse.error(404, "用户不存在: " + id));
    }

    /** 调整角色（农户 / 技术员 / 专家 / 管理员） */
    @PostMapping("/{id}/role")
    @Transactional
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> changeRole(@PathVariable Long id, @RequestBody RoleRequest req) {
        if (req.role() == null || req.role().isBlank()) {
            return ApiResponse.error(400, "请指定角色");
        }
        UserRole target;
        try {
            target = UserRole.valueOf(req.role().trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, "未知角色：" + req.role());
        }

        return userRepo.findById(id).map(u -> {
            // 不允许把最后一个管理员降级，避免后台把自己锁死
            if (u.getRole() == UserRole.ADMIN && target != UserRole.ADMIN
                    && userRepo.countByRole(UserRole.ADMIN) <= 1) {
                return ApiResponse.<Map<String, Object>>error(400, "系统至少保留一名管理员，无法降级");
            }
            u.setRole(target);
            u.setTokenVersion((u.getTokenVersion() == null ? 0 : u.getTokenVersion()) + 1);
            userRepo.save(u);
            log.info("管理员调整用户角色: id={}, role={}", id, target);
            Map<String, Object> resp = AuthService.toPublicView(u);
            resp.put("message", "角色已调整为 " + target.name() + "，该用户需重新登录");
            return ApiResponse.ok(resp);
        }).orElseGet(() -> ApiResponse.error(404, "用户不存在: " + id));
    }

    /** 重置密码（用于农户忘记密码时人工协助，无需短信通道） */
    @PostMapping("/{id}/reset-password")
    @Transactional
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> resetPassword(@PathVariable Long id,
                                                          @RequestBody ResetPasswordRequest req) {
        String pwd = req.newPassword() == null ? "" : req.newPassword().trim();
        if (pwd.length() < 6) {
            return ApiResponse.error(400, "新密码至少 6 位");
        }
        return userRepo.findById(id).map(u -> {
            u.setPasswordHash(passwordEncoder.encode(pwd));
            u.setTokenVersion((u.getTokenVersion() == null ? 0 : u.getTokenVersion()) + 1);
            u.setMustChangePassword(true);   // 被管理员重置 → 提醒用户自行改密
            userRepo.save(u);
            log.info("管理员重置用户密码: id={}, phone={}", id, u.getPhone());
            Map<String, Object> resp = new LinkedHashMap<>();
            resp.put("user_id", id);
            resp.put("message", "密码已重置，请通过线下方式告知用户");
            return ApiResponse.ok(resp);
        }).orElseGet(() -> ApiResponse.error(404, "用户不存在: " + id));
    }

    // ==================== 删除用户（不可恢复，需 ADMIN + 二次验证密码）====================

    /**
     * 删除请求体
     *
     * <p>为什么要密码：删除是不可恢复操作，比"查看手机号"危险得多。
     * 只靠"已经登录"不够 —— 管理员离开座位时浏览器可能还开着，
     * 二次输入密码能确保是本人主动、当下做出的决定。
     */
    public record DeleteUserRequest(@jakarta.validation.constraints.NotBlank String password) {}

    /**
     * 删除影响预览 —— 删之前先让管理员看清"删什么、留什么"
     *
     * <p>最要紧的是让管理员确认**平台数据不会受损**：
     * 识别记录、图片、训练数据资产都不会随账号消失。
     */
    @GetMapping("/{id}/delete-preview")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> deletePreview(@PathVariable Long id) {
        User admin = currentAdmin();
        var preview = deletionService.preview(id, admin == null ? null : admin.getId());
        if (preview == null) {
            return ApiResponse.error(404, "用户不存在: " + id);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user_id", preview.userId());
        data.put("nickname", preview.nickname());
        data.put("phone_masked", preview.phoneMasked());
        data.put("country_code", preview.countryCode());
        data.put("role", preview.role());
        data.put("is_active", preview.active());
        // 将被匿名保留的数据（平台资产，删除账号不影响）
        data.put("diagnoses_kept", preview.diagnosesKept());
        data.put("images_kept", preview.imagesKept());
        data.put("training_assets_kept", preview.trainingAssetsKept());
        data.put("training_ready_kept", preview.trainingReadyKept());
        // 将随账号删除的个人信息
        data.put("verification_codes", preview.verificationCodes());
        data.put("deletable", preview.deletable());
        data.put("blockers", preview.blockers());
        data.put("notice", "识别记录、图片、训练数据资产会匿名保留（不再关联到任何人），平台数据资产不受影响；审计日志同样保留");
        return ApiResponse.ok(data);
    }

    /**
     * 删除用户账号（识别数据匿名保留）
     *
     * <p>安全设计（与"查看手机号"同一套路，但更严）：
     * <ol>
     *   <li>仅 ADMIN（类级 @PreAuthorize 放开了 EXPERT/TECHNICIAN 查看列表，这里必须收紧）</li>
     *   <li>必须再次输入管理员自己的登录密码，密码错误一律拒绝并记审计</li>
     *   <li>不能删自己 / 不能删最后一个管理员</li>
     *   <li>成功与失败都写审计日志，且**审计日志本身不随用户删除而消失**</li>
     * </ol>
     *
     * <p><b>不删数据资产</b>：见 {@link com.laos.agri.service.UserDeletionService} 的说明 ——
     * 识别记录、图片、训练数据资产是平台的核心价值，删账号时**只解除与个人的关联**，
     * 数据本身（AI 结果、专家标签、图片）全部保留。
     */
    @PostMapping("/{id}/delete")
    @Transactional
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<Map<String, Object>> deleteUser(@PathVariable Long id,
                                                       @Valid @RequestBody DeleteUserRequest req,
                                                       HttpServletRequest httpReq) {
        User admin = currentAdmin();
        if (admin == null) {
            return ApiResponse.error(401, "未登录或登录已过期");
        }

        // 二次验证：密码错误一律拒绝，且失败也留痕（便于发现异常探测）
        boolean passwordOk = admin.getPasswordHash() != null
                && passwordEncoder.matches(req.password(), admin.getPasswordHash());
        if (!passwordOk) {
            auditService.record(admin, "DELETE_USER_FAILED", "USER", id,
                    "二次验证密码错误，拒绝删除用户", clientIp(httpReq));
            log.warn("删除用户时密码校验失败: actorId={}, targetId={}", admin.getId(), id);
            return ApiResponse.error(403, "密码不正确，无法删除用户");
        }

        var preview = deletionService.preview(id, admin.getId());
        if (preview == null) {
            return ApiResponse.error(404, "用户不存在: " + id);
        }
        if (!preview.deletable()) {
            String reason = String.join("；", preview.blockers());
            auditService.record(admin, "DELETE_USER_BLOCKED", "USER", id, reason, clientIp(httpReq));
            return ApiResponse.error(400, reason);
        }

        var result = deletionService.delete(id);

        auditService.record(admin, "DELETE_USER", "USER", id,
                String.format("删除账号 role=%s，识别记录匿名保留=%d、图片保留=%d、训练资产保留=%d，删除验证码=%d",
                        preview.role(), result.anonymizedRecords(), result.keptImages(),
                        result.keptTrainingAssets(), result.deletedVerificationCodes()),
                clientIp(httpReq));
        log.warn("管理员删除用户账号: actorId={}, targetId={}, role={}",
                admin.getId(), id, preview.role());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user_id", id);
        data.put("account_deleted", result.accountDeleted());
        data.put("anonymized_records", result.anonymizedRecords());
        data.put("kept", Map.of(
                "diagnoses", result.keptDiagnoses(),
                "images", result.keptImages(),
                "training_assets", result.keptTrainingAssets()));
        data.put("deleted_verification_codes", result.deletedVerificationCodes());
        data.put("message", String.format(
                "账号已删除。平台数据已保留：识别记录 %d 条（已匿名化）、图片 %d 张、训练数据资产 %d 条；"
                        + "同时删除该号码的验证码记录 %d 条",
                result.keptDiagnoses(), result.keptImages(),
                result.keptTrainingAssets(), result.deletedVerificationCodes()));
        return ApiResponse.ok(data);
    }
}
