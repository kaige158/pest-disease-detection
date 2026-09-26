package com.laos.agri.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security 配置 —— 同时支撑两种客户端
 *
 * <table>
 *   <tr><th>客户端</th><th>登录方式</th><th>会话</th></tr>
 *   <tr><td>移动端 APP</td><td>POST /api/v1/auth/login → JWT</td><td>无状态（Bearer 令牌）</td></tr>
 *   <tr><td>管理后台网页</td><td>表单登录 /admin/login</td><td>HttpSession</td></tr>
 * </table>
 *
 * <p>管理接口 {@code /api/v1/admin/**} 与后台网页 {@code /admin/**} 都要求已认证，
 * 并由 {@code @PreAuthorize("hasRole('ADMIN')")} 进一步限定为管理员。
 * 开发/演示期若要临时放开，可设 {@code security.admin-open=true}，
 * 但生产环境必须保持 false（默认值）。
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    /** 无需登录即可访问的公开接口 */
    private static final String[] PUBLIC_API = {
            "/api/v1/knowledge/**",
            "/api/v1/recognition/**",
            "/api/v1/assistant/**",
            "/api/v1/sync/**",
            "/api/v1/auth/login",
            "/api/v1/meta/**",
    };

    private static final String[] PUBLIC_OTHER = {
            "/css/**", "/js/**", "/images/**", "/favicon.ico",
            // 上传的识别图片：APP 直接用 <img src="/uploads/..."> 加载，
            // 不会带 Bearer 令牌，所以必须公开；文件名由服务端随机生成，不可枚举。
            "/uploads/**",
            "/health", "/actuator/health", "/api-docs/**", "/swagger-ui/**", "/swagger-ui.html",
            "/admin/login", "/admin/error", "/error",
    };

    @Value("${security.admin-open:false}")
    private boolean adminOpen;

    /** 允许跨域的来源，逗号分隔；留空则使用开发默认（本机各端口） */
    @Value("${app.cors-allowed-origins:}")
    private String corsAllowedOrigins;

    private final JwtAuthFilter jwtAuthFilter;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 角色继承关系 —— 避免把同一组角色在几十处重复书写
     *
     * <p>ADMIN 与 EXPERT 都继承 TECHNICIAN 的权限：
     * "能进后台"的角色集合只需写一次 {@code hasRole('TECHNICIAN')}，
     * 新增角色时也只改这里。
     */
    /**
     * 让方法级 @PreAuthorize 也使用角色继承
     * （默认只对 URL 规则生效，注解里 hasRole 不会向上继承）
     */
    @Bean
    public org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler
            methodSecurityExpressionHandler(org.springframework.security.access.hierarchicalroles.RoleHierarchy hierarchy) {
        // 说明：SpEL 里引用 Bean（如 @securityFlags.adminOpen）能生效，
        // 是因为该 handler 实现了 ApplicationContextAware，Spring 会注入上下文
        // 并自动设置 BeanResolver —— 不需要（也无法）在这里手动 set。
        var handler = new org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler();
        handler.setRoleHierarchy(hierarchy);
        return handler;
    }

    @Bean
    public org.springframework.security.access.hierarchicalroles.RoleHierarchy roleHierarchy() {
        // 注意：Spring Security 6.2 用 setHierarchy(String)，
        // 静态工厂 fromHierarchy() 是 6.3+ 才有的，这里按 6.2 的 API 写
        var hierarchy = new org.springframework.security.access.hierarchicalroles.RoleHierarchyImpl();
        hierarchy.setHierarchy("ROLE_ADMIN > ROLE_EXPERT\nROLE_EXPERT > ROLE_TECHNICIAN");
        return hierarchy;
    }

    /**
     * CORS 配置 —— 支持 Flutter Web 调试与 APP 内 WebView 跨域调用接口
     *
     * <p>生产部署时把 {@code app.cors-allowed-origins} 设为实际域名，
     * 不要长期使用通配符来源。
     */
    @Bean
    public org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource() {
        var config = new org.springframework.web.cors.CorsConfiguration();
        if (corsAllowedOrigins != null && !corsAllowedOrigins.isBlank()) {
            config.setAllowedOriginPatterns(java.util.Arrays.stream(corsAllowedOrigins.split(","))
                    .map(String::trim).filter(s -> !s.isEmpty()).toList());
        } else {
            // 开发默认：本机各端口（Flutter Web / 后台页面 / 局域网真机调试）
            config.setAllowedOriginPatterns(java.util.List.of(
                    "http://localhost:*", "http://127.0.0.1:*",
                    "http://10.0.2.2:*", "http://192.168.*:*", "http://172.*:*"));
        }
        config.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(java.util.List.of("*"));
        config.setExposedHeaders(java.util.List.of("Authorization"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        var source = new org.springframework.web.cors.UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // CORS —— Flutter Web 调试页(8081) 与 APP 内置 WebView 需要跨域访问后端。
            // 默认只放开本机开发来源；生产请用 app.cors-allowed-origins 显式指定域名。
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED))
            .authorizeHttpRequests(auth -> {
                auth.requestMatchers(PUBLIC_API).permitAll();
                auth.requestMatchers(PUBLIC_OTHER).permitAll();

                if (adminOpen) {
                    // 仅用于本地演示：后台完全放开
                    auth.requestMatchers("/api/v1/admin/**").permitAll();
                    auth.requestMatchers("/admin/**").permitAll();
                } else {
                    // 后台是"运营人员"的地方：农户角色不得进入。
                    // 借助角色继承，ADMIN/EXPERT 自动满足 hasRole('TECHNICIAN')
                    auth.requestMatchers("/api/v1/admin/**").hasRole("TECHNICIAN");
                    auth.requestMatchers("/admin/**").hasRole("TECHNICIAN");
                }

                // 其余接口默认公开（识别/知识库等），需要登录的接口自行用 @PreAuthorize 标注
                auth.anyRequest().permitAll();
            })
            .formLogin(form -> form
                .loginPage("/admin/login")
                .loginProcessingUrl("/admin/login")
                .defaultSuccessUrl("/admin/dashboard", true)
                .failureUrl("/admin/login?error=1")
                .permitAll()
            )
            .logout(logout -> logout
                .logoutUrl("/admin/logout")
                .logoutSuccessUrl("/admin/login?logout=1")
                .permitAll()
            )
            // 未认证时的响应按客户端类型区分：
            //   /api/**  → 401 JSON（APP 需要结构化错误，不能拿到 HTML 登录页）
            //   其它     → 302 跳转到后台登录页（浏览器）
            .exceptionHandling(ex -> ex.authenticationEntryPoint((request, response, authException) -> {
                if (request.getRequestURI().startsWith("/api/")) {
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    response.setContentType("application/json;charset=UTF-8");
                    response.getWriter().write(
                            "{\"code\":401,\"message\":\"未登录或登录已过期\",\"data\":null}");
                } else {
                    response.sendRedirect("/admin/login");
                }
            }))
            // JWT 过滤器要在表单登录之前
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
