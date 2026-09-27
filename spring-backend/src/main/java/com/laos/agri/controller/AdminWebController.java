package com.laos.agri.controller;

import com.laos.agri.entity.User;
import com.laos.agri.repository.CropRepository;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseImageRepository;
import com.laos.agri.repository.DiseaseRepository;
import com.laos.agri.repository.UserRepository;
import com.laos.agri.service.AuthService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 专家后台Web页面控制器 (Thymeleaf服务端渲染)
 * 老师通过浏览器直接访问，不需要额外前端项目
 */
@Controller
@RequestMapping("/admin")
public class AdminWebController {

    private final DiagnosisRecordRepository diagnosisRepo;
    private final DiseaseRepository diseaseRepo;
    private final DiseaseImageRepository imageRepo;
    private final CropRepository cropRepo;
    private final UserRepository userRepo;
    private final AuthService authService;
    private final com.laos.agri.config.AdminPermissionView permissionView;

    public AdminWebController(DiagnosisRecordRepository diagnosisRepo,
                              DiseaseRepository diseaseRepo,
                              DiseaseImageRepository imageRepo,
                              CropRepository cropRepo,
                              UserRepository userRepo,
                              AuthService authService,
                              com.laos.agri.config.AdminPermissionView permissionView) {
        this.diagnosisRepo = diagnosisRepo;
        this.diseaseRepo = diseaseRepo;
        this.imageRepo = imageRepo;
        this.cropRepo = cropRepo;
        this.userRepo = userRepo;
        this.authService = authService;
        this.permissionView = permissionView;
    }

    /** 当前登录管理员（表单提交时使用） */
    private User resolveCurrentAdminOrNull() {
        return resolveCurrentAdmin();
    }

    /** 仪表盘首页 */
    @GetMapping("/dashboard")
    public String dashboard(Model model) {
        long totalDiagnoses = diagnosisRepo.count();
        long pendingReview = diagnosisRepo.findPendingReview(PageRequest.of(0, 1000)).getTotalElements();
        long totalDiseases = diseaseRepo.count();
        long usableImages = imageRepo.countUsableByVersion("vegetable") + imageRepo.countUsableByVersion("fruit");

        model.addAttribute("totalDiagnoses", totalDiagnoses);
        model.addAttribute("pendingReview", pendingReview);
        model.addAttribute("totalDiseases", totalDiseases);
        model.addAttribute("usableImages", usableImages);
        model.addAttribute("currentPage", "dashboard");
        return "admin/dashboard";
    }

    /** AI审核中心 */
    @GetMapping("/review")
    public String reviewCenter(Model model) {
        var pendingPage = diagnosisRepo.findPendingReview(
                PageRequest.of(0, 50, Sort.by(Sort.Direction.DESC, "createdAt")));
        model.addAttribute("pendingList", pendingPage.getContent());
        model.addAttribute("pendingCount", pendingPage.getTotalElements());
        model.addAttribute("currentPage", "review");
        return "admin/review";
    }

    /** 知识库管理 */
    @GetMapping("/knowledge")
    public String knowledgeManagement(Model model) {
        var crops = cropRepo.findAll();
        var diseases = diseaseRepo.findAll();
        model.addAttribute("crops", crops);
        model.addAttribute("diseases", diseases);
        model.addAttribute("currentPage", "knowledge");
        return "admin/knowledge";
    }

    /** 数据统计 */
    @GetMapping("/stats")
    public String statistics(Model model) {
        model.addAttribute("currentPage", "stats");
        return "admin/stats";
    }

    /** 审计日志 —— 仅管理员：删账号、看手机号这类操作必须可追溯 */
    @GetMapping("/audit-logs")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ADMIN')")
    public String auditLogs(Model model) {
        model.addAttribute("currentPage", "audit-logs");
        return "admin/audit-logs";
    }

    /** AI 配置中心 —— 可视化配置 AI 通道，改完即生效（专家可查看，修改需 ADMIN） */
    @GetMapping("/ai-config")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('ADMIN','EXPERT')")
    public String aiConfig(Model model) {
        model.addAttribute("currentPage", "ai-config");
        return "admin/ai-config";
    }

    /** 用户管理 —— 仅管理员（含账号安全操作，见 Permission.USER_MANAGE） */
    @GetMapping("/users")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ADMIN')")
    public String users(Model model) {
        model.addAttribute("currentPage", "users");
        // 角色权限说明：说明文案由 Permission 矩阵实时生成，改角色前管理员能看清后果
        var view = permissionView.build();
        model.addAttribute("permissionRows", view.rows());
        model.addAttribute("roleCards", view.roles());
        return "admin/users";
    }

    /** 修改密码页（首次登录 / 密码被重置后会引导到这里） */
    @GetMapping("/change-password")
    public String changePasswordPage(Model model) {
        model.addAttribute("currentPage", "change-password");
        return "admin/change-password";
    }

    /**
     * 提交修改密码
     *
     * <p>后台采用服务端表单提交（无前端构建链），比在这里引入 JWT 调用更简单直接；
     * 成功后递增 token_version，本次会话立即失效，需用新密码重新登录。
     */
    @PostMapping("/change-password")
    public String changePassword(@RequestParam String oldPassword,
                                 @RequestParam String newPassword,
                                 @RequestParam String confirmPassword,
                                 Model model) {
        model.addAttribute("currentPage", "change-password");

        if (!newPassword.equals(confirmPassword)) {
            model.addAttribute("errorMessage", "两次输入的新密码不一致");
            return "admin/change-password";
        }

        User admin = resolveCurrentAdminOrNull();
        if (admin == null) {
            return "redirect:/admin/login";
        }
        try {
            authService.changePassword(admin, oldPassword, newPassword);
            // 改密后令牌版本已递增，原会话不可用，回登录页
            return "redirect:/admin/login?pwdChanged=1";
        } catch (AuthService.InvalidCredentialException e) {
            model.addAttribute("errorMessage", e.getMessage());
            return "admin/change-password";
        }
    }

    /**
     * 当前登录管理员 —— 从 Spring Security 上下文解析
     *
     * <p>与 {@link com.laos.agri.config.AdminViewAdvice} 共用同一套解析逻辑。
     *
     * <p><b>踩过的坑</b>：早期这里自己判断 {@code auth.getPrincipal() instanceof String}，
     * 但后台是**表单登录**，principal 是 {@code UserDetails} 对象（只有 JWT 才是字符串）——
     * 于是永远返回 null，改密码方法直接跳回登录页，
     * 表现为"点了修改、提示重新登录、但密码一个字都没改"的静默失败。
     */
    private User resolveCurrentAdmin() {
        String username = com.laos.agri.config.AdminViewAdvice.resolveUsername();
        if (username == null) return null;
        return userRepo.findByPhone(username).orElse(null);
    }

    /** 登录页 */
    @GetMapping("/login")
    public String login() {
        return "admin/login";
    }
}
