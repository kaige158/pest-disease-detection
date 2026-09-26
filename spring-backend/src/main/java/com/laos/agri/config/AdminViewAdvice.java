package com.laos.agri.config;

import com.laos.agri.entity.User;
import com.laos.agri.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ModelAttribute;

/**
 * 后台页面的通用视图数据 —— 把"当前登录管理员"和语言偏好注入每个后台页面
 *
 * <p>为什么需要它：早期模板里写死了"👩‍🏫 老师 | 欢迎回来"，
 * 但管理员不一定是老师（可能是农技站人员、项目运营、老挝本地同事），
 * 显示假身份既不专业也容易造成误解。这里统一取真实账号信息。
 *
 * <p>同时为 i18n 提供 {@code lang} 变量，模板用它决定当前高亮哪种语言。
 */
@ControllerAdvice(basePackages = "com.laos.agri.controller")
public class AdminViewAdvice {

    private static final Logger log = LoggerFactory.getLogger(AdminViewAdvice.class);

    private final UserRepository userRepo;

    public AdminViewAdvice(UserRepository userRepo) {
        this.userRepo = userRepo;
    }

    /** 当前登录管理员（未登录返回 null）；仅对 /admin 页面生效 */
    @ModelAttribute("currentAdmin")
    public User currentAdmin() {
        String username = resolveUsername();
        if (username == null) return null;
        try {
            User u = userRepo.findByPhone(username).orElse(null);
            if (u == null) log.debug("currentAdmin: 账号不存在 phone={}", username);
            return u;
        } catch (Exception e) {
            log.debug("读取当前管理员失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 从安全上下文取登录用户名。
     *
     * <p>注意：表单登录（DaoAuthenticationProvider）的 principal 是
     * {@code org.springframework.security.core.userdetails.User} 对象，
     * 而 JWT 过滤器设置的是普通字符串 —— 两种都要兼容，
     * 早期只判断 String 会导致后台页面拿不到当前账号。
     */
    public static String resolveUsername() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) return null;

        Object principal = auth.getPrincipal();
        String username = null;
        if (principal instanceof org.springframework.security.core.userdetails.UserDetails details) {
            username = details.getUsername();
        } else if (principal instanceof String s) {
            username = s;
        }
        if (username == null || username.isBlank() || "anonymousUser".equals(username)) return null;
        return username;
    }

    /** 当前账号显示名 —— 模板里直接 ${adminDisplayName} */
    @ModelAttribute("adminDisplayName")
    public String adminDisplayName() {
        User u = currentAdmin();
        if (u == null) return "";

        String nickname = u.getNickname();
        String lang = org.springframework.context.i18n.LocaleContextHolder.getLocale().getLanguage();
        boolean lao = "lo".equalsIgnoreCase(lang);

        // 老挝语界面下，如果昵称是不含老挝文字的中文名，就退回角色名，
        // 避免老挝同事看到一串看不懂的中文（角色名在界面里已有本地化文案）
        boolean nicknameHasLao = nickname != null
                && nickname.codePoints().anyMatch(c -> c >= 0x0E80 && c <= 0x0EFF);
        boolean nicknameHasChinese = nickname != null
                && nickname.codePoints().anyMatch(c -> c >= 0x4E00 && c <= 0x9FFF);

        if (nickname != null && !nickname.isBlank()) {
            if (lao && nicknameHasChinese && !nicknameHasLao) {
                return u.getRole() == null ? "" : roleFallbackName(u);
            }
            return nickname;
        }
        return roleFallbackName(u);
    }

    /** 昵称为空时用角色名兜底（文案走前端 i18n，这里只给出中性串） */
    private String roleFallbackName(User u) {
        if (u.getPhone() != null && !u.getPhone().isBlank()) return u.getPhone();
        return "admin";
    }

    /**
     * 当前界面语言（zh / lo）—— 模板里写 `th:lang="${uiLang}"`
     *
     * <p>不能直接用 {@code ${#locale.language}}：CookieLocaleResolver 设置的是
     * {@code Locale("lo")} 这类没有国家的 locale，模板里取 language 会拿到空串，
     * 导致 <html lang=""> 影响字体选择（老挝文字体需要正确的 lang 才生效）。
     */
    @ModelAttribute("uiLang")
    public String uiLang() {
        String lang = org.springframework.context.i18n.LocaleContextHolder.getLocale().getLanguage();
        return (lang == null || lang.isBlank()) ? "zh" : lang;
    }

    /** 是否需要提醒修改密码（初始密码未改 / 刚被重置） */
    @ModelAttribute("mustChangePassword")
    public boolean mustChangePassword() {
        User u = currentAdmin();
        return u != null && Boolean.TRUE.equals(u.getMustChangePassword());
    }
}
