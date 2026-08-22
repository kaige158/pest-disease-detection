package com.laos.agri.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Spring Security配置 — 开发阶段开放访问，生产环境收紧
 *
 * 控制方式: security.admin-open 配置项
 * - true (开发/demo): admin路径无需登录
 * - false (生产): admin路径需要认证
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${security.admin-open:false}")
    private boolean adminOpen;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED))
            .authorizeHttpRequests(auth -> {
                // 公开API — 任何环境都无需认证
                auth.requestMatchers("/api/v1/knowledge/**").permitAll();
                auth.requestMatchers("/api/v1/recognition/**").permitAll();
                auth.requestMatchers("/api/v1/assistant/**").permitAll();

                // 管理路径 — 根据环境配置决定
                if (adminOpen) {
                    auth.requestMatchers("/api/v1/admin/**").permitAll();
                    auth.requestMatchers("/admin/**").permitAll();
                } else {
                    auth.requestMatchers("/api/v1/admin/**").authenticated();
                    auth.requestMatchers("/admin/**").authenticated();
                }

                // 静态资源 + 文档 + 健康检查
                auth.requestMatchers("/css/**", "/js/**", "/images/**").permitAll();
                auth.requestMatchers("/health", "/api-docs/**", "/swagger-ui/**").permitAll();

                // 其他请求默认允许（生产环境如需全认证可改为 .anyRequest().authenticated()）
                auth.anyRequest().permitAll();
            })
            .formLogin(form -> form
                .loginPage("/admin/login")
                .defaultSuccessUrl("/admin/dashboard")
                .permitAll()
            )
            .logout(logout -> logout
                .logoutSuccessUrl("/admin/login")
                .permitAll()
            );

        return http.build();
    }
}
