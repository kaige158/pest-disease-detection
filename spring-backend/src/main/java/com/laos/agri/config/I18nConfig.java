package com.laos.agri.config;

import com.laos.agri.entity.User;
import com.laos.agri.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.ReloadableResourceBundleMessageSource;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.servlet.LocaleResolver;
import org.springframework.web.servlet.i18n.CookieLocaleResolver;
import org.springframework.web.servlet.i18n.LocaleChangeInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.List;
import java.util.Locale;

/**
 * 管理后台国际化配置 —— 支持中文 / 老挝语（后续可加英文）
 *
 * <p>为什么后台也要双语：平台最终要交接给老挝本地人员运营，
 * 后台是他们每天用的界面，只有中文会直接影响可用性。
 *
 * <p>语言优先级（从高到低）：
 * <ol>
 *   <li>URL 参数 {@code ?lang=lo}（点击语言切换按钮时触发）</li>
 *   <li>账号里保存的 {@code language_pref}（登录后以账号设置为准，
 *       这样同一个后台在不同电脑上看到的是同一语言）</li>
 *   <li>Cookie（未登录时的选择，登录页也能切语言）</li>
 *   <li>浏览器 Accept-Language</li>
 * </ol>
 */
@Configuration
public class I18nConfig implements WebMvcConfigurer {

    /** 支持的语言 */
    public static final List<String> SUPPORTED_LANGUAGES = List.of("zh", "lo", "en");

    public static final Locale LAO = Locale.forLanguageTag("lo");

    private final UserRepository userRepo;

    public I18nConfig(UserRepository userRepo) {
        this.userRepo = userRepo;
    }

    @Bean
    public LocaleResolver localeResolver() {
        CookieLocaleResolver resolver = new CookieLocaleResolver("agri_admin_lang");
        resolver.setDefaultLocale(Locale.SIMPLIFIED_CHINESE);
        resolver.setCookieMaxAge(60 * 60 * 24 * 365);
        resolver.setCookiePath("/");
        return resolver;
    }

    /** `?lang=xx` 切换语言，交给 CookieLocaleResolver 落盘 */
    @Bean
    public LocaleChangeInterceptor localeChangeInterceptor() {
        LocaleChangeInterceptor interceptor = new LocaleChangeInterceptor();
        interceptor.setParamName("lang");
        return interceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(localeChangeInterceptor());

        // 已登录时，让账号里的语言偏好覆盖 Cookie —— 保证"我的设置在哪台电脑都生效"
        registry.addInterceptor(new org.springframework.web.servlet.HandlerInterceptor() {
            @Override
            public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
                // 本次请求显式指定了语言（点了切换按钮）→ 以显式选择为准，并写回账号
                String explicit = request.getParameter("lang");
                String username = AdminViewAdvice.resolveUsername();
                if (username == null) return true;

                try {
                    User user = userRepo.findByPhone(username).orElse(null);
                    if (user == null) return true;

                    if (explicit != null && SUPPORTED_LANGUAGES.contains(explicit)) {
                        // 切换语言：同步保存到账号，下次登录保持一致
                        if (!explicit.equals(user.getLanguagePref())) {
                            user.setLanguagePref(explicit);
                            userRepo.save(user);
                        }
                        return true;
                    }

                    String pref = user.getLanguagePref();
                    if (pref != null && SUPPORTED_LANGUAGES.contains(pref)) {
                        org.springframework.context.i18n.LocaleContextHolder.setLocale(
                                "zh".equals(pref) ? Locale.SIMPLIFIED_CHINESE : Locale.forLanguageTag(pref));
                    }
                } catch (Exception ignored) {
                    // 语言解析失败不应影响正常请求
                }
                return true;
            }
        });
    }

    /** 消息包 —— 用 messages_zh.properties / messages_lo.properties */
    @Bean
    public ReloadableResourceBundleMessageSource messageSource() {
        ReloadableResourceBundleMessageSource source = new ReloadableResourceBundleMessageSource();
        source.setBasenames("classpath:i18n/messages");
        source.setDefaultEncoding("UTF-8");
        source.setFallbackToSystemLocale(false);
        // 开发期允许热更新文案（生产可改为 -1 并重启生效）
        source.setCacheSeconds(10);
        return source;
    }
}
